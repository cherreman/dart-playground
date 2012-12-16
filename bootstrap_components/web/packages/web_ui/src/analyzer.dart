// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Part of the template compilation that concerns with extracting information
 * from the HTML parse tree.
 */
library analyzer;

import 'package:html5lib/dom.dart';
import 'package:html5lib/dom_parsing.dart';

import 'directive_parser.dart' show parseDartCode;
import 'file_system/path.dart';
import 'files.dart';
import 'info.dart';
import 'messages.dart';
import 'utils.dart';

/**
 * Finds custom elements in this file and the list of referenced files with
 * component declarations. This is the first pass of analysis on a file.
 */
FileInfo analyzeDefinitions(SourceFile file, {bool isEntryPoint: false}) {
  var result = new FileInfo(file.path, isEntryPoint);
  new _ElementLoader(result).visit(file.document);
  return result;
}

/**
 * Extract relevant information from [source] and it's children.
 * Used for testing.
 */
FileInfo analyzeNodeForTesting(Node source,
    {String filepath: 'mock_testing_file.html'}) {
  var result = new FileInfo(new Path(filepath));
  new _Analyzer(result, new IntIterator()).visit(source);
  return result;
}

/** Extract relevant information from all files found from the root document. */
void analyzeFile(SourceFile file, Map<Path, FileInfo> info,
    Iterator<int> uniqueIds) {
  var fileInfo = info[file.path];
  _normalize(fileInfo, info);
  new _Analyzer(fileInfo, uniqueIds).visit(file.document);
}


/** A visitor that walks the HTML to extract all the relevant information. */
class _Analyzer extends TreeVisitor {
  final FileInfo _fileInfo;
  LibraryInfo _currentInfo;
  ElementInfo _parent;
  Iterator<int> _uniqueIds;

  _Analyzer(this._fileInfo, this._uniqueIds) {
    _currentInfo = _fileInfo;
  }

  void visitElement(Element node) {
    var info = null;
    if (node.tagName == 'script') {
      // We already extracted script tags in previous phase.
      return;
    }

    if (node.tagName == 'template'
        || node.attributes.containsKey('template')
        || node.attributes.containsKey('if')
        || node.attributes.containsKey('instantiate')
        || node.attributes.containsKey('iterate')) {
      // template tags, conditionals and iteration are handled specially.
      info = _createTemplateInfo(node);
    }

    // TODO(jmesserly): it would be nice not to create infos for text or
    // elements that don't need data binding. Ideally, we would visit our
    // child nodes and get their infos, and if any of them need data binding,
    // we create an ElementInfo for ourselves and return it, otherwise we just
    // return null.
    if (info == null) {
      // <element> tags are tracked in the file's declared components, so they
      // don't need a parent.
      var parent = node.tagName == 'element' ? null : _parent;
      info = new ElementInfo(node, parent);
    }

    visitElementInfo(info);

    if (_parent == null) {
      _fileInfo.bodyInfo = info;
    }
  }

  void visitElementInfo(ElementInfo info) {
    var node = info.node;

    if (node.id != '') info.identifier = '__${toCamelCase(node.id)}';
    if (node.tagName == 'body' || (_currentInfo is ComponentInfo
          && (_currentInfo as ComponentInfo).template == node)) {
      info.isRoot = true;
      info.identifier = '_root';
    }

    _bindCustomElement(node, info);

    var lastInfo = _currentInfo;
    if (node.tagName == 'element') {
      // If element is invalid _ElementLoader already reported an error, but
      // we skip the body of the element here.
      var name = node.attributes['name'];
      if (name == null) return;
      var component = _fileInfo.components[name];
      if (component == null) return;

      // Associate ElementInfo of the <element> tag with its component.
      component.elemInfo = info;

      _bindExtends(component);

      _currentInfo = component;
    }

    node.attributes.forEach((k, v) => visitAttribute(info, k, v));

    var savedParent = _parent;
    _parent = info;

    // Invoke super to visit children.
    super.visitElement(node);
    _currentInfo = lastInfo;

    _parent = savedParent;

    if (_needsIdentifier(info)) {
      _ensureParentHasQuery(info);
      if (info.identifier == null) {
        var id = '__e-${_uniqueIds.next()}';
        info.identifier = toCamelCase(id);
        // If it's not created in code, we'll query the element by it's id.
        if (!info.createdInCode) node.attributes['id'] = id;
      }
    }
  }

