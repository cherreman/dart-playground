// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library browser;

import 'dart:math';
import 'dart:html';
import 'path.dart';
import 'package:web_components/src/file_system.dart';
import 'package:js/js.dart' as js;

/**
 * File system implementation indirectly using the Chrome Extension Api's to
 * proxy arbitrary urls. See extension/background.js for the code that does
 * the actual proxying.
 */
class BrowserFileSystem implements FileSystem {

  /**
   * Chrome extension port used to communicate back to the source page that
   * will consume these proxied urls.
   */
  js.Proxy sourcePagePort;

  final _filesToProxy = <String>{};
  final _random = new Random();
  final _uriScheme;

  BrowserFileSystem(this._uriScheme, this.sourcePagePort);

  Future flush() {
    // TODO(jacobr): this should really only return the future when the
    // urls are fully proxied.
    js.scoped(() {
      var requests = [];
      _filesToProxy.forEach((k,v) {
        requests.add( js.map({'url': k, 'content': v}));
      });
      _filesToProxy.clear();
      js.context.proxyUrls(sourcePagePort, js.array(requests));
    });

    return new Future.immediate(null);
  }

  void writeString(Path path, String text) {
    _filesToProxy['$_uriScheme://$path'] = text;
  }

  // TODO(jmesserly): read bytes on browsers that support XHR v2
  // Or restructure the code to use the browser's builtin HTML parser :)
  Future readTextOrBytes(Path path) => readText(path);

  Future<String> readText(Path path) {
    var completer = new Completer<String>();
    // We must add a random id or a timestamp to defeat proxy servers and Chrome
    // caching when accessing file urls.
    var uniqueUrl = '$_uriScheme://$path?random_id=${_random.nextDouble()}';
    new HttpRequest.get(uniqueUrl, onSuccess(HttpRequest request) {
      completer.complete(request.responseText);
    });
    return completer.future;
  }
}
