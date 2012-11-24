// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library compiler;

import 'dart:collection' show SplayTreeMap;
import 'package:html5lib/dom.dart';
import 'package:html5lib/parser.dart';

import 'analyzer.dart';
import 'code_printer.dart';
import 'codegen.dart' as codegen;
import 'directive_parser.dart' show parseDartCode;
import 'emitters.dart';
import 'file_system.dart';
import 'file_system/path.dart';
import 'files.dart';
import 'html_cleaner.dart';
import 'info.dart';
import 'messages.dart';
import 'options.dart';
import 'utils.dart';

/**
 * Parses an HTML file [contents] and returns a DOM-like tree.
 * Note that [contents] will be a [String] if coming from a browser-based
 * [FileSystem], or it will be a [List<int>] if running on the command line.
 */
Document parseHtml(contents, Path sourcePath) {
  var parser = new HtmlParser(contents, generateSpans: true);
  var document = parser.parse();

  // Note: errors aren't fatal in HTML (unless strict mode is on).
  // So just print them as warnings.
  for (var e in parser.errors) {
    messages.warning(e.message, e.span, file: sourcePath);
  }
  return document;
}

/** Compiles an application written with Dart web components. */
class Compiler {
  final FileSystem filesystem;
  final CompilerOptions options;
  final List<SourceFile> files = <SourceFile>[];
  final List<OutputFile> output = <OutputFile>[];

  Path _mainPath;
  PathInfo _pathInfo;

  /** Information about source [files] given their href. */
  final Map<Path, FileInfo> info = new SplayTreeMap<Path, FileInfo>();

  Compiler(this.filesystem, this.options, [String currentDir]) {
    _mainPath = new Path(options.inputFile);
    var mainDir = _mainPath.directoryPath;
    var basePath =
        options.baseDir != null ? new Path(options.baseDir) : mainDir;
    var outputPath =
        options.outputDir != null ? new Path(options.outputDir) : mainDir;

    // Normalize paths - all should be relative or absolute paths.
    bool anyAbsolute = _mainPath.isAbsolute || basePath.isAbsolute ||
        outputPath.isAbsolute;
    bool allAbsolute = _mainPath.isAbsolute && basePath.isAbsolute &&
        outputPath.isAbsolute;
    if (anyAbsolute && !allAbsolute) {
      if (currentDir == null)  {
        messages.error('internal error: could not normalize paths. Please make '
            'the input, base, and output paths all absolute or relative, or '
            'specify "currentDir" to the Compiler constructor', null);
        return;
      }
      var currentPath = new Path(currentDir);
      if (!_mainPath.isAbsolute) _mainPath = currentPath.join(_mainPath);
      if (!basePath.isAbsolute) basePath = currentPath.join(basePath);
      if (!outputPath.isAbsolute) outputPath = currentPath.join(outputPath);
    }
    _pathInfo = new PathInfo(basePath, outputPath);
  }

  /** Compile the application starting from the given [mainFile]. */
  Future run() {
    if (_mainPath.filename.endsWith('.dart')) {
      messages.error("Please provide an HTML file as your entry point.",
          null, file: _mainPath);
      return new Future.immediate(null);
    }
    return _parseAndDiscover(_mainPath).transform((_) {
      _analyze();
      _emit();
      return null;
    });
  }

  /**
   * Asynchronously parse [inputFile] and transitively discover web components
   * to load and parse. Returns a future that completes when all files are
   * processed.
   */
  Future _parseAndDiscover(Path inputFile) {
    var tasks = new FutureGroup();
    bool isEntry = true;

    processHtmlFile(SourceFile file) {
      if (!_pathInfo.checkInputPath(file.path)) return;

      files.add(file);

      var fileInfo = _time('Analyzed definitions', file.path,
          () => analyzeDefinitions(file, isEntryPoint: isEntry));
      isEntry = false;
      info[file.path] = fileInfo;

      // Load component files referenced by [file].
      for (var href in fileInfo.componentLinks) {
        tasks.add(_parseHtmlFile(href).transform(processHtmlFile));
      }

      // Load .dart files being referenced in the page.
      var src = fileInfo.externalFile;
      if (src != null) tasks.add(_parseDartFile(src).transform(_addDartFile));

      // Load .dart files being referenced in components.
      for (var component in fileInfo.declaredComponents) {
        var src = component.externalFile;
        if (src != null) tasks.add(_parseDartFile(src).transform(_addDartFile));
      }
    }

    tasks.add(_parseHtmlFile(inputFile).transform(processHtmlFile));
    return tasks.future;
  }

  /** Asynchronously parse [path] as an .html file. */
  Future<SourceFile> _parseHtmlFile(Path path) {
    return (filesystem.readTextOrBytes(path)
        ..handleException((e) => _readError(e, path)))
        .transform((source) {
          var file = new SourceFile(path);
          file.document = _time('Parsed', path, () => parseHtml(source, path));
          return file;
        });
  }