  /**
   * If this [info] is not created in code, ensure that whichever parent element
   * is created in code has been marked appropriately, so we get an identifier.
   */
  static void _ensureParentHasQuery(ElementInfo info) {
    if (info.isRoot || info.createdInCode) return;

    for (var p = info.parent; p != null; p = p.parent) {
      if (p.createdInCode) {
        p.hasQuery = true;
        return;
      }
    }
  }

  /**
   * Whether code generators need to create a field to store a reference to this
   * element. This is typically true whenever we need to access the element
   * (e.g. to add event listeners, update values on data-bound watchers, etc).
   */
  static bool _needsIdentifier(ElementInfo info) {
    if (info.isRoot) return false;

    return info.hasDataBinding || info.hasIfCondition || info.hasIterate
       || info.hasQuery || info.component != null || info.values.length > 0 ||
       info.events.length > 0;
  }

  void _bindExtends(ComponentInfo component) {
    if (component.extendsTag == null) {
      // TODO(jmesserly): is web components spec going to have a default
      // extends?
      messages.error('Missing the "extends" tag of the component. Please '
          'include an attribute like \'extends="div"\'.',
          component.element.sourceSpan, file: _fileInfo.path);
      return;
    }

    component.extendsComponent = _fileInfo.components[component.extendsTag];
    if (component.extendsComponent == null &&
        component.extendsTag.startsWith('x-')) {

      messages.warning(
          'custom element with tag name ${component.extendsTag} not found.',
          component.element.sourceSpan, file: _fileInfo.path);
    }
  }

  void _bindCustomElement(Element node, ElementInfo info) {
    // <x-fancy-button>
    var component = _fileInfo.components[node.tagName];
    if (component == null) {
      // TODO(jmesserly): warn for unknown element tags?

      // <button is="x-fancy-button">
      var isAttr = node.attributes['is'];
      if (isAttr != null) {
        component = _fileInfo.components[isAttr];
        if (component == null) {
          messages.warning('custom element with tag name $isAttr not found.',
              node.sourceSpan, file: _fileInfo.path);
        }
      }
    }

    if (component != null && !component.hasConflict) {
      info.component = component;
      _currentInfo.usedComponents[component] = true;
    }
  }

  TemplateInfo _createTemplateInfo(Element node) {
    if (node.tagName != 'template' &&
        !node.attributes.containsKey('template')) {
      messages.warning('template attribute is required when using if, '
          'instantiate, or iterate attributes.',
          node.sourceSpan, file: _fileInfo.path);
    }

    var instantiate = node.attributes['instantiate'];
    var condition = node.attributes['if'];
    if (instantiate != null) {
      if (instantiate.startsWith('if ')) {
        if (condition != null) {
          messages.warning(
              'another condition was already defined on this element.',
              node.sourceSpan, file: _fileInfo.path);
        } else {
          condition = instantiate.substring(3);
        }
      }
    }
    var iterate = node.attributes['iterate'];

    // Note: we issue warnings instead of errors because the spirit of HTML and
    // Dart is to be forgiving.
    if (condition != null && iterate != null) {
      messages.warning('template cannot have both iteration and conditional '
          'attributes', node.sourceSpan, file: _fileInfo.path);
      return null;
    }

    if (condition != null) {
      var result = new TemplateInfo(node, _parent, ifCondition: condition);
      result.removeAttributes.add('if');
      result.removeAttributes.add('instantiate');
      if (node.tagName == 'template') {
        return node.nodes.length > 0 ? result : null;
      }

      result.removeAttributes.add('template');


      // TODO(jmesserly): if-conditions in attributes require injecting a
      // placeholder node, and a real node which is a clone. We should
      // consider a design where we show/hide the node instead (with care
      // taken not to evaluate hidden bindings). That is more along the lines
      // of AngularJS, and would have a cleaner DOM. See issue #142.
      var contentNode = node.clone();
      // Clear out the original attributes. This is nice to have, but
      // necessary for ID because of issue #141.
      node.attributes.clear();
      contentNode.nodes.addAll(node.nodes);

      // Create a new ElementInfo that is a child of "result" -- the
      // placeholder node. This will become result.contentInfo.
      visitElementInfo(new ElementInfo(contentNode, result));
      return result;
    } else if (iterate != null) {
      var match = new RegExp(r"(.*) in (.*)").firstMatch(iterate);
      if (match != null) {
        if (node.nodes.length == 0) return null;
        var result = new TemplateInfo(node, _parent, loopVariable: match[1],
            loopItems: match[2]);
        result.removeAttributes.add('iterate');
        if (node.tagName != 'template') result.removeAttributes.add('template');
        return result;
      }
      messages.warning('template iterate must be of the form: '
          'iterate="variable in list", where "variable" is your variable name '
          'and "list" is the list of items.',
          node.sourceSpan, file: _fileInfo.path);
    }
    return null;
  }

