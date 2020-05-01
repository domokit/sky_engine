// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.6
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;

final ArgParser argParser = ArgParser()
  ..addOption(
    'words',
    abbr: 'w',
    help: 'Sync the word break properties.',
  )
  ..addOption(
    'lines',
    abbr: 'l',
    help: 'Sync the line break properties.',
  )
  ..addFlag(
    'dry',
    abbr: 'd',
    help: 'Dry mode does not write anything to disk. '
        'The output is printed to the console.',
  );

/// A tuple that holds a [start] and [end] of a unicode range and a [property].
class PropertyTuple {
  const PropertyTuple(this.start, this.end, this.property);

  final int start;
  final int end;
  final EnumValue property;

  /// Checks if there's an overlap between this tuple's range and [other]'s
  /// range.
  bool isOverlapping(PropertyTuple other) {
    return start <= other.end && end >= other.start;
  }

  /// Checks if the [other] tuple is adjacent to this tuple.
  ///
  /// Two tuples are considered adjacent if:
  /// - The new tuple's range immediately follows this tuple's range, and
  /// - The new tuple has the same property as this tuple.
  bool isAdjacent(PropertyTuple other) {
    return other.start == end + 1 && property == other.property;
  }

  /// Merges the ranges of the 2 [PropertyTuples] if they are adjacent.
  PropertyTuple extendRange(PropertyTuple extension) {
    assert(isAdjacent(extension));
    return PropertyTuple(start, extension.end, property);
  }
}

final String codegenPath = path.join(
  path.dirname(Platform.script.toFilePath()),
  '../lib/src/engine/text',
);
final String wordBreakCodegen =
    path.join(codegenPath, 'word_break_properties.dart');
final String lineBreakCodegen =
    path.join(codegenPath, 'line_break_properties.dart');

/// Usage (from the root of the web_ui project).
///
/// To generate code for word break properties:
/// ```
/// dart tool/unicode_sync_script.dart -w <path/to/word/break/properties>
/// ```
///
/// To generate code for line break properties:
/// ```
/// dart tool/unicode_sync_script.dart -l <path/to/line/break/properties>
/// ```
///
/// To do a dry run, add the `-d` flag:
///
/// ```
/// dart tool/unicode_sync_script.dart -d ...
/// ```
///
/// This script parses the unicode word/line break properties(1) and generates Dart
/// code(2) that can perform lookups in the unicode ranges to find what property
/// a letter has.
///
/// (1) The word break properties file can be downloaded from:
///     https://www.unicode.org/Public/13.0.0/ucd/auxiliary/WordBreakProperty.txt
///
///     The line break properties file can be downloaded from:
///     https://www.unicode.org/Public/13.0.0/ucd/LineBreak.txt
///
/// (2) The codegen'd Dart files is located at:
///     lib/src/engine/text/word_break_properties.dart
///     lib/src/engine/text/line_break_properties.dart
void main(List<String> arguments) async {
  final ArgResults result = argParser.parse(arguments);
  final PropertiesSyncer syncer = getSyncer(
    result['words'],
    result['lines'],
    result['dry'],
  );

  syncer.perform();
}

PropertiesSyncer getSyncer(
  String wordBreakProperties,
  String lineBreakProperties,
  bool dry,
) {
  if (wordBreakProperties == null && lineBreakProperties == null) {
    print(
        'Expecting either a word break properties file or a line break properties file. None was given.');
    exit(64);
  }
  if (wordBreakProperties != null && lineBreakProperties != null) {
    print(
        'Expecting either a word break properties file or a line break properties file. Both were given.');
    exit(64);
  }
  if (wordBreakProperties != null) {
    return dry
        ? WordBreakPropertiesSyncer.dry(wordBreakProperties)
        : WordBreakPropertiesSyncer(wordBreakProperties, '$wordBreakCodegen');
  } else {
    return dry
        ? LineBreakPropertiesSyncer.dry(lineBreakProperties)
        : LineBreakPropertiesSyncer(lineBreakProperties, '$lineBreakCodegen');
  }
}

