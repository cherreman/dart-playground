// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Part of the template compilation that concerns with simplifying HTML trees to
 * emit trimmed simple HTML code.
 */
library html_cleaner;

import 'package:html5lib/dom.dart';

import 'info.dart';

/** Removes bindings and extra nodes from the HTML assciated with [info]. */
void cleanHtmlNodes(info) {
  new _HtmlCleaner().visit(info);
}

/** Remove all MDV attributes; post-analysis these attributes are not needed. */
class _HtmlCleaner extends InfoVisitor {

  void visitComponentInfo(ComponentInfo info) {
    // Remove the <element> tag from the tree
    if (info.elemInfo != null) info.elemInfo.node.remove();
    super.visitComponentInfo(info);
  }

  void visitElementInfo(ElementInfo info) {
    var node = info.node;
    if (info.hasIterate || info.hasIfCondition) {
      // Remove children but not template node itself
      node.nodes.clear();

      // Hide all template elements. At the very least, we must do this for
      // template attributes, such as `<td template instantiate="if cond">`.
      // TODO(jmesserly): should probably inject a stylesheet into the page:
      // http://dvcs.w3.org/hg/webcomponents/raw-file/tip/spec/templates/index.html#css-additions
      if (info.isTemplateElement || info.hasIfCondition) {
        node.attributes['style'] = 'display:none';
      }
    } else if (info.childrenCreatedInCode && node.parent != null) {
      // clear the children from info's parent perspective, but keep it in the
      // node so that the emitter can use them when generating code for [info].
      var clone = node.clone();
      node.parent.insertBefore(clone, node);
      node.remove();
    }

    for (var name in info.attributes.keys) {
      if (name != 'class') node.attributes.remove(name);
    }

    const [
      'data-action', 'data-bind', 'data-value',
      'instantiate', 'iterate', 'template'
    ].forEach(node.attributes.remove);

    super.visitElementInfo(info);
  }
}
