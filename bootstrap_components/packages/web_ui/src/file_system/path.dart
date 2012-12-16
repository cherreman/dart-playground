// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This library contains stubs for dartio functionality useful in the browser.
 * Contents of this file were directly copied from dart:io.
 */
// TODO(jacobr): remove when there is a subset of dart:io that runs client and
// server. dartbug.com/5818
// TODO(sigmund): make sure the improvements here are in dart:io before we
// get rid of this file.
library path;

import 'dart:math' as math;

/**
 * A Path, which is a String interpreted as a sequence of path segments,
 * which are strings, separated by forward slashes.
 * Paths are immutable wrappers of a String, that offer member functions for
 * useful path manipulations and queries.  Joining of paths and normalization
 * interpret '.' and '..' in the usual way.
 */
abstract class Path extends Comparable {
  /**
   * Creates a Path from the String [source].  [source] is used as-is, so if
   * the string does not consist of segments separated by forward slashes, the
   * behavior may not be as expected.  Paths are immutable.
   */
  factory Path(String source) => new _Path(source);

  /**
   * Creates a Path from a String that uses the native filesystem's conventions.
   * On Windows, this converts '\' to '/', and adds a '/' before a drive letter.
   * A path starting with '/c:/' (or any other character instead of 'c') is
   * treated specially.  Backwards links ('..') cannot cancel the drive letter.
   */
  factory Path.fromNative(String source) => new _Path.fromNative(source);

  /**
   * Is this path the empty string?
   */
  bool get isEmpty;

  /**
   * Is this path an absolute path, beginning with a path separator?
   */
  bool get isAbsolute;

  /**
   * Does this path end with a path separator?
   */
  bool get hasTrailingSeparator;

  /**
   * Does this path contain no consecutive path separators, no segments that
   * are '.' unless the path is exactly '.', and segments that are '..' only
   * as the leading segments on a relative path?
   */
  bool get isCanonical;

  /**
   * Make a path canonical by dropping segments that are '.', cancelling
   * segments that are '..' with preceding segments, if possible,
   * and combining consecutive path separators.  Leading '..' segments
   * are kept on relative paths, and dropped from absolute paths.
   */
  Path canonicalize();

  /**
   * Joins the relative path [further] to this path.  Canonicalizes the
   * resulting joined path using [canonicalize],
   * interpreting '.' and '..' as directory traversal commands, and removing
   * consecutive path separators.
   *
   * If [further] is an absolute path, an IllegalArgument exception is thrown.
   *
   * Examples:
   *   `new Path('/a/b/c').join(new Path('d/e'))` returns the Path object
   *   containing `'a/b/c/d/e'`.
   *
   *   `new Path('a/b/../c/').join(new Path('d/./e//')` returns the Path
   *   containing `'a/c/d/e/'`.
   *
   *   `new Path('a/b/c').join(new Path('d/../../e')` returns the Path
   *   containing `'a/b/e'`.
   *
   * Note that the join operation does not drop the last segment of the
   * base path, the way URL joining does.  That would be accomplished with
   * basepath.directoryPath.join(further).
   *
   * If you want to avoid joins that traverse
   * parent directories in the base, you can check whether
   * `further.canonicalize()` starts with '../' or equals '..'.
   */
  Path join(Path further);


  /**
   * Returns a path [:relative:] such that
   *    [:base.join(relative) == this.canonicalize():].
   * Throws an exception if such a path is impossible.
   * For example, if [base] is '../../a/b' and [this] is '.'.
   * The computation is independent of the file system and current directory.
   */
  Path relativeTo(Path base);

  /**
   * Converts a path to a string using the native filesystem's conventions.
   *
   * On Windows, converts path separators to backwards slashes, and removes
   * the leading path separator if the path starts with a drive specification.
   * For most valid Windows paths, this should be the inverse of the
   * constructor Path.fromNative.
   */
  String toNativePath();

  /**
   * Returns the path as a string.  If this path is constructed using
   * new Path() or new Path.fromNative() on a non-Windows system, the
   * returned value is the original string argument to the constructor.
   */
  String toString();