  void visitAttribute(ElementInfo info, String name, String value) {
    if (name == 'data-value') {
      for (var item in value.split(',')) {
        if (!_readDataValue(info, item)) break;
      }
      info.removeAttributes.add(name);
      return;
    } else if (name == 'data-action') {
      for (var item in value.split(',')) {
        if (!_readDataAction(info, item)) break;
      }
      info.removeAttributes.add(name);
      return;
    } else if (name == 'data-bind') {
      for (var item in value.split(',')) {
        if (!_readDataBind(info, item)) break;
      }
      info.removeAttributes.add(name);
      return;
    } else if (name.startsWith('on')) {
      _readEventHandler(info, name, value);
      return;
    } else if (name.startsWith('bind-')) {
      // Strip leading "bind-" and make camel case.
      var fieldName = toCamelCase(name.substring(5));
      if (_readTwoWayBinding(info, fieldName, value)) {
        info.removeAttributes.add(name);
      }
      return;
    }

    AttributeInfo attrInfo;
    if (name == 'data-style') {
      attrInfo = new AttributeInfo([value], isStyle: true);
      info.removeAttributes.add(name);
    } else if (name == 'class') {
      attrInfo = _readClassAttribute(info, value);
    } else {
      attrInfo = _readAttribute(info, name, value);
    }

    if (attrInfo != null) {
      info.attributes[name] = attrInfo;
      info.hasDataBinding = true;
    }
  }

  bool _readDataValue(ElementInfo info, String value) {
    messages.warning('data-value is deprecated. '
        'Given data-value="fieldName:expr", replace it with '
        'field-name="{{expr}}". Unlike data-value, "expr" will be watched and '
        'fieldName will automatically update. You may also use '
        'bind-field-name="dartAssignableValue" to get two-way data binding.',
        info.node.sourceSpan, file: _fileInfo.path);

    var colonIdx = value.indexOf(':');
    if (colonIdx <= 0) {
      messages.error('data-value attribute should be of the form '
          'data-value="name:value" or data-value='
          '"name1:value1,name2:value2,..." for multiple assigments.',
          info.node.sourceSpan, file: _fileInfo.path);
      return false;
    }
    var name = value.substring(0, colonIdx);
    value = value.substring(colonIdx + 1);

    info.values[name] = value;
    return true;
  }

  // TODO(jmesserly): remove this after a grace period.
  // TODO(jmesserly): would be neat to have an automated refactoring.
  bool _readDataAction(ElementInfo info, String value) {
    messages.warning('data-action is deprecated. '
        'Given a handler like data-action="eventName:handlerName", replace it '
        'with on-event-name="handlerName(\$event)". You may optionally remove '
        'the \$event or pass in more arguments if desired.',
        info.node.sourceSpan, file: _fileInfo.path);

    // Special data-attribute specifying an event listener.
    var colonIdx = value.indexOf(':');
    if (colonIdx <= 0) {
      messages.error('data-action attribute should be of the form '
          'data-action="eventName:action", or data-action='
          '"eventName1:action1,eventName2:action2,..." for multiple events.',
          info.node.sourceSpan, file: _fileInfo.path);
      return false;
    }

    var name = value.substring(0, colonIdx);
    value = value.substring(colonIdx + 1);
    _addEvent(info, name, (elem) => '$value(\$event)');
    return true;
  }

