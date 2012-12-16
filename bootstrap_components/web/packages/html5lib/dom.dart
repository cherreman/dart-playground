/**
 * A simple tree API that results from parsing html. Intended to be compatible
 * with dart:html, but right now it resembles the classic JS DOM.
 */
library dom;

import 'package:meta/meta.dart';
import 'src/constants.dart';
import 'src/list_proxy.dart';
import 'src/treebuilder.dart';
import 'src/utils.dart';
import 'dom_parsing.dart';
import 'parser.dart';

// TODO(jmesserly): this needs to be replaced by an AttributeMap for attributes
// that exposes namespace info.
class AttributeName implements Comparable {
  /** The namespace prefix, e.g. `xlink`. */
  final String prefix;

  /** The attribute name, e.g. `title`. */
  final String name;

  /** The namespace url, e.g. `http://www.w3.org/1999/xlink` */
  final String namespace;

  const AttributeName(this.prefix, this.name, this.namespace);

  String toString() {
    // Implement:
    // http://www.whatwg.org/specs/web-apps/current-work/multipage/the-end.html#serializing-html-fragments
    // If we get here we know we are xml, xmlns, or xlink, because of
    // [HtmlParser.adjustForeignAttriubtes] is the only place we create
    // an AttributeName.
    return prefix != null ? '$prefix:$name' : name;
  }

  int get hashCode {
    int h = prefix.hashCode;
    h = 37 * (h & 0x1FFFFF) + name.hashCode;
    h = 37 * (h & 0x1FFFFF) + namespace.hashCode;
    return h & 0x3FFFFFFF;
  }

  int compareTo(other) {
    // Not sure about this sort order
    if (other is! AttributeName) return 1;
    int cmp = (prefix != null ? prefix : "").compareTo(
          (other.prefix != null ? other.prefix : ""));
    if (cmp != 0) return cmp;
    cmp = name.compareTo(other.name);
    if (cmp != 0) return cmp;
    return namespace.compareTo(other.namespace);
  }

  bool operator ==(x) {
    if (x is! AttributeName) return false;
    return prefix == x.prefix && name == x.name && namespace == x.namespace;
  }
}

/** Really basic implementation of a DOM-core like Node. */
abstract class Node {
  static const int ATTRIBUTE_NODE = 2;
  static const int CDATA_SECTION_NODE = 4;
  static const int COMMENT_NODE = 8;
  static const int DOCUMENT_FRAGMENT_NODE = 11;
  static const int DOCUMENT_NODE = 9;
  static const int DOCUMENT_TYPE_NODE = 10;
  static const int ELEMENT_NODE = 1;
  static const int ENTITY_NODE = 6;
  static const int ENTITY_REFERENCE_NODE = 5;
  static const int NOTATION_NODE = 12;
  static const int PROCESSING_INSTRUCTION_NODE = 7;
  static const int TEXT_NODE = 3;

  // TODO(jmesserly): this should be on Element
  /** The tag name associated with the node. */
  final String tagName;

  /** The parent of the current node (or null for the document node). */
  Node parent;

  // TODO(jmesserly): should move to Element.
  /**
   * A map holding name, value pairs for attributes of the node.
   *
   * Note that attribute order needs to be stable for serialization, so we use a
   * LinkedHashMap. Each key is a [String] or [AttributeName].
   */
  LinkedHashMap<dynamic, String> attributes = new LinkedHashMap();

  /**
   * A list of child nodes of the current node. This must
   * include all elements but not necessarily other node types.
   */
  final NodeList nodes = new NodeList._();

  List<Element> _elements;

  // TODO(jmesserly): consider using an Expando for this, and put it in
  // dom_parsing. Need to check the performance affect.
  /** The source span of this node, if it was created by the [HtmlParser]. */
  SourceSpan sourceSpan;

  Node(this.tagName) {
    nodes._parent = this;
  }

  List<Element> get elements {
    if (_elements == null) {
      _elements = new FilteredElementList(this);
    }
    return _elements;
  }

  // TODO(jmesserly): needs to support deep clone.
  /**
   * Return a shallow copy of the current node i.e. a node with the same
   * name and attributes but with no parent or child nodes.
   */
  Node clone();

