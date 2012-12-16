// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * A mini parser that extracts top-level directives (library, imports, exports,
 * and parts) from a dart source file.
 */
library directive_parser;

import 'info.dart' show DartCodeInfo, DartDirectiveInfo;
import 'messages.dart' show Messages;
import 'file_system/path.dart';

/** Parse and extract top-level directives from [code]. */
DartCodeInfo parseDartCode(String code, Path file, Messages messages) {
  return new _DirectiveParser(messages, file).parse(code);
}

/** A parser that extracts top-level directives. */
// TODO(sigmund): add source-span to error messages
class _DirectiveParser {
  /** Path to the source file containing the code (for error messages). */
  Path file;

  /** Tokenizer used to parse the input until the end of the directives. */
  _DirectiveTokenizer tokenizer;

  /** Extracted library identifier, if any. */
  String libraryName;

  /** Extracted part-of identifier, if any. */
  String partName;

  /** Extracted imports, exports, and parts, if any. */
  List<DartDirectiveInfo> directives = <DartDirectiveInfo>[];

  /** Helper for reporting error messages. */
  Messages messages;

  /** Last token read by the parser. */
  Token token;

  _DirectiveParser(this.messages, this.file);

  /** Parse and extract directives from [code]. */
  DartCodeInfo parse(String code) {
    tokenizer = new _DirectiveTokenizer(code);
    parseTopLevel();
    return new DartCodeInfo(libraryName, partName, directives,
        code.substring(token.start));
  }

  /**
   * Parse top-level directives and comments, but unlike normal Dart code, stop
   * as soon as we find actual code.
   */
  void parseTopLevel() {
    token = tokenizer.next();
    while (token.kind != Token.EOF) {
      if (token.kind == Token.IDENTIFIER) {
        if (token.value == 'library') {
          parseLibrary();
        } else if (token.value == 'part') {
          parsePart();
        } else if (token.value == 'import') {
          parseImport();
        } else if (token.value == 'export') {
          parseExport();
        } else {
          break;
        }
      } else if (token.kind != Token.COMMENT) {
        break;
      }
      token = tokenizer.next();
    }
  }

  /** Parse library declarations: 'library foo.bar;' */
  parseLibrary() {
    libraryName = parseQualifiedName();
    expectToken(Token.SEMICOLON);
  }

  /**
   * Parse either a part declaration or part inclusions. For instance,
   *     part of foo.bar;
   * or
   *     part "foo";
   */
  parsePart() {
    token = tokenizer.next();
    if (token.kind == Token.IDENTIFIER && token.value == 'of') {
      partName = parseQualifiedName();
    } else if (token.kind == Token.STRING) {
      directives.add(new DartDirectiveInfo('part', token.value));
      token = tokenizer.next();
    } else {
      messages.error('unexpected token: ${token}', null, file: file);
    }
    expectToken(Token.SEMICOLON);
  }

  /** Parse a qualified name, such as `one.two.three`. */
  parseQualifiedName() {
    List<String> segments = [];
    while (true) {
      token = tokenizer.next();
      if (token.kind != Token.IDENTIFIER) {
        messages.error('invalid qualified name: $token', null, file: file);
        return null;
      }
      segments.add(token.value);
      token = tokenizer.next();
      if (token.kind == Token.SEMICOLON) break;
      if (token.kind != Token.DOT) {
        messages.error('invalid qualified name: $token', null, file: file);
        return null;
      }
    }
    return Strings.join(segments, '.');
  }

  /** Parse an import, with optional prefix and show/hide combinators. */
  parseImport() {
    token = tokenizer.next();
    if (token.kind != Token.STRING) {
      // TODO(sigmund): add file name and span information here.
      messages.error('expected an import url, but found ${token}', null,
          file: file);
      return;
    }
    var uri = token.value;
    token = tokenizer.next();
    while (token.kind == Token.STRING) {
      uri = '$uri${token.value}';
      token = tokenizer.next();
    }

    // Parse the optional prefix.
    var prefix;
    if (token.kind == Token.IDENTIFIER && token.value == 'as') {
      token = tokenizer.next();
      if (token.kind != Token.IDENTIFIER) {
        messages.error('expected an identifier as prefix, but found ${token}',
            null, file: file);
        return;
      }
      prefix = token.value;
      token = tokenizer.next();
    }

    // Parse the optional show/hide combinators.
    var hide;
    var show;
    while (token.kind == Token.IDENTIFIER) {
      if (token.value == 'hide') {
        if (hide == null) hide = [];
        hide.addAll(parseIdentifierList());
      } else if (token.value == 'show') {
        if (show == null) show = [];
        show.addAll(parseIdentifierList());
      } else {
        break;
      }
    }

    expectToken(Token.SEMICOLON);
    directives.add(new DartDirectiveInfo('import', uri, prefix, hide, show));
  }

  /** Parse an export, with optional show/hide combinators. */
  parseExport() {
    token = tokenizer.next();
    if (token.kind != Token.STRING) {
      messages.error('expected an export url, but found ${token}', null,
          file: file);
      return;
    }
    var uri = token.value;

    // Parse the optional show/hide combinators.
    token = tokenizer.next();
    var hide;
    var show;
    while (token.kind == Token.IDENTIFIER) {
      if (token.value == 'hide') {
        if (hide == null) hide = [];
        hide.addAll(parseIdentifierList());
      } else if (token.value == 'show') {
        if (show == null) show = [];
        show.addAll(parseIdentifierList());
      }
    }

    expectToken(Token.SEMICOLON);
    directives.add(new DartDirectiveInfo('export', uri, null, hide, show));
  }

