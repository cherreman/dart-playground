// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(sigmund): move this library to a shared package? or make part of
// dart:html?
library safe_html;

/** Declares a string that is a well-formed HTML fragment. */
class SafeHtml {

  /** Underlying html string. */
  String _html;

  // TODO(sigmund): provide a constructor that does html validation
  SafeHtml.unsafe(this._html);

  String toString() => _html;
}
