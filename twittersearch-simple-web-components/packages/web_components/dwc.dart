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
import 'src/messages.dart';
import 'src/options.dart';
import 'src/utils.dart';

FileSystem fileSystem;

void main() {
  run(new Options().arguments);
}

/** Contains the result of a compiler run. */
class CompilerResult {
  final bool success;
  final List<String> outputs;
  final List<String> messages;
  CompilerResult(this.success, this.outputs, this.messages);
}

/**
 * Runs the web components compiler with the command-line options in [args].
 * See [CompilerOptions] for the definition of valid arguments.
 */
// TODO(jmesserly): fix this to return a proper exit code
// TODO(justinfagnani): return messages in the result
Future<CompilerResult> run(List<String> args) {
  var options = CompilerOptions.parse(args);
  if (options == null) return new Future.immediate(null);

  fileSystem = new ConsoleFileSystem();
  messages = new Messages(options: options);

  return asyncTime('Total time spent on ${options.inputFile}', () {
    var currentDir = new Directory.current().path;
    var compiler = new Compiler(fileSystem, options, currentDir);
    return compiler.run()
      .chain((_) {
        var entryPoint = null;
        // Write out the code associated with each source file.
        for (var file in compiler.output) {
          writeFile(file.path, file.contents, options.clean);
          if (file.path.filename.endsWith('_bootstrap.dart')) {
            entryPoint = file.path;
          }
        }
        return symlinkPubPackages(entryPoint, options);
      })
      .chain((_) => fileSystem.flush())
      .transform((_) => new CompilerResult(
            !messages.messages.some((m) => m.level == Level.SEVERE),
            compiler.output.map((f) => f.path.toString()),
            messages.messages.map((m) => m.toString())));
  }, printTime: true);
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
Future symlinkPubPackages(fs.Path outputFile, CompilerOptions options) {
  if (outputFile == null || options.outputDir == null) {
    // We don't need to copy the packages directory if the compiler was called
    // without an entry-point file or if the output was generated in-place where
    // the input lives.
    return new Future.immediate(null);
  }

  var toPath = _convert(outputFile.directoryPath.append('packages'));
  // A resolved symlink works like a directory
  // TODO(sigmund): replace this with something smarter once we have good
  // symlink support in dart:io
  if (new Directory.fromPath(toPath).existsSync()) {
    // Packages directory already exists.
    return new Future.immediate(null);
  }

  // A broken symlink works like a file
  var toFile = new File.fromPath(toPath);
  if (toFile.existsSync()) {
    toFile.deleteSync();
  }

  var fromPath = new Path(options.inputFile).directoryPath.append('packages');
  // [fullPathSync] will canonicalize the path, resolving any symlinks.
  // TODO(sigmund): once it's possible in dart:io, we just want to use a full
  // path, but not necessarily resolve symlinks.
  var from = new File.fromPath(fromPath).fullPathSync().toString();
  var to = toPath.toNativePath().toString();
  return createSymlink(from, to);
}


// TODO(jmesserly): this code was taken from Pub's io library.
// Added error handling and don't return the file result, to match the code
// we had previously. Also "from" and "to" only accept strings. And inlined
// the relevant parts of runProcess. Note that it uses "cmd" to get the path
// on Windows.
/**
 * Creates a new symlink that creates an alias from [from] to [to], both of
 * which can be a [String], [File], or [Directory]. Returns a [Future] which
 * completes to the symlink file (i.e. [to]).
 */
Future createSymlink(String from, String to) {
  var command = 'ln';
  var args = ['-s', from, to];

  if (Platform.operatingSystem == 'windows') {
    // Call mklink on Windows to create an NTFS junction point. Only works on
    // Vista or later. (Junction points are available earlier, but the "mklink"
    // command is not.) I'm using a junction point (/j) here instead of a soft
    // link (/d) because the latter requires some privilege shenanigans that
    // I'm not sure how to specify from the command line.
    command = 'cmd';
    args = ['/c', 'mklink', '/j', to, from];
  }

  return Process.run(command, args).transform((result) {
    if (result.exitCode != 0) {
      var details = 'subprocess stdout:\n${result.stdout}\n'
                    'subprocess stderr:\n${result.stderr}';
      messages.error(
        'unable to create symlink\n from: $from\n to:$to\n$details', null);
    }
    return null;
  });
}


// TODO(sigmund): this conversion from dart:io paths to internal paths should
// go away when dartbug.com/5818 is fixed.
Path _convert(fs.Path path) => new Path(path.toString());