  /** Parse [filename] and treat it as a .dart file. */
  Future<SourceFile> _parseDartFile(Path path) {
    return (filesystem.readText(path)
        ..handleException((e) => _readError(e, path)))
        .transform((code) => new SourceFile(path, isDart: true)..code = code);
  }

  bool _readError(error, Path path) {
    messages.error('exception while reading file, original message:\n $error',
        null, file: path);
    return true;
  }

  void _addDartFile(SourceFile dartFile) {
    if (!_pathInfo.checkInputPath(dartFile.path)) return;
    
    var fileInfo = new FileInfo(dartFile.path);
    info[dartFile.path] = fileInfo;
    fileInfo.inlinedCode = dartFile.code;
    fileInfo.userCode = parseDartCode(fileInfo.inlinedCode,
        fileInfo.path, messages);
    if (fileInfo.userCode.partOf != null) {
      messages.error('expected a library, not a part.', null,
          file: dartFile.path);
    }

    files.add(dartFile);
  }

  /** Run the analyzer on every input html file. */
  void _analyze() {
    for (var file in files) {
      if (file.isDart) continue;
      _time('Analyzed contents', file.path, () => analyzeFile(file, info));
    }
  }

  /** Emit the generated code corresponding to each input file. */
  void _emit() {
    for (var file in files) {
      _time('Codegen', file.path, () {
        if (!file.isDart) {
          var fileInfo = info[file.path];
          cleanHtmlNodes(fileInfo);
          _emitComponents(fileInfo);
          if (fileInfo.isEntryPoint && fileInfo.codeAttached) {
            _emitMainDart(file);
            _emitMainHtml(file);
          }
        }
      });
    }
  }

  static const String DARTJS_LOADER =
    "http://dart.googlecode.com/svn/branches/bleeding_edge/dart/client/dart.js";

  /** Emit the main .dart file. */
  void _emitMainDart(SourceFile file) {
    var fileInfo = info[file.path];
    var contents = new MainPageEmitter(fileInfo).run(file.document, _pathInfo);
    output.add(new OutputFile(_pathInfo.outputLibraryPath(fileInfo), contents));
  }

  /** Generate an html file with the (trimmed down) main html page. */
  void _emitMainHtml(SourceFile file) {
    var fileInfo = info[file.path];

    // Clear the body, we moved all of it
    var document = file.document;
    document.body.nodes.clear();
    var bootstrapName = 
        _pathInfo.mangle('${file.path.filename}_bootstrap.dart','');
    output.add(new OutputFile(
        _pathInfo.fileInOutputDir(bootstrapName),
        codegen.bootstrapCode(_pathInfo.relativePathFromOutputDir(fileInfo))));

    document.body.nodes.add(parseFragment(
      '<script type="text/javascript" src="$DARTJS_LOADER"></script>\n'
      '<script type="application/dart"'
      ' src="$bootstrapName">'
      '</script>'
    ));

    for (var link in document.head.queryAll('link')) {
      if (link.attributes["rel"] == "components") {
        link.remove();
      }
    }

    _addAutoGeneratedComment(file);
    output.add(new OutputFile(
        _pathInfo.fileInOutputDir(
            _pathInfo.mangle(file.path.filename, '.html')),
        document.outerHTML));
  }

  /** Emits the Dart code for all components in [fileInfo]. */
  void _emitComponents(FileInfo fileInfo) {
    for (var component in fileInfo.declaredComponents) {
      var code = new WebComponentEmitter(fileInfo).run(component, _pathInfo);
      output.add(new OutputFile(_pathInfo.outputLibraryPath(component), code));
    }
  }

  _time(String logMessage, Path path, callback(), {bool printTime: false}) {
    var message = new StringBuffer();
    message.add(logMessage);
    for (int i = (60 - logMessage.length - path.filename.length); i > 0 ; i--) {
      message.add(' ');
    }
    message.add(path.filename);
    return time(message.toString(), callback,
        printTime: options.verbose || printTime);
  }
}

void _addAutoGeneratedComment(SourceFile file) {
  var document = file.document;

  // Insert the "auto-generated" comment after the doctype, otherwise IE will go
  // into quirks mode.
  int commentIndex = 0;
  DocumentType doctype = find(document.nodes, (n) => n is DocumentType);
  if (doctype != null) {
    commentIndex = document.nodes.indexOf(doctype) + 1;
    // TODO(jmesserly): the html5lib parser emits a warning for missing doctype,
    // but it allows you to put it after comments. Presumably they do this
    // because some comments won't force IE into quirks mode (sigh). See this
    // link for more info:
    //     http://bugzilla.validator.nu/show_bug.cgi?id=836
    // For simplicity we're emitting the warning always, like validator.nu does.
    if (doctype.tagName != 'html' || commentIndex != 1) {
      messages.warning('file should start with <!DOCTYPE html> '
          'to avoid the possibility of it being parsed in quirks mode in IE. '
          'See http://www.w3.org/TR/html5-diff/#doctype',
          doctype.span, file: file.path);
    }
  }
  document.nodes.insertAt(commentIndex, parseFragment(
      '\n<!-- This file was auto-generated from template ${file.path}. -->\n'));
}