  /**
   * Support for inline event handlers that take expressions.
   * For example: `on-double-click=myHandler($event, todo)`.
   */
  void _readEventHandler(ElementInfo info, String name, String value) {
    if (!name.startsWith('on-')) {
      // TODO(jmesserly): do we need an option to suppress this warning?
      messages.warning('Event handler $name will be interpreted as an inline '
          'JavaScript event handler. Use the form '
          'on-event-name="handlerName(\$event)" if you want a Dart handler '
          'that will automatically update the UI based on model changes.',
          info.node.sourceSpan, file: _fileInfo.path);
      return;
    }

    // Strip leading "on-" and make camel case.
    var eventName = toCamelCase(name.substring(3));
    _addEvent(info, eventName, (elem) => value);
    info.removeAttributes.add(name);
  }

  EventInfo _addEvent(ElementInfo info, String name, ActionDefinition action) {
    var events = info.events.putIfAbsent(name, () => <EventInfo>[]);
    var eventInfo = new EventInfo(name, action);
    events.add(eventInfo);
    return eventInfo;
  }

  bool _readDataBind(ElementInfo info, String value) {
    messages.warning('data-bind is deprecated. '
        'Given a binding like data-bind="attribute:dartAssignableValue" replace'
        ' it with bind-attribute="dartAssignableValue".',
        info.node.sourceSpan, file: _fileInfo.path);

    var colonIdx = value.indexOf(':');
    if (colonIdx <= 0) {
      messages.error('data-bind attribute should be of the form '
          'data-bind="attribute:dartAssignableValue"',
          info.node.sourceSpan, file: _fileInfo.path);
      return false;
    }
    var name = value.substring(0, colonIdx);
    value = value.substring(colonIdx + 1);

    return _readTwoWayBinding(info, name, value);
  }

  // http://dev.w3.org/html5/spec/the-input-element.html#the-input-element
  /** Support for two-way bindings. */
  bool _readTwoWayBinding(ElementInfo info, String name, String bindingExpr) {
    var elem = info.node;

    // Find the HTML tag name.
    var isInput = info.baseTagName == 'input';
    var isTextArea = info.baseTagName == 'textarea';
    var isSelect = info.baseTagName == 'select';
    var inputType = elem.attributes['type'];

    String eventName;

    // Special two-way binding logic for input elements.
    if (isInput && name == 'checked') {
      if (inputType == 'radio') {
        if (!_isValidRadioButton(info)) return false;
      } else if (inputType != 'checkbox') {
        messages.error('checked is only supported in HTML with type="radio" '
            'or type="checked".', info.node.sourceSpan, file: _fileInfo.path);
        return false;
      }

      // Both 'click' and 'change' seem reliable on all the modern browsers.
      eventName = 'change';
    } else if (isSelect && (name == 'selectedIndex' || name == 'value')) {
      eventName = 'change';
    } else if (isInput && name == 'value' && inputType == 'radio') {
      return _addRadioValueBinding(info, bindingExpr);
    } else if (isTextArea && name == 'value' || isInput &&
        (name == 'value' || name == 'valueAsDate' || name == 'valueAsNumber')) {
      // Input event is fired more frequently than "change" on some browsers.
      // We want to update the value for each keystroke.
      eventName = 'input';
    } else if (info.component != null) {
      // Assume we are binding a field on the component.
      // TODO(jmesserly): validate this assumption about the user's code by
      // using compile time mirrors.

      _checkDuplicateAttribute(info, name);
      info.attributes[name] = new AttributeInfo([bindingExpr],
          customTwoWayBinding: true);
      info.hasDataBinding = true;
      return true;

    } else {
      messages.error('Unknown two-way binding attribute $name. Ignored.',
          info.node.sourceSpan, file: _fileInfo.path);
      return false;
    }

    _checkDuplicateAttribute(info, name);

    info.attributes[name] = new AttributeInfo([bindingExpr]);
    _addEvent(info, eventName, (e) => '$bindingExpr = $e.$name');
    info.hasDataBinding = true;
    return true;
  }

  void _checkDuplicateAttribute(ElementInfo info, String name) {
    if (info.node.attributes[name] != null) {
      messages.warning('Duplicate attribute $name. You should provide either '
          'the two-way binding or the attribute itself. The attribute will be '
          'ignored.', info.node.sourceSpan, file: _fileInfo.path);
      info.removeAttributes.add(name);
    }
  }

