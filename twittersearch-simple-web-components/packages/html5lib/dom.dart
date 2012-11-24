/**
 * A simple tree API that results from parsing html. Intended to be compatible
 * with dart:html, but right now it resembles the classic JS DOM.
 */
library dom;

import 'src/constants.dart';
import 'src/list_proxy.dart';
import 'src/treebuilder.dart';
import 'src/utils.dart';
import 'dom_parsing.dart';

// For doc comment only:
import 'parser.dart' show HtmlParser;

// TODO(jmesserly): I added this class to replace the tuple usage in Python.
// How does this fit in to dart:html?
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

  /**
   * The source span of this node, if it was created by the [HtmlParser].
   */
  SourceSpan span;

  Node(this.tagName) {
    nodes._parent = this;
  }

  /**
   * Return a shallow copy of the current node i.e. a node with the same
   * name and attributes but with no parent or child nodes.
   */
  Node clone();

  String get id {
    var result = attributes['id'];
    return result != null ? result : '';
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
   * is not a child of the current node.
   */
  void insertBefore(Node node, Node refNode) {
    nodes.insertAt(nodes.indexOf(refNode), node);
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
   * See <ttp://www.w3.org/TR/CSS2/grammar.html>.
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

  int get nodeType => Node.DOCUMENT_NODE;

  // TODO(jmesserly): optmize this if needed
  Element get head => query('html').query('head');
  Element get body => query('html').query('body');

  String toString() => "#document";

  StringBuffer _addOuterHtml(StringBuffer str) => _addInnerHtml(str);

  Document clone() => new Document();
}

class DocumentFragment extends Document {
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

  Element(String name, [this.namespace]) : super(name);

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
