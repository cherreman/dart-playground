// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Common logic to make it easy to create a `build.dart` for your project.
 *
 * The `build.dart` script is invoked automatically by the Editor whenever a
 * file in the project changes. It must be placed in the root of a project
 * (where pubspec.yaml lives) and should be named exactly 'build.dart'.
 *
 * A common `build.dart` would look as follows:
 *
 *     import 'dart:io';
 *     import 'package:web_ui/component_build.dart';
 *
 *     main() => build(new Options().arguments, ['web/main.html']);
 *
 *
 */
library build_utils;

import 'dart:io';
import 'package:args/args.dart';
import 'package:web_ui/dwc.dart' as dwc;

/**
 * Set up 'build.dart' to compile with the dart web components compiler every
 * [entryPoints] listed. On clean commands, the directory where [entryPoints]
 * live will be scanned for generated files to delete them.
 */
// TODO(jmesserly): we need a better way to automatically detect input files
void build(List<String> arguments, List<String> entryPoints) {
  var args = _processArgs(arguments);

  var trackDirs = <Directory>[];
  var changedFiles = args["changed"];
  var removedFiles = args["removed"];
  var cleanBuild = args["clean"];
  var machineFormat = args["machine"];
  var fullBuild = changedFiles.isEmpty && removedFiles.isEmpty && !cleanBuild;

  for (var file in entryPoints) {
    trackDirs.add(new Directory(_outDir(file)));
  }

  if (cleanBuild) {
    _handleCleanCommand(trackDirs);
  } else if (fullBuild || changedFiles.some((f) => _isInputFile(f, trackDirs))
      || removedFiles.some((f) => _isInputFile(f, trackDirs))) {
    for (var file in entryPoints) {
      var path = new Path(file);
      var outDir = path.directoryPath.append('out');
      var args = [];
      if (machineFormat) args.add('--json_format');
      if (Platform.operatingSystem == 'windows') args.add('--no-colors');
      args.addAll(['-o', outDir.toString(), file]);
      dwc.run(args);

      if (machineFormat) {
        // Print for the Dart Editor the mapping from the input entry point file
        // and its corresponding output.
        var out = outDir.append(path.filename);
        print('[{"method":"mapping","params":{"from":"$file","to":"$out"}}]');
      }
    }
  }
}

String _outDir(String file) =>
  new Path(file).directoryPath.append('out').toString();

bool _isGeneratedFile(String filePath, List<Directory> outputDirs) {
  var path = new Path.fromNative(filePath);
  for (var dir in outputDirs) {
    if (path.directoryPath.toString() == dir.path) return true;
  }
  return path.filename.startsWith('_');
}

bool _isInputFile(String path, List<Directory> outputDirs) {
  return (path.endsWith(".dart") || path.endsWith(".html"))
      && !_isGeneratedFile(path, outputDirs);
}

/** Delete all generated files. */
void _handleCleanCommand(List<Directory> trackDirs) {
  for (var dir in trackDirs) {
    dir.exists().then((exists) {
      if (!exists) return;
      dir.list(recursive: false).onFile = (path) {
        if (_isGeneratedFile(path, trackDirs)) {
          // TODO(jmesserly): we need a cleaner way to do this with dart:io.
          // The bug is that DirectoryLister returns native paths, so you need
          // to use Path.fromNative to work around this. Ideally we could just
          // write: new File(path).delete();
          new File.fromPath(new Path.fromNative(path)).delete();
        }
      };
    });
  }
}

/** Handle --changed, --removed, --clean and --help command-line args. */
ArgResults _processArgs(List<String> arguments) {
  var parser = new ArgParser()
    ..addOption("changed", help: "the file has changed since the last build",
        allowMultiple: true)
    ..addOption("removed", help: "the file was removed since the last build",
        allowMultiple: true)
    ..addFlag("clean", negatable: false, help: "remove any build artifacts")
    ..addFlag("machine", negatable: false,
        help: "produce warnings in a machine parseable format")
    ..addFlag("help", negatable: false, help: "displays this help and exit");
  var args = parser.parse(arguments);
  if (args["help"]) {
    print(parser.getUsage());
    exit(0);
  }
  return args;
}
