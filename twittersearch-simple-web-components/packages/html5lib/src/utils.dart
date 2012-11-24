/** Misc things that were useful when porting the code from Python. */
library utils;

import 'package:unittest/unittest.dart';
import 'constants.dart';

typedef bool Predicate();

class Pair<F, S> {
  final F first;
  final S second;

  const Pair(this.first, this.second);

  int get hashCode => 37 * first.hashCode + second.hashCode;
  bool operator ==(other) => other.first == first && other.second == second;
}

int parseIntRadix(String str, [int radix = 10]) {
  int val = 0;
  for (int i = 0; i < str.length; i++) {
    var digit = str.charCodeAt(i);
    if (digit >= LOWER_A) {
      digit += 10 - LOWER_A;
    } else if (digit >= UPPER_A) {
      digit += 10 - UPPER_A;
    } else {
      digit -= ZERO;
    }
    val = val * radix + digit;
  }
  return val;
}

bool any(List<bool> iterable) => iterable.some((f) => f);

bool startsWithAny(String str, List<String> prefixes) {
  for (var prefix in prefixes) {
    if (str.startsWith(prefix)) {
      return true;
    }
  }
  return false;
}

String joinStr(List<String> strings) => Strings.join(strings, '');

// Like the python [:] operator.
List slice(List list, int start, [int end]) {
  if (end == null) end = list.length;
  if (end < 0) end += list.length;

  // Ensure the indexes are in bounds.
  if (end < start) end = start;
  if (end > list.length) end = list.length;
  return list.getRange(start, end - start);
}

/** Makes a dictionary, where the first key wins. */
LinkedHashMap makeDict(List<List> items) {
  var result = new LinkedHashMap();
  for (var item in items) {
    expect(item.length, equals(2));
    result.putIfAbsent(item[0], () => item[1]);
  }
  return result;
}

bool allWhitespace(String str) {
  for (int i = 0; i < str.length; i++) {
    if (!isWhitespaceCC(str.charCodeAt(i))) return false;
  }
  return true;
}

String padWithZeros(String str, int size) {
  if (str.length == size) return str;
  var result = new StringBuffer();
  size -= str.length;
  for (int i = 0; i < size; i++) result.add('0');
  result.add(str);
  return result.toString();
}

// TODO(jmesserly): this implementation is pretty wrong, but I need something
// quick until dartbug.com/1694 is fixed.
/**
 * Format a string like Python's % string format operator. Right now this only
 * supports a [data] dictionary used with %s or %08x. Those were the only things
 * needed for [errorMessages].
 */
String formatStr(String format, Map data) {
  if (data == null) return format;
  data.forEach((key, value) {
    var result = new StringBuffer();
    var search = '%($key)';
    int last = 0, match;
    while ((match = format.indexOf(search, last)) >= 0) {
      result.add(format.substring(last, match));
      match += search.length;

      int digits = match;
      while (isDigit(format[digits])) {
        digits++;
      }
      int numberSize;
      if (digits > match) {
        numberSize = int.parse(format.substring(match, digits));
        match = digits;
      }

      switch (format[match]) {
        case 's':
          result.add(value);
          break;
        case 'd':
          var number = value.toString();
          result.add(padWithZeros(number, numberSize));
          break;
        case 'x':
          var number = value.toRadixString(16);
          result.add(padWithZeros(number, numberSize));
          break;
        default: throw "not implemented: formatStr does not support format "
            "character ${format[match]}";
      }

      last = match + 1;
    }

    result.add(format.substring(last, format.length));
    format = result.toString();
  });

  return format;
}

_ReverseIterable reversed(List list) => new _ReverseIterable(list);

class _ReverseIterable implements Iterable, Iterator {
  int _index;
  List _list;
  _ReverseIterable(this._list);
  Iterator iterator() {
    if (_index == null) {
      _index = _list.length;
      return this;
    } else {
      return new _ReverseIterable(_list).iterator();
    }
  }

  bool get hasNext => _index > 0;
  next() {
    if (_index == 0) throw new StateError("No more elements");
    return _list[--_index];
  }
}
