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

  /** Force mangling any generated name (even when --out is provided). */
  final bool forceMangle;

  /** File to process by the compiler. */
  String inputFile;

  /** Directory where all sources are found. */
  final String baseDir;

  /** Directory where all output will be generated. */
  final String outputDir;

  /**
   * Whether to print error messages using the json format understood by the
   * Dart editor.
   */
  final bool jsonFormat;

  // We could make this faster, if it ever matters.
  factory CompilerOptions() => parse(['']);

  CompilerOptions.fromArgs(ArgResults args)
    : warningsAsErrors = args['warnings_as_errors'],
      verbose = args['verbose'],
      clean = args['clean'],
      useColors = args['colors'],
      baseDir = args['basedir'],
      outputDir = args['out'],
      forceMangle = args['unique_output_filenames'],
      jsonFormat = args['json_format'],
      inputFile = args.rest.length > 0 ? args.rest[0] : null;

  static CompilerOptions parse(List<String> arguments) {
    var parser = new ArgParser()
      ..addFlag('verbose', abbr: 'v',
          defaultsTo: false, negatable: false)
      ..addFlag('clean', help: 'Remove all generated files',
          defaultsTo: false, negatable: false)
      ..addFlag('warnings_as_errors', abbr: 'e',
          help: 'Warnings handled as errors',
          defaultsTo: false, negatable: false)
      ..addFlag('colors', help: 'Display errors/warnings in colored text',
          defaultsTo: true)
      ..addFlag('unique_output_filenames', abbr: 'u',
          help: 'Use unique names for all generated files, so they will not '
                'have the same name as your input files, even if they are in a '
                'different directory',
          defaultsTo: false, negatable: false)
      ..addFlag('json_format',
          help: 'Print error messsages in a json format easy to parse by tools,'
                ' such as the Dart editor',
          defaultsTo: false, negatable: false)
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