/// Base class that provides common logic for syncing all kinds of unicode
/// properties (e.g. word break properties, line break properties, etc).
///
/// Subclasses implement the [template] method which receives as argument the
/// list of data parsed by [processLines].
abstract class PropertiesSyncer {
  PropertiesSyncer(this._src, this._dest) : _dryRun = false;
  PropertiesSyncer.dry(this._src)
      : _dest = null,
        _dryRun = true;

  final String _src;
  final String _dest;
  final bool _dryRun;

  String get prefix;
  String get enumDocLink;

  void perform() async {
    final List<String> lines = await File(_src).readAsLines();
    final List<String> header = extractHeader(lines);
    final PropertyCollection data = PropertyCollection.fromLines(lines);

    final String output = template(header, data);

    if (_dryRun) {
      print(output);
    } else {
      final IOSink sink = File(_dest).openWrite();
      sink.write(output);
    }
  }

  String template(List<String> header, PropertyCollection data) {
    return '''
// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// AUTO-GENERATED FILE.
// Generated by: tool/unicode_sync_script.dart
//
// Source:
// ${header.join('\n// ')}

// @dart = 2.6
part of engine;

/// For an explanation of these enum values, see:
///
/// * ${enumDocLink}
enum ${prefix}CharProperty {
  ${_getEnumValues(data.enumCollection).join('\n  ')}
}

const String _packed${prefix}BreakProperties =
  '${_packProperties(data)}';


UnicodePropertyLookup<${prefix}CharProperty> ${prefix.toLowerCase()}Lookup =
    UnicodePropertyLookup<${prefix}CharProperty>.fromPackedData(
  _packed${prefix}BreakProperties,
  ${_getSingleRangesCount(data)},
  ${prefix}CharProperty.values,
);
''';
  }

  Iterable<String> _getEnumValues(EnumCollection enumCollection) {
    return enumCollection.values.map(
      (EnumValue value) =>
          '${value.enumName}, // serialized as "${value.serialized}"',
    );
  }

  int _getSingleRangesCount(PropertyCollection data) {
    int count = 0;
    for (final PropertyTuple tuple in data.tuples) {
      if (tuple.start == tuple.end) {
        count++;
      }
    }
    return count;
  }

  String _packProperties(PropertyCollection data) {
    final StringBuffer buffer = StringBuffer();
    for (final PropertyTuple tuple in data.tuples) {
      buffer.write(tuple.start.toRadixString(36).padLeft(4, '0'));
      if (tuple.start == tuple.end) {
        buffer.write('!');
      } else {
        buffer.write(tuple.end.toRadixString(36).padLeft(4, '0'));
      }
      buffer.write(tuple.property.serialized);
    }
    return buffer.toString();
  }
}

/// Syncs Unicode's word break properties.
class WordBreakPropertiesSyncer extends PropertiesSyncer {
  WordBreakPropertiesSyncer(String src, String dest) : super(src, dest);
  WordBreakPropertiesSyncer.dry(String src) : super.dry(src);

  final String prefix = 'Word';
  final String enumDocLink = 'http://unicode.org/reports/tr29/#Table_Word_Break_Property_Values';
}

/// Syncs Unicode's line break properties.
class LineBreakPropertiesSyncer extends PropertiesSyncer {
  LineBreakPropertiesSyncer(String src, String dest) : super(src, dest);
  LineBreakPropertiesSyncer.dry(String src) : super.dry(src);

  final String prefix = 'Line';
  final String enumDocLink = 'https://unicode.org/reports/tr14/#DescriptionOfProperties';
}

/// Holds the collection of properties parsed from the unicode spec file.
class PropertyCollection {
  PropertyCollection.fromLines(List<String> lines) {
    final List<PropertyTuple> unprocessedTuples = lines
        .map(removeCommentFromLine)
        .where((String line) => line.isNotEmpty)
        .map(parseLineIntoPropertyTuple)
        .toList();
    tuples = processTuples(unprocessedTuples);
  }

  List<PropertyTuple> tuples;

  final EnumCollection enumCollection = EnumCollection();