  String get id {
    var result = attributes['id'];
    return result != null ? result : '';
  }

  set id(String value) {
    if (value == null) {
      attributes.remove('id');
    } else {
      attributes['id'] = value;
    }
  }

  String get namespace => null;

  // TODO(jmesserly): do we need this here?
  /** The value of the current node (applies to text nodes and comments). */
  String get value => null;

  // TODO(jmesserly): this is a workaround for http://dartbug.com/4754
  int get $dom_nodeType => nodeType;

  int get nodeType;

  String get outerHTML => _addOuterHtml(new StringBuffer()).toString();

  String get innerHTML => _addInnerHtml(new StringBuffer()).toString();

  set innerHTML(String value) {
    nodes.clear();
    // TODO(jmesserly): should be able to get the same effect by adding the
    // fragment directly.
    nodes.addAll(parseFragment(value, container: tagName).nodes);
  }

  StringBuffer _addOuterHtml(StringBuffer str);

  StringBuffer _addInnerHtml(StringBuffer str) {
    for (Node child in nodes) child._addOuterHtml(str);
    return str;
  }

  String toString() => tagName;

  Node remove() {
    // TODO(jmesserly): is parent == null an error?
    if (parent != null) {
      parent.nodes.remove(this);
    }
    return this;
  }

  /**
   * Insert [node] as a child of the current node, before [refNode] in the
   * list of child nodes. Raises [UnsupportedOperationException] if [refNode]
   * is not a child of the current node. If refNode is null, this adds to the
   * end of the list.
   */
  void insertBefore(Node node, Node refNode) {
    if (refNode == null) {
      nodes.add(node);
    } else {
      nodes.insertAt(nodes.indexOf(refNode), node);
    }
  }

  /** Replaces this node with another node. */
  Node replaceWith(Node otherNode) {
    if (parent == null) {
      throw new UnsupportedError('Node must have a parent to replace it.');
    }
    parent.nodes[parent.nodes.indexOf(this)] = otherNode;
    return this;
  }

  // TODO(jmesserly): should this be a property or remove?
  /** Return true if the node has children or text. */
  bool hasContent() => nodes.length > 0;

  Pair<String, String> get nameTuple {
    var ns = namespace != null ? namespace : Namespaces.html;
    return new Pair(ns, tagName);
  }

  /**
   * Move all the children of the current node to [newParent].
   * This is needed so that trees that don't store text as nodes move the
   * text in the correct way.
   */
  void reparentChildren(Node newParent) {
    newParent.nodes.addAll(nodes);
    nodes.clear();
  }

  /**
   * Seaches for the first descendant node matching the given selectors, using a
   * preorder traversal. NOTE: right now, this supports only a single type
   * selectors, e.g. `node.query('div')`.
   */
  Element query(String selectors) => _queryType(_typeSelector(selectors));

  /**
   * Retursn all descendant nodes matching the given selectors, using a
   * preorder traversal. NOTE: right now, this supports only a single type
   * selectors, e.g. `node.queryAll('div')`.
   */
  List<Element> queryAll(String selectors) {
    var results = new List<Element>();
    _queryAllType(_typeSelector(selectors), results);
    return results;
  }

  String _typeSelector(String selectors) {
    selectors = selectors.trim();
    if (!_isTypeSelector(selectors)) {
      throw new UnimplementedError('only type selectors are implemented');
    }
    return selectors;
  }

  /**
   * Checks if this is a type selector.
   * See <http://www.w3.org/TR/CSS2/grammar.html>.
   * Note: this doesn't support '*', the universal selector, non-ascii chars or
   * escape chars.
   */
  bool _isTypeSelector(String selector) {
    // Parser:

    // element_name
    //   : IDENT | '*'
    //   ;

    // Lexer:

    // nmstart   [_a-z]|{nonascii}|{escape}
    // nmchar    [_a-z0-9-]|{nonascii}|{escape}
    // ident   -?{nmstart}{nmchar}*
    // nonascii  [\240-\377]
    // unicode   \\{h}{1,6}(\r\n|[ \t\r\n\f])?
    // escape    {unicode}|\\[^\r\n\f0-9a-f]

    // As mentioned above, no nonascii or escape support yet.
    int len = selector.length;
    if (len == 0) return false;

    int i = 0;
    const int DASH = 45;
    if (selector.charCodeAt(i) == DASH) i++;

    if (i >= len || !isLetter(selector[i])) return false;
    i++;

    for (; i < len; i++) {
      if (!isLetterOrDigit(selector[i]) && selector.charCodeAt(i) != DASH) {
        return false;
      }
    }

    return true;
  }

