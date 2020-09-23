// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:image/image.dart';
import 'package:path/path.dart' as p;

import 'goldens.dart';

String diffImage(
  Image screenshot,
  bool write,
  bool doUpdateScreenshotGoldens,
  String filename,
  String goldensDirectory,
  PixelComparison pixelComparison,
  double maxDiffRateFailure,
  String testResultsPath,
) {
  // Bail out fast if golden doesn't exist, and user doesn't want to create it.
  final File file = File(p.join(
    goldensDirectory,
    filename,
  ));
  if (!file.existsSync() && !write) {
    return '''
Golden file $filename does not exist.

To automatically create this file call matchGoldenFile('$filename', write: true).
''';
  }
  if (write) {
    // Don't even bother with the comparison, just write and return
    print('Updating screenshot golden: $file');
    file.writeAsBytesSync(encodePng(screenshot), flush: true);
    if (doUpdateScreenshotGoldens) {
      // Do not fail tests when bulk-updating screenshot goldens.
      return 'OK';
    } else {
      return 'Golden file $filename was updated. You can remove "write: true" in the call to matchGoldenFile.';
    }
  }

  // Compare screenshots.
  final ImageDiff diff = ImageDiff(
    golden: decodeNamedImage(file.readAsBytesSync(), filename),
    other: screenshot,
    pixelComparison: pixelComparison,
  );

  if (diff.rate > 0) {
    Directory(testResultsPath).createSync(recursive: true);
    final String basename = p.basenameWithoutExtension(file.path);

    final File actualFile =
        File(p.join(testResultsPath, '$basename.actual.png'));
    actualFile.writeAsBytesSync(encodePng(screenshot), flush: true);

    final File diffFile = File(p.join(testResultsPath, '$basename.diff.png'));
    diffFile.writeAsBytesSync(encodePng(diff.diff), flush: true);

    final File expectedFile =
        File(p.join(testResultsPath, '$basename.expected.png'));
    file.copySync(expectedFile.path);

    final File reportFile =
        File(p.join(testResultsPath, '$basename.report.html'));
    reportFile.writeAsStringSync('''
Golden file $filename did not match the image generated by the test.

<table>
  <tr>
    <th>Expected</th>
    <th>Diff</th>
    <th>Actual</th>
  </tr>
  <tr>
    <td>
      <img src="$basename.expected.png">
    </td>
    <td>
      <img src="$basename.diff.png">
    </td>
    <td>
      <img src="$basename.actual.png">
    </td>
  </tr>
</table>
''');

    final StringBuffer message = StringBuffer();
    message.writeln(
        'Golden file $filename did not match the image generated by the test.');
    message.writeln(getPrintableDiffFilesInfo(diff.rate, maxDiffRateFailure));
    message.writeln('You can view the test report in your browser by opening:');

    final String localReportPath = '$testResultsPath/$basename.report.html';
    message.writeln(localReportPath);

    message.writeln(
        'To update the golden file call matchGoldenFile(\'$filename\', write: true).');
    message.writeln('Golden file: ${expectedFile.path}');
    message.writeln('Actual file: ${actualFile.path}');

    if (diff.rate < maxDiffRateFailure) {
      // Issue a warning but do not fail the test.
      print('WARNING:');
      print(message);
      return 'OK';
    } else {
      // Fail test
      return '$message';
    }
  }
  return 'OK';
}
