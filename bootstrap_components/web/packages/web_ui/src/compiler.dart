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
  final FileSystem fileSystem;
  final CompilerOptions options;
  final List<SourceFile> files = <SourceFile>[];
  final List<OutputFile> output = <OutputFile>[];

  Path _mainPath;
  PathInfo _pathInfo;

  /** Information about source [files] given their href. */
  final Map<Path, FileInfo> info = new SplayTreeMap<Path, FileInfo>();

  Compiler(this.fileSystem, this.options, [String currentDir]) {
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
    _pathInfo = new PathInfo(basePath, outputPath, options.forceMangle);
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

    var processed = new Set();
    processHtmlFile(SourceFile file) {
      if (file == null || !_pathInfo.checkInputPath(file.path)) return;

      files.add(file);

      var fileInfo = _time('Analyzed definitions', file.path,
          () => analyzeDefinitions(file, isEntryPoint: isEntry));
      isEntry = false;
      info[file.path] = fileInfo;

      // Load component files referenced by [file].
      for (var href in fileInfo.componentLinks) {
        if (!processed.contains(href)) {
          processed.add(href);
          tasks.add(_parseHtmlFile(href).transform(processHtmlFile));
        }
      }

      // Load .dart files being referenced in the page.
      var src = fileInfo.externalFile;
      if (src != null && !processed.contains(src)) {
        processed.add(src);
        tasks.add(_parseDartFile(src).transform(_addDartFile));
      }

      // Load .dart files being referenced in components.
      for (var component in fileInfo.declaredComponents) {
        var src = component.externalFile;
        if (src != null && !processed.contains(src)) {
          processed.add(src);
          tasks.add(_parseDartFile(src).transform(_addDartFile));
        }
      }
    }

    processed.add(inputFile);
    tasks.add(_parseHtmlFile(inputFile).transform(processHtmlFile));
    return tasks.future;
  }

  /** Asynchronously parse [path] as an .html file. */
  Future<SourceFile> _parseHtmlFile(Path path) {
    return fileSystem.readTextOrBytes(path)
        .transform((source) {
          var file = new SourceFile(path);
          file.document = _time('Parsed', path, () => parseHtml(source, path));
          return file;
        })
        .transformException((e) => _readError(e, path));
  }

  /** Parse [filename] and treat it as a .dart file. */
  Future<SourceFile> _parseDartFile(Path path) {
    return fileSystem.readText(path)
        .transform((code) => new SourceFile(path, isDart: true)..code = code)
        .transformException((e) => _readError(e, path));
  }

  SourceFile _readError(error, Path path) {
    messages.error('exception while reading file, original message:\n $error',
        null, file: path);

    return null;
  }

  void _addDartFile(SourceFile dartFile) {
    if (dartFile == null || !_pathInfo.checkInputPath(dartFile.path)) return;

    files.add(dartFile);

    var fileInfo = new FileInfo(dartFile.path);
    info[dartFile.path] = fileInfo;
    fileInfo.inlinedCode = dartFile.code;
    fileInfo.userCode = parseDartCode(fileInfo.inlinedCode,
        fileInfo.path, messages);
    if (fileInfo.userCode.partOf != null) {
      messages.error('expected a library, not a part.', null,
          file: dartFile.path);
    }
  }

  /** Run the analyzer on every input html file. */
  void _analyze() {
    var uniqueIds = new IntIterator();
    for (var file in files) {
      if (file.isDart) continue;
      _time('Analyzed contents', file.path,
          () => analyzeFile(file, info, uniqueIds));
    }
  }

  /** Emit the generated code corresponding to each input file. */
  void _emit() {
    for (var file in files) {
      if (file.isDart) continue;
      _time('Codegen', file.path, () {
        var fileInfo = info[file.path];
        cleanHtmlNodes(fileInfo);
        _emitComponents(fileInfo);
        if (fileInfo.isEntryPoint && fileInfo.codeAttached) {
          _emitMainDart(file);
          _emitMainHtml(file);
        }
      });
    }
  }

  // TODO(jmesserly): should we bundle a copy of dart.js and link to that?
  // This URL doesn't work offline, see http://dartbug.com/6723
  static const String DART_LOADER =
      '<script type="text/javascript" src="http://dart.googlecode.com/'
      'svn/branches/bleeding_edge/dart/client/dart.js"></script>\n';

  /** Emit the main .dart file. */
  void _emitMainDart(SourceFile file) {
    var fileInfo = info[file.path];
    var contents = new MainPageEmitter(fileInfo).run(file.document, _pathInfo);
    output.add(new OutputFile(_pathInfo.outputLibraryPath(fileInfo), contents,
        source: fileInfo.inputPath));
  }

  /** Generate an html file with the (trimmed down) main html page. */
  void _emitMainHtml(SourceFile file) {
    var fileInfo = info[file.path];

    // Clear the body, we moved all of it
    var document = file.document;
    var bootstrapName =
        _pathInfo.mangle('${file.path.filename}_bootstrap.dart','');
    output.add(new OutputFile(
        _pathInfo.outputDirPath(file.path).append(bootstrapName),
        codegen.bootstrapCode(_pathInfo.relativePath(fileInfo, fileInfo))));

    // TODO(jmesserly): should we be adding the loader script?
    var dartLoader = DART_LOADER;
    for (var script in document.queryAll('script')) {
      var src = script.attributes['src'];
      if (src != null && src.split('/').last == 'dart.js') {
        dartLoader = '';
        break;
      }
    }

    document.body.nodes.add(parseFragment(
      '$dartLoader'
      '<script type="application/dart" src="$bootstrapName"></script>'
    ));

    for (var link in document.head.queryAll('link')) {
      if (link.attributes["rel"] == "components") {
        link.remove();
      }
    }

    _addAutoGeneratedComment(file);
    output.add(new OutputFile(_pathInfo.outputPath(file.path, '.html'),
        document.outerHTML, source: file.path));
  }

  /** Emits the Dart code for all components in [fileInfo]. */
  void _emitComponents(FileInfo fileInfo) {
    for (var component in fileInfo.declaredComponents) {
      var code = new WebComponentEmitter(fileInfo).run(component, _pathInfo);
      output.add(new OutputFile(_pathInfo.outputLibraryPath(component), code,
          source: component.externalFile));
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
          doctype.sourceSpan, file: file.path);
    }
  }
  document.nodes.insertAt(commentIndex, parseFragment(
      '\n<!-- This file was auto-generated from template ${file.path}. -->\n'));
}