  Element _queryType(String tag) {
    for (var node in nodes) {
      if (node is! Element) continue;
      if (node.tagName == tag) return node;
      var result = node._queryType(tag);
      if (result != null) return result;
    }
    return null;
  }

  void _queryAllType(String tag, List<Element> results) {
    for (var node in nodes) {
      if (node is! Element) continue;
      if (node.tagName == tag) results.add(node);
      node._queryAllType(tag, results);
    }
  }
}

class Document extends Node {
  Document() : super(null);
  factory Document.html(String html) => parse(html);

  int get nodeType => Node.DOCUMENT_NODE;

  // TODO(jmesserly): optmize this if needed
  Element get head => query('html').query('head');
  Element get body => query('html').query('body');

  String toString() => "#document";

  StringBuffer _addOuterHtml(StringBuffer str) => _addInnerHtml(str);

  Document clone() => new Document();
}

class DocumentFragment extends Document {
  DocumentFragment();
  factory DocumentFragment.html(String html) => parseFragment(html);

  int get nodeType => Node.DOCUMENT_FRAGMENT_NODE;

  String toString() => "#document-fragment";

  DocumentFragment clone() => new DocumentFragment();
}

class DocumentType extends Node {
  final String publicId;
  final String systemId;

  DocumentType(String name, this.publicId, this.systemId) : super(name);

  int get nodeType => Node.DOCUMENT_TYPE_NODE;

  String toString() {
    if (publicId != null || systemId != null) {
      // TODO(jmesserly): the html5 serialization spec does not add these. But
      // it seems useful, and the parser can handle it, so for now keeping it.
      var pid = publicId != null ? publicId : '';
      var sid = systemId != null ? systemId : '';
      return '<!DOCTYPE $tagName "$pid" "$sid">';
    } else {
      return '<!DOCTYPE $tagName>';
    }
  }


  StringBuffer _addOuterHtml(StringBuffer str) => str.add(toString());

  DocumentType clone() => new DocumentType(tagName, publicId, systemId);
}

class Text extends Node {
  // TODO(jmesserly): this should be text?
  String value;

  Text(this.value) : super(null);

  int get nodeType => Node.TEXT_NODE;

  String toString() => '"$value"';

  StringBuffer _addOuterHtml(StringBuffer str) {
    // Don't escape text for certain elements, notably <script>.
    if (rcdataElements.contains(parent.tagName) ||
        parent.tagName == 'plaintext') {
      str.add(value);
    } else {
      str.add(htmlSerializeEscape(value));
    }
  }

  Text clone() => new Text(value);
}

class Element extends Node {
  final String namespace;

  // TODO(jmesserly): deprecate in favor of Element.tag? Or rename?
  Element(String name, [this.namespace]) : super(name);

  Element.tag(String name) : namespace = null, super(name);

  static final _START_TAG_REGEXP = new RegExp('<(\\w+)');

  static final _CUSTOM_PARENT_TAG_MAP = const {
    'body': 'html',
    'head': 'html',
    'caption': 'table',
    'td': 'tr',
    'colgroup': 'table',
    'col': 'colgroup',
    'tr': 'tbody',
    'tbody': 'table',
    'tfoot': 'table',
    'thead': 'table',
    'track': 'audio',
  };