  /// Examples:
  ///
  /// 00C0..00D6    ; ALetter
  /// 037F          ; ALetter
  ///
  /// Would be parsed into:
  ///
  /// ```dart
  /// PropertyTuple(192, 214, EnumValue('ALetter'));
  /// PropertyTuple(895, 895, EnumValue('ALetter'));
  /// ```
  PropertyTuple parseLineIntoPropertyTuple(String line) {
    final List<String> split = line.split(';');
    final String rangeStr = split[0].trim();
    final String propertyStr = split[1].trim();

    return PropertyTuple(
      getRangeStart(rangeStr),
      getRangeEnd(rangeStr),
      enumCollection.add(propertyStr),
    );
  }
}

/// Represents the collection of values of an enum.
class EnumCollection {
  final List<EnumValue> values = <EnumValue>[];

  EnumValue add(String name) {
    final int index =
        values.indexWhere((EnumValue value) => value.name == name);
    EnumValue value;
    if (index == -1) {
      value = EnumValue(values.length, name);
      values.add(value);
    } else {
      value = values[index];
    }
    return value;
  }
}

/// Represents a single value in an [EnumCollection].
class EnumValue {
  EnumValue(this.index, this.name);

  final int index;
  final String name;

  /// Returns a serialized, compact format of the enum value.
  ///
  /// Enum values are serialized based on their index. We start serializing them
  /// to "A", "B", "C", etc until we reach "Z". Then we continue with "a", "b",
  /// "c", etc.
  String get serialized {
    // "A" <=> 65
    // "Z" <=> 90
    // "a" <=> 97
    // "z" <=> 122

    // We assign uppercase letters to the first 26 enum values.
    if (index < 26) {
      return String.fromCharCode(65 + index);
    }
    // Enum values above 26 will be assigned a lowercase letter.
    return String.fromCharCode(97 + index - 26);
  }

  /// Returns the enum name that'll be used in the Dart code.
  ///
  /// ```dart
  /// enum CharProperty {
  ///   ALetter, // <-- this is the name returned by this method ("ALetter").
  ///   Numeric,
  ///   // etc...
  /// }
  /// ```
  String get enumName {
    return name.replaceAll('_', '');
  }
}

/// Sorts tuples and combines adjacent tuples that have ranges that can be
/// merged.
Iterable<PropertyTuple> processTuples(List<PropertyTuple> data) {
  data.sort(
    // Ranges don't overlap so it's safe to sort based on the start of each
    // range.
    (PropertyTuple tuple1, PropertyTuple tuple2) =>
        tuple1.start.compareTo(tuple2.start),
  );
  verifyNoOverlappingRanges(data);
  return combineAdjacentRanges(data);
}

/// Example:
///
/// ```
/// 0x01C4..0x0293; ALetter
/// 0x0294..0x0294; ALetter
/// 0x0295..0x02AF; ALetter
/// ```
///
/// will get combined into:
///
/// ```
/// 0x01C4..0x02AF; ALetter
/// ```
List<PropertyTuple> combineAdjacentRanges(List<PropertyTuple> data) {
  final List<PropertyTuple> result = <PropertyTuple>[data.first];
  for (int i = 1; i < data.length; i++) {
    if (result.last.isAdjacent(data[i])) {
      result.last = result.last.extendRange(data[i]);
    } else {
      result.add(data[i]);
    }
  }
  return result;
}

int getRangeStart(String range) {
  return int.parse(range.split('..')[0], radix: 16);
}

int getRangeEnd(String range) {
  if (range.contains('..')) {
    return int.parse(range.split('..')[1], radix: 16);
  }
  return int.parse(range, radix: 16);
}

void verifyNoOverlappingRanges(List<PropertyTuple> data) {
  for (int i = 1; i < data.length; i++) {
    if (data[i].isOverlapping(data[i - 1])) {
      throw Exception('Data contains overlapping ranges.');
    }
  }
}

List<String> extractHeader(List<String> lines) {
  final List<String> headerLines = <String>[];
  for (String line in lines) {
    if (line.trim() == '#' || line.trim().isEmpty) {
      break;
    }
    if (line.isNotEmpty) {
      headerLines.add(line);
    }
  }
  return headerLines;
}

String removeCommentFromLine(String line) {
  final int poundIdx = line.indexOf('#');
  return (poundIdx == -1) ? line : line.substring(0, poundIdx);
}
