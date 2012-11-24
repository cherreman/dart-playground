// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library options;

import 'package:args/args.dart';

class CompilerOptions {
  /** Report warnings as errors. */
  final bool warningsAsErrors;

  /** True to show informational messages. The `--verbose` flag. */
  final bool verbose;

  /** Remove any generated files. */
  final bool clean;

  /** Whether to use colors to print messages on the terminal. */
  final bool useColors;
  
  /** File to process by the compiler. */
  String inputFile;

  /** Directory where all sources are found. */
  final String baseDir;

  /** Directory where all output will be generated. */
  final String outputDir;

  // We could make this faster, if it ever matters.
  factory CompilerOptions() => parse(['']);

  CompilerOptions.fromArgs(ArgResults args)
    : warningsAsErrors = args['warnings_as_errors'],
      verbose = args['verbose'],
      clean = args['clean'],
      useColors = args['colors'],
      baseDir = args['basedir'],
      outputDir = args['out'],
      inputFile = args.rest.length > 0 ? args.rest[0] : null;

  static CompilerOptions parse(List<String> arguments) {
    var parser = new ArgParser()
      ..addFlag('verbose', abbr: 'v',
          defaultsTo: false, negatable: false)
      ..addFlag('clean', help: 'Remove all generated files',
          defaultsTo: false, negatable: false)
      ..addFlag('warnings_as_errors', help: 'Warning handled as errors',
          defaultsTo: false, negatable: false)
      ..addFlag('colors', help: 'Display errors/warnings in colored text',
          defaultsTo: true)
      ..addOption('out', abbr: 'o', help: 'Directory where to generate files'
          ' (defaults to the same directory as the source file)')
      ..addOption('basedir', help: 'Base directory where to find all source '
          'files (defaults to the source file\'s directory)')
      ..addFlag('help', abbr: 'h', help: 'Displays this help message',
          defaultsTo: false, negatable: false);
    try {
      var results = parser.parse(arguments);
      if (results['help'] || results.rest.length == 0) {
        showUsage(parser);
        return null;
      }
      return new CompilerOptions.fromArgs(results);
    } on FormatException catch (e) {
      print(e.message);
      showUsage(parser);
      return null;
    }
  }

  static showUsage(parser) {
    print('Usage: dwc [options...] input.html');
    print(parser.getUsage());
  }
}
