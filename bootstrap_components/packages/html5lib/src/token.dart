/** This library contains token types used by the html5 tokenizer. */
library token;

import 'package:html5lib/dom_parsing.dart' show SourceSpan;

/** An html5 token. */
abstract class Token {
  SourceSpan span;

  int get kind;

  // TODO(jmesserly): it'd be nice to remove this and always use the ".data"
  // on the particular token type, since they store different kinds of data.
  get data;
  set data(value);
}

abstract class TagToken extends Token {
  String name;

  // TODO(jmesserly): this starts as a List, but becomes a Map of attributes.
  // Should probably separate these into different named fields.
  var data;

  bool selfClosing;

  TagToken(this.name, data, this.selfClosing)
      : data = data == null ? [] : data;
}

class StartTagToken extends TagToken {
  bool selfClosingAcknowledged;

  /** The namespace. This is filled in later during tree building. */
  String namespace;

  StartTagToken(String name, {data, bool selfClosing: false,
      this.selfClosingAcknowledged: false, this.namespace})
      : super(name, data, selfClosing);

  int get kind => TokenKind.startTag;
}

class EndTagToken extends TagToken {
  EndTagToken(String name, {data, bool selfClosing: false})
      : super(name, data, selfClosing);

  int get kind => TokenKind.endTag;
}

abstract class StringToken extends Token {
  String data;
  StringToken(this.data);
}

class ParseErrorToken extends StringToken {
  /** Extra information that goes along with the error message. */
  Map messageParams;

  ParseErrorToken(String data, {this.messageParams}) : super(data);

  int get kind => TokenKind.parseError;
}

class CharactersToken extends StringToken {
  CharactersToken([String data]) : super(data);

  int get kind => TokenKind.characters;
}

class SpaceCharactersToken extends StringToken {
  SpaceCharactersToken([String data]) : super(data);

  int get kind => TokenKind.spaceCharacters;
}

class CommentToken extends StringToken {
  CommentToken([String data]) : super(data);

  int get kind => TokenKind.comment;
}

class DoctypeToken extends Token {
  String publicId;
  String systemId;
  String name = "";
  bool correct;

  DoctypeToken({this.publicId, this.systemId, this.correct: false});

  int get kind => TokenKind.doctype;

  // TODO(jmesserly): remove. These are only here because of Token.data
  String get data { throw new UnsupportedError("data"); }
  set data(value) { throw new UnsupportedError("data"); }
}


class TokenKind {
  static const int spaceCharacters = 0;
  static const int characters = 1;
  static const int startTag = 2;
  static const int endTag = 3;
  static const int comment = 4;
  static const int doctype = 5;
  static const int parseError = 6;
}