  bool _isValidRadioButton(ElementInfo info) {
    if (info.attributes['checked'] == null) return true;

    messages.error('Radio buttons cannot have both "checked" and "value" '
        'two-way bindings. Either use checked:\n'
        '  <input type="radio" bind-checked="myBooleanVar">\n'
        'or value:\n'
        '  <input type="radio" bind-value="myStringVar" value="theValue">',
        info.node.sourceSpan, file: _fileInfo.path);
    return false;
  }

  /**
   * Radio buttons use the "value" and "bind-value" fields.
   * The "value" attribute is assigned to the bindingExpr when checked, and
   * the checked field is updated if "value" matches bindingExpr.
   */
  bool _addRadioValueBinding(ElementInfo info, String bindingExpr) {
    if (!_isValidRadioButton(info)) return false;

    // TODO(jmesserly): should we read the element's "value" at runtime?
    var radioValue = info.node.attributes['value'];
    if (radioValue == null) {
      messages.error('Radio button bindings need "bind-value" and "value".'
          'For example: '
          '<input type="radio" bind-value="myStringVar" value="theValue">',
          info.node.sourceSpan, file: _fileInfo.path);
      return false;
    }

    radioValue = escapeDartString(radioValue);
    info.attributes['checked'] = new AttributeInfo(
        ["$bindingExpr == '$radioValue'"]);
    _addEvent(info, 'change', (e) => "$bindingExpr = '$radioValue'");
    info.hasDataBinding = true;
    return true;
  }

  /**
   * Data binding support in attributes. Supports multiple bindings.
   * This is can be used for any attribute, but a typical use case would be
   * URLs, for example:
   *
   *       href="#{item.href}"
   */
  AttributeInfo _readAttribute(ElementInfo info, String name, String value) {
    var parser = new BindingParser(value);
    if (!parser.moveNext()) return null;

    info.removeAttributes.add(name);

    // TODO(jmesserly): this seems like a common pattern.
    var bindings = <String>[];
    var content = <String>[];
    do {
      bindings.add(parser.binding);
      content.add(parser.textContent);
    } while (parser.moveNext());
    content.add(parser.textContent);

    // Use a simple attriubte binding if we can.
    // This kind of binding works for non-String values.
    if (bindings.length == 1 && content[0] == '' && content[1] == '') {
      return new AttributeInfo(bindings);
    }

    // Otherwise do a text attribute that performs string interpolation.
    return new AttributeInfo(bindings, textContent: content);
  }

  /**
   * Special support to bind each css class separately.
   *
   *       class="{{class1}} class2 {{class3}} {{class4}}"
   *
   * Returns list of databound expressions (e.g, class1, class3 and class4).
   */
  AttributeInfo _readClassAttribute(ElementInfo info, String value) {
    var parser = new BindingParser(value);
    if (!parser.moveNext()) return null;

    var bindings = <String>[];
    var content = new StringBuffer();
    do {
      content.add(parser.textContent);
      bindings.add(parser.binding);
    } while (parser.moveNext());
    content.add(parser.textContent);

    // Update class attributes to only have non-databound class names for
    // attributes for the HTML.
    info.node.attributes['class'] = content.toString();

    return new AttributeInfo(bindings, isClass: true);
  }

  void visitText(Text text) {
    var parser = new BindingParser(text.value);
    if (!parser.moveNext()) {
      new TextInfo(text, _parent);
      return;
    }

    _parent.hasDataBinding = true;
    _parent.childrenCreatedInCode = true;

    // We split [text] so that each binding has its own text node.
    var node = text.parent;
    do {
      _addRawTextContent(parser.textContent, text);
      var placeholder = new Text('');
      var id = '__binding${_uniqueIds.next()}';
      new TextInfo(placeholder, _parent, parser.binding, id);
    } while (parser.moveNext());

    _addRawTextContent(parser.textContent, text);
  }

  void _addRawTextContent(String content, Text location) {
    if (content != '') {
      new TextInfo(new Text(content), _parent);
    }
  }
}

/** A visitor that finds `<link rel="components">` and `<element>` tags.  */
class _ElementLoader extends TreeVisitor {
  final FileInfo _fileInfo;
  LibraryInfo _currentInfo;
  bool _inHead = false;

  _ElementLoader(this._fileInfo) {
    _currentInfo = _fileInfo;
  }