  /** Parse a list of identifiers of the form `id1, id2, id3` */
  List<String> parseIdentifierList() {
    var list = [];
    do {
      token = tokenizer.next();
      if (!expectToken(Token.IDENTIFIER)) return list;
      list.add(token.value);
      token = tokenizer.next();
    } while (token.kind == Token.COMMA);
    return list;
  }

  /** Report an error if the last token is not of the expected kind. */
  bool expectToken(int kind) {
    if (token.kind != kind) {
      messages.error(
          'expected <${Token.KIND_NAMES[kind]}>, but got ${token}', null,
          file: file);
      return false;
    }
    return true;
  }
}

/** Set of tokens that we parse out of the dart code. */
class Token {
  /** Kind of token, one of the constants below. */
  final int kind;

  /** Value in the token (filled only for identifiers and strings). */
  final String value;

  /** Start location for the token in the input string. */
  final int start;

  /** End location for the token in the input string. */
  final int end;

  const Token(this.kind, this.start, this.end, [this.value]);

  toString() => '<#Token ${KIND_NAMES[kind]}, $value>';

  static const int COMMENT = 0;
  static const int STRING = 1;
  static const int IDENTIFIER = 2;
  static const int SEMICOLON = 3;
  static const int DOT = 4;
  static const int COMMA = 5;
  static const int EOF = 6;
  static const List<String> KIND_NAMES =
      const ['comment', 'string', 'id', 'semicolon', 'dot', 'comma', 'eof'];

}

/**
 * A simple tokenizer that understands comments, identifiers, strings,
 * separators, and practically nothing else.
 */
class _DirectiveTokenizer {
  int pos = 0;
  String _data;

  _DirectiveTokenizer(this._data);

  /** Return the next token. */
  Token next() {
    while (true) {
      if (pos >= _data.length) return new Token(Token.EOF, pos, pos);
      if (!isWhiteSpace(peek())) break;
      nextChar();
    }

    var c = peek();
    switch (c) {
      case _SLASH:
        if (peek(1) == _SLASH) return lineComment();
        if (peek(1) == _STAR) return blockComment();
        break;
      case _SINGLE_QUOTE:
      case _DOUBLE_QUOTE:
        return string();
      case _SEMICOLON:
        pos++;
        return new Token(Token.SEMICOLON, pos - 1, pos);
      case _DOT:
        pos++;
        return new Token(Token.DOT, pos - 1, pos);
      case _COMMA:
        pos++;
        return new Token(Token.COMMA, pos - 1, pos);
      default:
        if (isIdentifierStart(c)) return identifier();
        break;
    }
    return new Token(Token.EOF, pos, pos);
  }

  int nextChar() => _data.charCodeAt(pos++);
  int peek([int skip = 0]) => _data.charCodeAt(pos + skip);

  /** Advance parsing until the end of a string (no tripple quotes allowed). */
  Token string() {
    // TODO(sigmund): add support for multi-line strings, and raw strings.
    int start = pos;
    int startQuote = nextChar();
    bool escape = false;
    while (true) {
      if (pos >= _data.length) return new Token(Token.EOF, start, pos);
      int c = nextChar();
      if (c == startQuote && !escape) break;
      escape = !escape && c == _BACKSLASH;
    }
    return new Token(Token.STRING, start, pos,
        _data.substring(start + 1, pos - 1));
  }

  /** Advance parsing until the end of an identifier. */
  Token identifier() {
    int start = pos;
    while (pos < _data.length && isIdentifierChar(peek())) pos++;
    return new Token(Token.IDENTIFIER, start, pos, _data.substring(start, pos));
  }

  /** Advance parsing until the end of a line comment. */
  Token lineComment() {
    int start = pos;
    while (pos < _data.length && peek() != _LF) pos++;
    return new Token(Token.COMMENT, start, pos);
  }

  /** Advance parsing until the end of a block comment (nesting is allowed). */
  Token blockComment() {
    var start = pos;
    var commentNesting = 0;
    pos += 2;
    while (pos < _data.length) {
      if (peek() == _STAR && peek(1) == _SLASH) {
        pos += 2;
        if (commentNesting == 0) break;
        commentNesting--;
      } else if (peek() == _SLASH && peek(1) == _STAR) {
        pos += 2;
        commentNesting++;
      } else {
        pos++;
      }
    }
    return new Token(Token.COMMENT, start, pos);
  }

  bool isWhiteSpace(int c) => c == _LF || c == _SPACE || c == _CR || c == _TAB;
  bool isIdentifierStart(int c) => c == _UNDERSCORE || isLetter(c);
  bool isIdentifierChar(int c) => isIdentifierStart(c) || isNumber(c);
  bool isNumber(int c) => c >= _ZERO && c <= _NINE;
  bool isLetter(int c) =>
      (c >= _LOWER_A && c <= _LOWER_Z) ||
      (c >= _UPPER_A && c <= _UPPER_Z);


  // The following constant character values are used for tokenizing.

  static const int _TAB = 9;
  static const int _LF = 10;
  static const int _CR = 13;
  static const int _SPACE = 32;
  static const int _DOUBLE_QUOTE = 34; // "
  static const int _DOLLAR = 36;       // $
  static const int _SINGLE_QUOTE = 39; // '
  static const int _STAR = 42;         // *
  static const int _COMMA = 44;        // ,
  static const int _DOT = 46;          // .
  static const int _SLASH = 47;        // /
  static const int _ZERO = 48;         // 0
  static const int _NINE = 57;         // 9
  static const int _SEMICOLON = 59;    // ;
  static const int _UPPER_A = 65;      // A
  static const int _UPPER_Z = 90;      // Z
  static const int _BACKSLASH = 92;    // \
  static const int _UNDERSCORE = 95;   // _
  static const int _LOWER_A = 97;      // a
  static const int _LOWER_Z = 122;     // z
}
