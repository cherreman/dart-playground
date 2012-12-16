// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/** The entry point to the compiler. Used to implement `bin/dwc.dart`. */
library dwc;

import 'dart:io';
import 'package:logging/logging.dart' show Level;
import 'src/compiler.dart';
import 'src/file_system.dart';
import 'src/file_system/console.dart';
import 'src/file_system/path.dart' as fs;
import 'src/files.dart';
import 'src/messages.dart';
import 'src/options.dart';
import 'src/utils.dart';

FileSystem fileSystem;

void main() {
  run(new Options().arguments).then((result) {
    exit(result.success ? 0 : 1);
  });
}

/** Contains the result of a compiler run. */
class CompilerResult {
  final bool success;
  /** Map of output path to source, if there is one */
  final Map<String, String> outputs;
  final List<String> messages;
  String bootstrapFile;

  CompilerResult([this.success = true,
                  this.outputs,
                  this.messages = const [],
                  this.bootstrapFile]);

  factory CompilerResult._(Messages messages, List<OutputFile> outputs) {
    var success = !messages.messages.some((m) => m.level == Level.SEVERE);
    var file;
    var outs = new Map<String, String>();
    for (var out in outputs) {
      if (out.path.filename.endsWith('_bootstrap.dart')) {
        file = out.path.toString();
      }
      var sourcePath = (out.source == null) ? null : out.source.toString();
      var outputPath = out.path.toString();
      outs[outputPath] = sourcePath;
    }
    var msgs = messages.messages.map((m) => m.toString());
    return new CompilerResult(success, outs, msgs, file);
  }
}

/**
 * Runs the web components compiler with the command-line options in [args].
 * See [CompilerOptions] for the definition of valid arguments.
 */
// TODO(jmesserly): fix this to return a proper exit code
// TODO(justinfagnani): return messages in the result
Future<CompilerResult> run(List<String> args) {
  var options = CompilerOptions.parse(args);
  if (options == null) return new Future.immediate(new CompilerResult());

  fileSystem = new ConsoleFileSystem();
  messages = new Messages(options: options, shouldPrint: true);

  return asyncTime('Total time spent on ${options.inputFile}', () {
    var currentDir = new Directory.current().path;
    var compiler = new Compiler(fileSystem, options, currentDir);
    var res;
    return compiler.run()
      .transform((_) => (res = new CompilerResult._(messages, compiler.output)))
      .chain((_) => symlinkPubPackages(res, options))
      .chain((_) => emitFiles(compiler.output, options.clean))
      .transform((_) => res);
  }, printTime: true, useColors: options.useColors);
}

Future emitFiles(List<OutputFile> outputs, bool clean) {
  outputs.forEach((f) => writeFile(f.path, f.contents, clean));
  return fileSystem.flush();
}

void writeFile(fs.Path path, String contents, bool clean) {
  if (clean) {
    File fileOut = new File.fromPath(_convert(path));
    if (fileOut.existsSync()) {
      fileOut.deleteSync();
    }
  } else {
    _createIfNeeded(_convert(path.directoryPath));
    fileSystem.writeString(path, contents);
  }
}

void _createIfNeeded(Path outdir) {
  if (outdir.isEmpty) return;
  var outDirectory = new Directory.fromPath(outdir);
  if (!outDirectory.existsSync()) {
    _createIfNeeded(outdir.directoryPath);
    outDirectory.createSync();
  }
}

/**
 * Creates a symlink to the pub packages directory in the output location. The
 * returned future completes when the symlink was created (or immediately if it
 * already exists).
 */
Future symlinkPubPackages(CompilerResult result, CompilerOptions options) {
  if (options.outputDir == null || result.bootstrapFile == null) {
    // We don't need to copy the packages directory if the output was generated
    // in-place where the input lives or if the compiler was called without an
    // entry-point file.
    return new Future.immediate(null);
  }

  var linkDir = new Path(result.bootstrapFile).directoryPath;
  _createIfNeeded(linkDir);
  var linkPath = linkDir.append('packages');
  // A resolved symlink works like a directory
  // TODO(sigmund): replace this with something smarter once we have good
  // symlink support in dart:io
  if (new Directory.fromPath(linkPath).existsSync()) {
    // Packages directory already exists.
    return new Future.immediate(null);
  }

  // A broken symlink works like a file
  var toFile = new File.fromPath(linkPath);
  if (toFile.existsSync()) {
    toFile.deleteSync();
  }

  var targetPath = new Path(options.inputFile).directoryPath.append('packages');
  // [fullPathSync] will canonicalize the path, resolving any symlinks.
  // TODO(sigmund): once it's possible in dart:io, we just want to use a full
  // path, but not necessarily resolve symlinks.
  var target = new File.fromPath(targetPath).fullPathSync().toString();
  var link = linkPath.toNativePath().toString();
  return createSymlink(target, link);
}


// TODO(jmesserly): this code was taken from Pub's io library.
// Added error handling and don't return the file result, to match the code
// we had previously. Also "target" and "link" only accept strings. And inlined
// the relevant parts of runProcess. Note that it uses "cmd" to get the path
// on Windows.
/**
 * Creates a new symlink that creates an alias of [target] at [link], both of
 * which can be a [String], [File], or [Directory]. Returns a [Future] which
 * completes to the symlink file (i.e. [link]).
 */
Future createSymlink(String target, String link) {
  var command = 'ln';
  var args = ['-s', target, link];

  if (Platform.operatingSystem == 'windows') {
    // Call mklink on Windows to create an NTFS junction point. Only works on
    // Vista or later. (Junction points are available earlier, but the "mklink"
    // command is not.) I'm using a junction point (/j) here instead of a soft
    // link (/d) because the latter requires some privilege shenanigans that
    // I'm not sure how to specify from the command line.
    command = 'cmd';
    args = ['/c', 'mklink', '/j', link, target];
  }

  return Process.run(command, args).transform((result) {
    if (result.exitCode != 0) {
      var details = 'subprocess stdout:\n${result.stdout}\n'
                    'subprocess stderr:\n${result.stderr}';
      messages.error(
        'unable to create symlink\n target: $target\n link:$link\n$details',
        null);
    }
    return null;
  });
}


// TODO(sigmund): this conversion from dart:io paths to internal paths should
// go away when dartbug.com/5818 is fixed.
Path _convert(fs.Path path) => new Path(path.toString());