  void visitElement(Element node) {
    switch (node.tagName) {
      case 'link': visitLinkElement(node); break;
      case 'element': visitElementElement(node); break;
      case 'script': visitScriptElement(node); break;
      case 'head':
        var savedInHead = _inHead;
        _inHead = true;
        super.visitElement(node);
        _inHead = savedInHead;
        break;
      default: super.visitElement(node); break;
    }
  }

  void visitLinkElement(Element node) {
    if (node.attributes['rel'] != 'components') return;

    if (!_inHead) {
      messages.warning('link rel="components" only valid in '
          'head.', node.sourceSpan, file: _fileInfo.path);
      return;
    }

    var href = node.attributes['href'];
    if (href == null || href == '') {
      messages.warning('link rel="components" missing href.',
          node.sourceSpan, file: _fileInfo.path);
      return;
    }

    var path = _fileInfo.path.directoryPath.join(new Path(href));
    _fileInfo.componentLinks.add(path);
  }

  void visitElementElement(Element node) {
    // TODO(jmesserly): what do we do in this case? It seems like an <element>
    // inside a Shadow DOM should be scoped to that <template> tag, and not
    // visible from the outside.
    if (_currentInfo is ComponentInfo) {
      messages.error('Nested component definitions are not yet supported.',
          node.sourceSpan, file: _fileInfo.path);
      return;
    }

    var tagName = node.attributes['name'];
    var extendsTag = node.attributes['extends'];
    var constructor = node.attributes['constructor'];
    var templateNodes = node.nodes.filter((n) => n.tagName == 'template');

    if (tagName == null) {
      messages.error('Missing tag name of the component. Please include an '
          'attribute like \'name="x-your-tag-name"\'.',
          node.sourceSpan, file: _fileInfo.path);
      return;
    }

    var template = null;
    if (templateNodes.length == 1) {
      template = templateNodes[0];
    } else {
      messages.warning('an <element> should have exactly one <template> child.',
          node.sourceSpan, file: _fileInfo.path);
    }

    if (constructor == null) {
      var name = tagName;
      if (name.startsWith('x-')) name = name.substring(2);
      constructor = toCamelCase(name, startUppercase: true);
    }

    var component = new ComponentInfo(node, _fileInfo, tagName, extendsTag,
        constructor, template);

    _fileInfo.declaredComponents.add(component);

    var lastInfo = _currentInfo;
    _currentInfo = component;
    super.visitElement(node);
    _currentInfo = lastInfo;
  }


  void visitScriptElement(Element node) {
    var scriptType = node.attributes['type'];
    if (scriptType == null) {
      // Note: in html5 leaving off type= is fine, but it defaults to
      // text/javascript. Because this might be a common error, we warn about it
      // and force explicit type="text/javascript".
      // TODO(jmesserly): is this a good warning?
      messages.warning('ignored script tag, possibly missing '
          'type="application/dart" or type="text/javascript":',
          node.sourceSpan, file: _fileInfo.path);
    }

    if (scriptType != 'application/dart') return;

    var src = node.attributes["src"];
    if (src != null) {
      if (!src.endsWith('.dart')) {
        messages.warning('"application/dart" scripts should'
            'use the .dart file extension.',
            node.sourceSpan, file: _fileInfo.path);
      }

      if (node.innerHTML.trim() != '') {
        messages.error('script tag has "src" attribute and also has script '
            ' text.', node.sourceSpan, file: _fileInfo.path);
      }

      if (_currentInfo.codeAttached) {
        _tooManyScriptsError(node);
      } else {
        _currentInfo.externalFile =
            _fileInfo.path.directoryPath.join(new Path(src));
      }
      return;
    }

    if (node.nodes.length == 0) return;

    // I don't think the html5 parser will emit a tree with more than
    // one child of <script>
    assert(node.nodes.length == 1);
    Text text = node.nodes[0];

    if (_currentInfo.codeAttached) {
      _tooManyScriptsError(node);
    } else if (_currentInfo == _fileInfo && !_fileInfo.isEntryPoint) {
      messages.warning('top-level dart code is ignored on '
          ' HTML pages that define components, but are not the entry HTML '
          'file.', node.sourceSpan, file: _fileInfo.path);
    } else {
      _currentInfo.inlinedCode = text.value;
      _currentInfo.userCode = parseDartCode(text.value,
          _currentInfo.inputPath, messages);
      if (_currentInfo.userCode.partOf != null) {
        messages.error('expected a library, not a part.',
            node.sourceSpan, file: _fileInfo.path);
      }
    }
  }

