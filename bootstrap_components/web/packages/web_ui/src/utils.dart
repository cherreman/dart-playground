// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library web_components.src.utils;

import 'dart:isolate';
import 'package:web_ui/src/messages.dart';

/**
 * Converts a string name with hyphens into an identifier, by removing hyphens
 * and capitalizing the following letter. Optionally [startUppercase] to
 * captialize the first letter.
 */
String toCamelCase(String hyphenedName, {bool startUppercase: false}) {
  var segments = hyphenedName.split('-');
  int start = startUppercase ? 0 : 1;
  for (int i = start; i < segments.length; i++) {
    var segment = segments[i];
    if (segment.length > 0) {
      // Character between 'a'..'z' mapped to 'A'..'Z'
      segments[i] = '${segment[0].toUpperCase()}${segment.substring(1)}';
    }
  }
  return Strings.join(segments, '');
}

/**
 * Invokes [callback], logs how long it took to execute in ms, and returns
 * whatever [callback] returns. The log message will be printed if [printTime]
 * is true.
 */
time(String logMessage, callback(),
     {bool printTime: false, bool useColors: false}) {
  final watch = new Stopwatch();
  watch.start();
  var result = callback();
  watch.stop();
  final duration = watch.elapsedMilliseconds;
  if (printTime) {
    _printMessage(logMessage, duration, useColors);
  }
  return result;
}

/**
 * Invokes [callback], logs how long it takes from the moment [callback] is
 * executed until the future it returns is completed. Returns the future
 * returned by [callback]. The log message will be printed if [printTime]
 * is true.
 */
Future asyncTime(String logMessage, Future callback(),
                 {bool printTime: false, bool useColors: false}) {
  final watch = new Stopwatch();
  watch.start();
  return callback()..then((_) {
    watch.stop();
    final duration = watch.elapsedMilliseconds;
    if (printTime) {
      _printMessage(logMessage, duration, useColors);
    }
  });
}

void _printMessage(String logMessage, int duration, bool useColors) {
  var buf = new StringBuffer();
  buf.add(logMessage);
  for (int i = logMessage.length; i < 60; i++) buf.add(' ');
  buf.add(' -- ');
  if (useColors) {
    buf.add(GREEN_COLOR);
  }
  if (duration < 10) buf.add(' ');
  if (duration < 100) buf.add(' ');
  buf.add(duration).add(' ms');
  if (useColors) {
    buf.add(NO_COLOR);
  }
  print(buf.toString());
}

// Color constants used for generating messages.
final String GREEN_COLOR = '\u001b[32m';
final String RED_COLOR = '\u001b[31m';
final String MAGENTA_COLOR = '\u001b[35m';
final String NO_COLOR = '\u001b[0m';

/** Find and return the first element in [list] that satisfies [matcher]. */
find(List list, bool matcher(elem)) {
  for (var elem in list) {
    if (matcher(elem)) return elem;
  }
  return null;
}


/** A completer that waits until all added [Future]s complete. */
// TODO(sigmund): this should be part of the futures/core libraries.
class FutureGroup {
  const _FINISHED = -1;

  int _pending = 0;
  Future _failedTask;
  final Completer<List> _completer = new Completer<List>();
  final List<Future> futures = <Future>[];

  /** Gets the task that failed, if any. */
  Future get failedTask => _failedTask;

  /**
   * Wait for [task] to complete.
   *
   * If this group has already been marked as completed, you'll get a
   * [FutureAlreadyCompleteException].
   *
   * If this group has a [failedTask], new tasks will be ignored, because the
   * error has already been signaled.
   */
  void add(Future task) {
    if (_failedTask != null) return;
    if (_pending == _FINISHED) throw new FutureAlreadyCompleteException();

    _pending++;
    futures.add(task);
    if (task.isComplete) {
      // TODO(jmesserly): maybe Future itself should do this itself?
      // But we'd need to fix dart:mirrors to have a sync version.
      setImmediate(() => _watchTask(task));
    } else {
      _watchTask(task);
    }
  }

  void _watchTask(Future task) {
    task.handleException((e) {
      if (_failedTask != null) return;
      _failedTask = task;
      _completer.completeException(e, task.stackTrace);
      return true;
    });
    task.then((_) {
      if (_failedTask != null) return;
      _pending--;
      if (_pending == 0) {
        _pending = _FINISHED;
        _completer.complete(futures);
      }
    });
  }

  Future<List> get future => _completer.future;
}


/**
 * Escapes [text] for use in a Dart string.
 * [single] specifies single quote `'` vs double quote `"`.
 * [triple] indicates that a triple-quoted string, such as `'''` or `"""`.
 */
String escapeDartString(String text, {bool single: true, bool triple: false}) {
  // Note: don't allocate anything until we know we need it.
  StringBuffer result = null;

  for (int i = 0; i < text.length; i++) {
    int code = text.charCodeAt(i);
    var replace = null;
    switch (code) {
      case 92/*'\\'*/: replace = r'\\'; break;
      case 36/*r'$'*/: replace = r'\$'; break;
      case 34/*'"'*/:  if (!single) replace = r'\"'; break;
      case 39/*"'"*/:  if (single) replace = r"\'"; break;
      case 10/*'\n'*/: if (!triple) replace = r'\n'; break;
      case 13/*'\r'*/: if (!triple) replace = r'\r'; break;

      // Note: we don't escape unicode characters, under the assumption that
      // writing the file in UTF-8 will take care of this.

      // TODO(jmesserly): do we want to replace any other non-printable
      // characters (such as \f) for readability?
    }

    if (replace != null && result == null) {
      result = new StringBuffer(text.substring(0, i));
    }

    if (result != null) result.add(replace != null ? replace : text[i]);
  }

  return result == null ? text : result.toString();
}

// TODO(jmesserly): this should exist in dart:isolates
/**
 * Adds an event to call [callback], so the event loop will call this after the
 * current stack has unwound.
 */
void setImmediate(void callback()) {
  var port = new ReceivePort();
  port.receive((msg, sendPort) {
    port.close();
    callback();
  });
  port.toSendPort().send(null);
}

/** Iterates through an infinite sequence, starting from zero. */
class IntIterator implements Iterator<int> {
  int _next = 0;

  bool get hasNext => true;

  int next() => _next++;
}
