// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library messages;

import 'dart:json';

import 'package:html5lib/dom_parsing.dart' show SourceSpan;
import 'package:logging/logging.dart' show Level;

import 'file_system/path.dart';
import 'options.dart';
import 'utils.dart';

// TODO(jmesserly): remove the global messages. We instead use some
// object that tracks compilation state.

/** The global [Messages] for tracking info/warnings/messages. */
Messages messages;

/** Map between error levels and their display color. */
final Map<Level, String> _ERROR_COLORS = (() {
  // TODO(jmesserly): the SourceSpan printer does not use our colors.
  var colorsMap = new Map<Level, String>();
  colorsMap[Level.SEVERE] = RED_COLOR;
  colorsMap[Level.WARNING] = MAGENTA_COLOR;
  colorsMap[Level.INFO] = GREEN_COLOR;
  return colorsMap;
})();

/** A single message from the compiler. */
class Message {
  final Level level;
  final String message;
  final Path file;
  final SourceSpan span;
  final bool useColors;

  Message(this.level, this.message, {this.file, this.span,
      this.useColors: false});

  String toString() {
    var output = new StringBuffer();
    bool colors = useColors && _ERROR_COLORS.containsKey(level);
    if (colors) output.add(_ERROR_COLORS[level]);
    output.add(level.name).add(' ');
    if (colors) output.add(NO_COLOR);

    if (span == null) {
      if (file != null) output.add('$file: ');
      output.add(message);
    } else {
      output.add(span.toMessageString(
          file.toString(), message, useColors: colors));
    }

    return output.toString();
  }

  String toJson() {
    if (file == null) return toString();

    var kind = (level == Level.SEVERE ? 'error' :
        (level == Level.WARNING ? 'warning' : 'info'));
    var json = {
      'method': kind,
      'params': {
        'file': file.toString(),
        'message': message,
        'line': span == null ? 1 : span.line + 1,
      }
    };
    if (span != null) {
      json['params']['charStart'] = span.start;
      json['params']['charEnd'] = span.end;
    }
    return JSON.stringify([json]);
  }
}

/**
 * This class tracks and prints information, warnings, and errors emitted by the
 * compiler.
 */
class Messages {
  final CompilerOptions options;
  final bool shouldPrint;

  final List<Message> messages = <Message>[];

  Messages({CompilerOptions options, this.shouldPrint: true})
      : options = options != null ? options : new CompilerOptions();

  // Convenience methods for testing
  int get length => messages.length;
  Message operator[](int index) => messages[index];
  void clear() {
    messages.clear();
  }

  /** [message] is considered a static compile-time error by the Dart lang. */
  void error(String message, SourceSpan span, {Path file}) {
    var msg = new Message(Level.SEVERE, message, file: file, span: span,
        useColors: options.useColors);

    messages.add(msg);
    printMessage(msg);
  }

  /** [message] is considered a type warning by the Dart lang. */
  void warning(String message, SourceSpan span, {Path file}) {
    if (options.warningsAsErrors) {
      error(message, span, file: file);
    } else {
      var msg = new Message(Level.WARNING, message, file: file,
          span: span, useColors: options.useColors);

      messages.add(msg);
      printMessage(msg);
    }
  }

  /**
   * [message] at [file] will tell the user about what the compiler
   * is doing.
   */
  void info(String message, SourceSpan span, {Path file}) {
    var msg = new Message(Level.INFO, message, file: file, span: span,
        useColors: options.useColors);

    messages.add(msg);
    if (options.verbose) printMessage(msg);
  }

  void printMessage(msg) {
    if (shouldPrint) print(options.jsonFormat ? msg.toJson() : msg);
  }
}
