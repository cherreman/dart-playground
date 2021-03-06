// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/** Common utility functions used by code generated by the dwc compiler. */
library templating;

import 'dart:html';
import 'dart:uri';
import 'package:web_ui/safe_html.dart';
import 'package:web_ui/watcher.dart';

/**
 * Removes all sibling nodes from `start.nextNode` until [end] (inclusive). For
 * convinience, this function returns [start].
 */
Node removeNodes(Node start, Node end) {
  var parent = end != null ? end.parentNode : null;
  if (parent == null) return start;

  while (start != end) {
    var prev = end.previousNode;
    // TODO(sigmund): use `end.remove()` after dartbug.com/7173 is fixed
    parent.$dom_removeChild(end);
    end = prev;
  }
  return start;
}

/**
 * Take the value of a bound expression and creates an HTML node with its value.
 * Normally bindings are associated with text nodes, unless [binding] has the
 * [SafeHtml] type, in which case an html element is created for it.
 */
Node nodeForBinding(binding) => binding is SafeHtml
    ? new Element.html(binding.toString()) : new Text(binding.toString());

/**
 * Updates a data-bound [node] to a new [value]. If the new value is not
 * [SafeHtml] and the node is a [Text] node, then we update the node in place.
 * Otherwise, the node is replaced in the DOM tree and the new node is returned.
 * [stringValue] should be equivalent to `value.toString()` and can be passed
 * here if it has already been computed.
 */
Node updateBinding(value, Node node, [String stringValue]) {
  var isSafeHtml = value is SafeHtml;
  if (stringValue == null) {
    stringValue = value.toString();
  }

  if (!isSafeHtml && node is Text) {
    node.text = stringValue;
  } else {
    var old = node;
    node = isSafeHtml ? new Element.html(stringValue) : new Text(stringValue);
    old.replaceWith(node);
  }
  return node;
}

/**
 * Insert every node in [nodes] under [parent] before [reference]. [reference]
 * should be a child of [parent] or `null` if inserting at the end.
 */
void insertAllBefore(Node parent, Node reference, List<Node> nodes) {
  nodes.forEach((n) => parent.insertBefore(n, reference));
}

/**
 * Adds CSS [classes] if [addClasses] is true, otherwise removes them.
 * This is useful to keep one or more CSS classes in sync with a boolean
 * property.
 *
 * The classes parameter can be either a [String] or [List<String>].
 * If it is a single string, it may contain spaces and several class names.
 * If it is a list of strings, null and empty strings are ignored.
 * Any other type except null will throw an [ArgumentError].
 *
 * For example:
 *
 *     updateCssClass(node, item.isDone, 'item-checked item-completed');
 *
 * It can also be used with a watcher:
 *
 *     watch(() => item.isDone, (e) {
 *       updateCssClass(node, e.newValue, 'item-checked item-completed');
 *     });
 *
 * If the set of classes is changing dynamically, it is better to use
 * [bindCssClasses].
 */
void updateCssClass(Element elem, bool addClasses, classes) {
  if (classes == '' || classes == null) return;
  if (addClasses) {
    // Add classess
    if (classes is String) {
      if (classes.contains(' ')) {
        elem.classes.addAll(classes.split(' '));
      } else {
        elem.classes.add(classes);
      }
    } else if (classes is List<String>) {
      elem.classes.addAll(classes.filter((e) => e != null && e != ''));
    } else {
      throw new ArgumentError('classes must be a String or List<String>.');
    }
  } else {
    // Remove classes
    if (classes is String) {
      if (classes.contains(' ')) {
        elem.classes.removeAll(classes.split(' '));
      } else {
        elem.classes.remove(classes);
      }
    } else if (classes is List<String>) {
      elem.classes.removeAll(classes.filter((e) => e != null && e != ''));
    } else {
      throw new ArgumentError('classes must be a String or List<String>.');
    }
  }
}

/**
 * Bind the result of [exp] to the class attribute in [elem]. [exp] is a closure
 * that can return a string, a list of strings, an string with spaces, or null.
 *
 * You can bind a single class attribute by binding a getter to the property
 * defining your class.  For example,
 *
 *     var class1 = 'pretty';
 *     bindCssClasses(e, () => class1);
 *
 * In this example, if you update class1 to null or an empty string, the
 * previous value ('pretty') is removed from the element.
 *
 * You can bind multiple class attributes in several ways: by returning a list
 * of values in [exp], by returning in [exp] a string with multiple classes
 * separated by spaces, or by calling this function several times. For example,
 * suppose you want to bind 2 classes on an element,
 *
 *     var class1 = 'pretty';
 *     var class2 = 'selected';
 *
 * and you want to independently change class1 and class2. For instance, If you
 * set `class1` to null, you'd like `pretty` will be removed from `e.classes`,
 * but `selected` to be kept.  The tree alternatives mentioned earlier look as
 * follows:
 *
 *   * binding classes with a list:
 *
 *         bindCssClasses(e, () => [class1, class2]);
 *
 *   * binding classes with a string:
 *
 *         bindCssClasses(e, () => "${class1 != null ? class1 : ''} "
 *                                 "${class2 != null ? class2 : ''}");
 *
 *   * binding classes separately:
 *
 *         bindCssClasses(e, () => class1);
 *         bindCssClasses(e, () => class2);
 */
WatcherDisposer bindCssClasses(Element elem, dynamic exp()) {
  return watchAndInvoke(exp, (e) {
    updateCssClass(elem, false, e.oldValue);
    updateCssClass(elem, true, e.newValue);
  });
}

/** Bind the result of [exp] to the style attribute in [elem]. */
WatcherDisposer bindStyle(Element elem, Map<String, String> exp()) {
  return watchAndInvoke(exp, (e) {
    if (e.oldValue is Map<String, String>) {
      var props = e.newValue;
      if (props is! Map<String, String>) props = const {};
      for (var property in e.oldValue.keys) {
        if (!props.containsKey(property)) {
          // Value will not be overwritten with new setting. Remove.
          elem.style.removeProperty(property);
        }
      }
    }
    if (e.newValue is! Map<String, String>) {
      throw new DataBindingError("Expected Map<String, String> value "
        "to data-style binding.");
    }
    e.newValue.forEach(elem.style.setProperty);
  });
}

/**
 * Ensure that [usiString] is a safe URI. Otherwise, return a '#' URL.
 *
 * The logic in this method was based on the GWT implementation located at:
 * http://code.google.com/p/google-web-toolkit/source/browse/trunk/user/src/com/google/gwt/safehtml/shared/UriUtils.java
 */
String sanitizeUri(uri) {
  if (uri is SafeUri) return uri.toString();
  uri = uri.toString();
  return _isSafeUri(uri) ? uri : '#';
}

const _SAFE_SCHEMES = const ["http", "https", "ftp", "mailto"];

bool _isSafeUri(String uri) {
  var scheme = new Uri(uri).scheme;
  if (scheme == '') return true;

  // There are two checks for mailto to correctly handle the Turkish locale.
  //   i -> to upper in Turkish locale -> İ
  //   I -> to lower in Turkish locale -> ı
  // For details, see: http://www.i18nguy.com/unicode/turkish-i18n.html
  return _SAFE_SCHEMES.contains(scheme.toLowerCase()) ||
      "MAILTO" == scheme.toUpperCase();
}

/** An error thrown when data bindings are set up with incorrect data. */
class DataBindingError implements Error {
  final message;
  DataBindingError(this.message);
  toString() => "Data binding error: $message";
}