  /**
   * Gets the segments of a Path.  Paths beginning or ending with the
   * path separator do not have leading or terminating empty segments.
   * Other than that, the segments are just the result of splitting the
   * path on the path separator.
   *
   *     new Path('/a/b/c/d').segments() == ['a', 'b', 'c', d'];
   *     new Path(' foo bar //../') == [' foo bar ', '', '..'];
   */
  List<String> segments();

  /**
   * Appends [finalSegment] to a path as a new segment.  Adds a path separator
   * between the path and [finalSegment] if the path does not already end in
   * a path separator.  The path is not canonicalized, and [finalSegment] may
   * contain path separators.
   */
  Path append(String finalSegment);

  /**
   * Drops the final path separator and whatever follows it from this Path,
   * and returns the resulting Path object.  If the only path separator in
   * this Path is the first character, returns '/' instead of the empty string.
   * If there is no path separator in the Path, returns the empty string.
   *
   *     new Path('../images/dot.gif').directoryPath == '../images'
   *     new Path('/usr/geoffrey/www/').directoryPath == '/usr/geoffrey/www'
   *     new Path('lost_file_old').directoryPath == ''
   *     new Path('/src').directoryPath == '/'
   *     Note: new Path('/D:/src').directoryPath == '/D:'
   */
  Path get directoryPath;

  /**
   * The part of the path after the last path separator, or the entire path if
   * it contains no path separator.
   *
   *     new Path('images/DSC_0027.jpg).filename == 'DSC_0027.jpg'
   *     new Path('users/fred/').filename == ''
   */
  String get filename;

  /**
   * The part of [filename] before the last '.', or the entire filename if it
   * contains no '.'.  If [filename] is '.' or '..' it is unchanged.
   *
   *     new Path('/c:/My Documents/Heidi.txt').filenameWithoutExtension
   *     would return 'Heidi'.
   *     new Path('not what I would call a path').filenameWithoutExtension
   *     would return 'not what I would call a path'.
   */
  String get filenameWithoutExtension;

  /**
   * The part of [filename] after the last '.', or '' if [filename]
   * contains no '.'.  If [filename] is '.' or '..', returns ''.
   *
   *     new Path('tiger.svg').extension == 'svg'
   *     new Path('/src/dart/dart_secrets').extension == ''
   */
  String get extension;
}

class _Path implements Path {
  final String _path;

  _Path(this._path);
  _Path.fromNative(String source) : _path = _clean(source);

  int get hashCode => _path.hashCode;

  static String _clean(String source) => source;

  bool get isEmpty => _path.isEmpty;
  bool get isAbsolute => _path.startsWith('/');
  bool get hasTrailingSeparator => _path.endsWith('/');

  String toString() => _path;

  // TODO(jmesserly): this should take any Path implementation.
  // See http://dartbug.com/5913
  Path relativeTo(_Path base) {
    // Throws exception if an unimplemented or impossible case is reached.
    // Returns a path "relative" such that
    //    base.join(relative) == this.canonicalize.
    // Throws an exception if no such path exists, or the case is not
    // implemented yet.

    if (base._path == '' || base._path == '.' || base._path == './') {
      return this;
    }

    if (_path.startsWith(base._path)) {
      // For instance:
      // 'a/b/c/d' relative to 'a/b/' returns 'c/d/'
      if (_path == base._path) return new Path('.');
      if (base.hasTrailingSeparator) {
        return new Path(_path.substring(base._path.length));
      }
      if (_path[base._path.length] == '/') {
        return new Path(_path.substring(base._path.length + 1));
      }
    } else if ((!isAbsolute && !base.isAbsolute)
        || (isAbsolute && base.isAbsolute)) {
      // For instance:
      // 'a/b/c/d' relative to 'a/b/e/f' returns '../../e/f'
      var baseSegments = base.segments();
      var pathSegments = segments();
      var min = math.min(baseSegments.length, pathSegments.length);
      int common = 0;
      for (; common < min; common++) {
        if (baseSegments[common] != pathSegments[common]) break;
      }
      var result = new Path('');
      for (int i = common; i < baseSegments.length; i++) {
        result = result.append('..');
      }
      for (int i = common; i < pathSegments.length; i++) {
        result = result.append(pathSegments[i]);
      }
      return result;
    }
    throw new UnimplementedError(
      "Unimplemented case of Path.relativeTo(base):\n"
      "  Arguments: $_path.relativeTo($base)");
  }