  // TODO(jmesserly): this is from dart:html _ElementFactoryProvider...
  // TODO(jmesserly): have a look at fixing some things in dart:html, in
  // particular: is the parent tag map complete? Is it faster without regexp?
  // TODO(jmesserly): for our version we can do something smarter in the parser.
  // All we really need is to set the correct parse state.
  factory Element.html(String html) {

    // TODO(jacobr): this method can be made more robust and performant.
    // 1) Cache the dummy parent elements required to use innerHTML rather than
    //    creating them every call.
    // 2) Verify that the html does not contain leading or trailing text nodes.
    // 3) Verify that the html does not contain both <head> and <body> tags.
    // 4) Detatch the created element from its dummy parent.
    String parentTag = 'div';
    String tag;
    final match = _START_TAG_REGEXP.firstMatch(html);
    if (match != null) {
      tag = match.group(1).toLowerCase();
      if (_CUSTOM_PARENT_TAG_MAP.containsKey(tag)) {
        parentTag = _CUSTOM_PARENT_TAG_MAP[tag];
      }
    }

    var fragment = parseFragment(html, container: parentTag);
    Element element;
    if (fragment.elements.length == 1) {
      element = fragment.elements[0];
    } else if (parentTag == 'html' && fragment.elements.length == 2) {
      // You'll always get a head and a body when starting from html.
      element = fragment.elements[tag == 'head' ? 0 : 1];
    } else {
      throw new ArgumentError('HTML had ${fragment.elements.length} '
          'top level elements but 1 expected');
    }
    element.remove();
    return element;
  }

  int get nodeType => Node.ELEMENT_NODE;

  String toString() {
    if (namespace == null) return "<$tagName>";
    return "<${Namespaces.getPrefix(namespace)} $tagName>";
  }

  StringBuffer _addOuterHtml(StringBuffer str) {
    // http://www.whatwg.org/specs/web-apps/current-work/multipage/the-end.html#serializing-html-fragments
    // Element is the most complicated one.
    if (namespace == null ||
        namespace == Namespaces.html ||
        namespace == Namespaces.mathml ||
        namespace == Namespaces.svg) {
      str.add('<$tagName');
    } else {
      // TODO(jmesserly): the spec doesn't define "qualified name".
      // I'm not sure if this is correct, but it should parse reasonably.
      str.add('<${Namespaces.getPrefix(namespace)}:$tagName');
    }

    if (attributes.length > 0) {
      attributes.forEach((key, v) {
        // Note: AttributeName.toString handles serialization of attribute
        // namespace, if needed.
        str.add(' $key="${htmlSerializeEscape(v, attributeMode: true)}"');
      });
    }

    str.add('>');

    if (nodes.length > 0) {
      if (tagName == 'pre' || tagName == 'textarea' || tagName == 'listing') {
        if (nodes[0] is Text && nodes[0].value.startsWith('\n')) {
          // These nodes will remove a leading \n at parse time, so if we still
          // have one, it means we started with two. Add it back.
          str.add('\n');
        }
      }

      _addInnerHtml(str);
    }

    // void elements must not have an end tag
    // http://dev.w3.org/html5/markup/syntax.html#void-elements
    if (!isVoidElement(tagName)) str.add('</$tagName>');
    return str;
  }

  Element clone() => new Element(tagName, namespace)
      ..attributes = new LinkedHashMap.from(attributes);
}

class Comment extends Node {
  final String data;

  Comment(this.data) : super(null);

  int get nodeType => Node.COMMENT_NODE;

  String toString() => "<!-- $data -->";

  StringBuffer _addOuterHtml(StringBuffer str) => str.add("<!--$data-->");

  Comment clone() => new Comment(data);
}

// TODO(jmesserly): is there any way to share code with the _NodeListImpl?
class NodeList extends ListProxy<Node> {
  // Note: this is conceptually final, but because of circular reference
  // between Node and NodeList we initialize it after construction.
  Node _parent;

  NodeList._();

  Node get first => this[0];

  Node _setParent(Node node) {
    // Note: we need to remove the node from its previous parent node, if any,
    // before updating its parent pointer to point at our parent.
    node.remove();
    node.parent = _parent;
    return node;
  }

  void add(Node value) {
    super.add(_setParent(value));
  }

  void addLast(Node value) => add(value);

  void addAll(Collection<Node> collection) {
    // Note: we need to be careful if collection is another NodeList.
    // In particular:
    //   1. we need to copy the items before updating their parent pointers,
    //   2. we should update parent pointers in reverse order. That way they
    //      are removed from the original NodeList (if any) from the end, which
    //      is faster.
    if (collection is NodeList) {
      collection = new List<Node>.from(collection);
    }
    for (var node in reversed(collection)) _setParent(node);
    super.addAll(collection);
  }