  void _tooManyScriptsError(Node node) {
    var location = _currentInfo is ComponentInfo ?
        'a custom element declaration' : 'the top-level HTML page';

    messages.error('there should be only one dart script tag in $location.',
        node.sourceSpan, file: _fileInfo.path);
  }
}

/**
 * Normalizes references in [info]. On the [analyzeDefinitions] phase, the
 * analyzer extracted names of files and components. Here we link those names to
 * actual info classes. In particular:
 *   * we initialize the [components] map in [info] by importing all
 *     [declaredComponents],
 *   * we scan all [componentLinks] and import their [declaredComponents],
 *     using [files] to map the href to the file info. Names in [info] will
 *     shadow names from imported files.
 *   * we fill [externalCode] on each component declared in [info].
 */
void _normalize(FileInfo info, Map<Path, FileInfo> files) {
  _attachExtenalScript(info, files);

  for (var component in info.declaredComponents) {
    _addComponent(info, component);
    _attachExtenalScript(component, files);
  }

  for (var link in info.componentLinks) {
    var file = files[link];
    // We already issued an error for missing files.
    if (file == null) continue;
    file.declaredComponents.forEach((c) => _addComponent(info, c));
  }
}

/**
 * Stores a direct reference in [info] to a dart source file that was loaded in
 * a script tag with the 'src' attribute.
 */
void _attachExtenalScript(LibraryInfo info, Map<Path, FileInfo> files) {
  var path = info.externalFile;
  if (path != null) {
    info.externalCode = files[path];
    info.userCode = info.externalCode.userCode;
  }
}

/** Adds a component's tag name to the names in scope for [fileInfo]. */
void _addComponent(FileInfo fileInfo, ComponentInfo componentInfo) {
  var existing = fileInfo.components[componentInfo.tagName];
  if (existing != null) {
    if (existing == componentInfo) {
      // This is the same exact component as the existing one.
      return;
    }

    if (existing.declaringFile == fileInfo &&
        componentInfo.declaringFile != fileInfo) {
      // Components declared in [fileInfo] are allowed to shadow component
      // names declared in imported files.
      return;
    }

    if (existing.hasConflict) {
      // No need to report a second error for the same name.
      return;
    }

    existing.hasConflict = true;

    if (componentInfo.declaringFile == fileInfo) {
      messages.error('duplicate custom element definition for '
          '"${componentInfo.tagName}".',
          existing.element.sourceSpan, file: fileInfo.path);
      messages.error('duplicate custom element definition for '
          '"${componentInfo.tagName}" (second location).',
          componentInfo.element.sourceSpan, file: fileInfo.path);
    } else {
      messages.error('imported duplicate custom element definitions '
          'for "${componentInfo.tagName}".',
          existing.element.sourceSpan,
          file: existing.declaringFile.path);
      messages.error('imported duplicate custom element definitions '
          'for "${componentInfo.tagName}" (second location).',
          componentInfo.element.sourceSpan,
          file: componentInfo.declaringFile.path);
    }
  } else {
    fileInfo.components[componentInfo.tagName] = componentInfo;
  }
}


/**
 * Parses double-curly data bindings within a string, such as
 * `foo {{bar}} baz {{quux}}`.
 *
 * Note that a double curly always closes the binding expression, and nesting
 * is not supported. This seems like a reasonable assumption, given that these
 * will be specified for HTML, and they will require a Dart or JavaScript
 * parser to parse the expressions.
 */
class BindingParser {
  final String text;
  int previousEnd;
  int start;
  int end = 0;

  BindingParser(this.text);

  int get length => text.length;

  String get textContent {
    if (start == null) throw new StateError('iteration not started');
    return text.substring(previousEnd, start);
  }

  String get binding {
    if (start == null) throw new StateError('iteration not started');
    if (end < 0) throw new StateError('no more bindings');
    return text.substring(start + 2, end - 2);
  }

  bool moveNext() {
    if (end < 0) return false;

    previousEnd = end;
    start = text.indexOf('{{', end);
    if (start < 0) {
      end = -1;
      start = length;
      return false;
    }

    end = text.indexOf('}}', start);
    if (end < 0) {
      start = length;
      return false;
    }
    // For consistency, start and end both include the curly braces.
    end += 2;
    return true;
  }
}