  Path join(_Path further) {
    if (further.isAbsolute) {
      throw new ArgumentError(
          "Path.join called with absolute Path as argument.");
    }
    if (isEmpty) {
      return further.canonicalize();
    }
    if (hasTrailingSeparator) {
      return new Path('$_path${further._path}').canonicalize();
    }
    return new Path('$_path/${further._path}').canonicalize();
  }

  // Note: The URI RFC names for these operations are normalize, resolve, and
  // relativize.
  Path canonicalize() {
    if (isCanonical) return this;
    return makeCanonical();
  }

  bool get isCanonical {
    // Contains no consecutive path separators.
    // Contains no segments that are '.'.
    // Absolute paths have no segments that are '..'.
    // All '..' segments of a relative path are at the beginning.
    if (isEmpty) return false;  // The canonical form of '' is '.'.
    if (_path == '.') return true;
    List segs = _path.split('/');  // Don't mask the getter 'segments'.
    if (segs[0] == '') {  // Absolute path
      segs[0] = null;  // Faster than removeRange().
    } else {  // A canonical relative path may start with .. segments.
      for (int pos = 0;
           pos < segs.length && segs[pos] == '..';
           ++pos) {
        segs[pos] = null;
      }
    }
    if (segs.last == '') segs.removeLast();  // Path ends with /.
    // No remaining segments can be ., .., or empty.
    return !segs.some((s) => s == '' || s == '.' || s == '..');
  }

  Path makeCanonical() {
    bool isAbs = isAbsolute;
    List segs = segments();
    String drive;
    if (isAbs &&
        !segs.isEmpty &&
        segs[0].length == 2 &&
        segs[0][1] == ':') {
      drive = segs[0];
      segs.removeRange(0, 1);
    }
    List newSegs = [];
    for (String segment in segs) {
      switch (segment) {
        case '..':
          // Absolute paths drop leading .. markers, including after a drive.
          if (newSegs.isEmpty) {
            if (isAbs) {
              // Do nothing: drop the segment.
            } else {
              newSegs.add('..');
            }
          } else if (newSegs.last == '..') {
            newSegs.add('..');
          } else {
            newSegs.removeLast();
          }
          break;
        case '.':
        case '':
          // Do nothing - drop the segment.
          break;
        default:
          newSegs.add(segment);
          break;
      }
    }

    List segmentsToJoin = [];
    if (isAbs) {
      segmentsToJoin.add('');
      if (drive != null) {
        segmentsToJoin.add(drive);
      }
    }

    if (newSegs.isEmpty) {
      if (isAbs) {
        segmentsToJoin.add('');
      } else {
        segmentsToJoin.add('.');
      }
    } else {
      segmentsToJoin.addAll(newSegs);
      if (hasTrailingSeparator) {
        segmentsToJoin.add('');
      }
    }
    return new Path(Strings.join(segmentsToJoin, '/'));
  }

  String toNativePath() {
    return _path;
  }

  List<String> segments() {
    List result = _path.split('/');
    if (isAbsolute) result.removeRange(0, 1);
    if (hasTrailingSeparator) result.removeLast();
    return result;
  }

  Path append(String finalSegment) {
    if (isEmpty) {
      return new Path(finalSegment);
    } else if (hasTrailingSeparator) {
      return new Path('$_path$finalSegment');
    } else {
      return new Path('$_path/$finalSegment');
    }
  }

  String get filenameWithoutExtension {
    var name = filename;
    if (name == '.' || name == '..') return name;
    int pos = name.lastIndexOf('.');
    return (pos < 0) ? name : name.substring(0, pos);
  }

  String get extension {
    var name = filename;
    int pos = name.lastIndexOf('.');
    return (pos < 0) ? '' : name.substring(pos + 1);
  }

  Path get directoryPath {
    int pos = _path.lastIndexOf('/');
    if (pos < 0) return new Path('');
    while (pos > 0 && _path[pos - 1] == '/') --pos;
    return new Path((pos > 0) ? _path.substring(0, pos) : '/');
  }

  String get filename {
    int pos = _path.lastIndexOf('/');
    return _path.substring(pos + 1);
  }

  int compareTo(Path other) => toString().compareTo(other.toString());
  operator ==(Path other) => compareTo(other) == 0;
}