  Node removeLast() => super.removeLast()..parent = null;

  Node removeAt(int i) => super.removeAt(i)..parent = null;

  void clear() {
    for (var node in this) node.parent = null;
    super.clear();
  }

  void operator []=(int index, Node value) {
    this[index].parent = null;
    super[index] = _setParent(value);
  }

  // TODO(jmesserly): These aren't implemented in DOM _NodeListImpl, see
  // http://code.google.com/p/dart/issues/detail?id=5371
  void setRange(int start, int rangeLength, List<Node> from,
                [int startFrom = 0]) {
    if (from is NodeList) {
      // Note: this is presumed to make a copy
      from = from.getRange(startFrom, rangeLength);
    }
    // Note: see comment in [addAll]. We need to be careful about the order of
    // operations if [from] is also a NodeList.
    for (int i = rangeLength - 1; i >= 0; i--) {
      this[start + i].parent = null;
      super[start + i] = _setParent(from[startFrom + i]);
    }
  }

  void removeRange(int start, int rangeLength) {
    for (int i = start; i < rangeLength; i++) this[i].parent = null;
    super.removeRange(start, rangeLength);
  }

  void insertRange(int start, int rangeLength, [Node initialValue]) {
    if (initialValue == null) {
      throw new ArgumentError('cannot add null node.');
    }
    if (rangeLength > 1) {
      throw new UnsupportedError('cannot add the same node multiple times.');
    }
    super.insertRange(start, 1, _setParent(initialValue));
  }
}


// TODO(jmesserly): this was copied from dart:html
// I fixed this to extend Collection and implement removeAt and first.
class FilteredElementList extends Collection<Element> implements List<Element> {
  final Node _node;
  final List<Node> _childNodes;

  FilteredElementList(Node node): _childNodes = node.nodes, _node = node;

  // We can't memoize this, since it's possible that children will be messed
  // with externally to this class.
  List<Element> get _filtered => _childNodes.filter((n) => n is Element);

  void forEach(void f(Element element)) => _filtered.forEach(f);

  void operator []=(int index, Element value) {
    this[index].replaceWith(value);
  }

  void set length(int newLength) {
    final len = this.length;
    if (newLength >= len) {
      return;
    } else if (newLength < 0) {
      throw new ArgumentError("Invalid list length");
    }

    removeRange(newLength - 1, len - newLength);
  }

  void add(Element value) {
    _childNodes.add(value);
  }

  void addAll(Collection<Element> collection) {
    collection.forEach(add);
  }

  void addLast(Element value) {
    add(value);
  }

  bool contains(Element element) {
    return element is Element && _childNodes.contains(element);
  }

  void sort([Comparator compare = Comparable.compare]) {
    // TODO(jacobr): should we impl?
    throw new UnimplementedError();
  }

  void setRange(int start, int rangeLength, List from, [int startFrom = 0]) {
    throw new UnimplementedError();
  }

  void removeRange(int start, int rangeLength) {
    _filtered.getRange(start, rangeLength).forEach((el) => el.remove());
  }

  void insertRange(int start, int rangeLength, [initialValue = null]) {
    throw new UnimplementedError();
  }

  void clear() {
    // Currently, ElementList#clear clears even non-element nodes, so we follow
    // that behavior.
    _childNodes.clear();
  }

  Element removeLast() {
    final result = this.last;
    if (result != null) {
      result.remove();
    }
    return result;
  }

  Element removeAt(int index) => this[index]..remove();

  Collection map(f(Element element)) => _filtered.map(f);
  Collection<Element> filter(bool f(Element element)) => _filtered.filter(f);
  //bool some(bool f(Element element)) => _filtered.some(f);
  int get length => _filtered.length;
  Element operator [](int index) => _filtered[index];
  Iterator<Element> iterator() => _filtered.iterator();
  List<Element> getRange(int start, int rangeLength) =>
    _filtered.getRange(start, rangeLength);
  int indexOf(Element element, [int start = 0]) =>
    _filtered.indexOf(element, start);

  int lastIndexOf(Element element, [int start]) {
    if (start == null) start = length - 1;
    return _filtered.lastIndexOf(element, start);
  }

  Element get last => _filtered.last;

  Element get first => _filtered.first;
}

