// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:ui/ui.dart' as ui;

import '../dom.dart';
import 'canvas_paragraph.dart';
import 'layout_fragmenter.dart';
import 'line_breaker.dart';
import 'measurement.dart';
import 'paragraph.dart';
import 'ruler.dart';

/// Performs layout on a [CanvasParagraph].
///
/// It uses a [DomCanvasElement] to measure text.
class TextLayoutService {
  TextLayoutService(this.paragraph);

  final CanvasParagraph paragraph;

  final DomCanvasRenderingContext2D context =
      createDomCanvasElement().context2D;

  // *** Results of layout *** //

  // Look at the Paragraph class for documentation of the following properties.

  double width = -1.0;

  double height = 0.0;

  ParagraphLine? longestLine;

  double minIntrinsicWidth = 0.0;

  double maxIntrinsicWidth = 0.0;

  double alphabeticBaseline = -1.0;

  double ideographicBaseline = -1.0;

  bool didExceedMaxLines = false;

  final List<ParagraphLine> lines = <ParagraphLine>[];

  /// The bounds that contain the text painted inside this paragraph.
  ui.Rect get paintBounds => _paintBounds;
  ui.Rect _paintBounds = ui.Rect.zero;

  late final Spanometer spanometer = Spanometer(paragraph, context);

  late final LayoutFragmenter layoutFragmenter = LayoutFragmenter(
    paragraph.plainText,
    paragraph.paragraphStyle.effectiveTextDirection,
    paragraph.spans,
  );

  /// Performs the layout on a paragraph given the [constraints].
  ///
  /// The function starts by resetting all layout-related properties. Then it
  /// starts looping through the paragraph to calculate all layout metrics.
  ///
  /// It uses a [Spanometer] to perform measurements within spans of the
  /// paragraph. It also uses [LineBuilders] to generate [ParagraphLine]s as
  /// it iterates through the paragraph.
  ///
  /// The main loop keeps going until:
  ///
  /// 1. The end of the paragraph is reached (i.e. LineBreakType.endOfText).
  /// 2. Enough lines have been computed to satisfy [maxLines].
  /// 3. An ellipsis is appended because of an overflow.
  void performLayout(ui.ParagraphConstraints constraints) {
    final int spanCount = paragraph.spans.length;

    // Reset results from previous layout.
    width = constraints.width;
    height = 0.0;
    longestLine = null;
    minIntrinsicWidth = 0.0;
    maxIntrinsicWidth = 0.0;
    didExceedMaxLines = false;
    lines.clear();

    // TODO(mdebbar): if (paragraph.isEmpty) { ... }
    if (spanCount == 0) {
      return;
    }

    LineBuilder currentLine =
        LineBuilder.first(paragraph, spanometer, maxWidth: constraints.width);

    final List<LayoutFragment> fragments =
        layoutFragmenter.fragment()..forEach(spanometer.measureFragment);

    outerLoop:
    for (final LayoutFragment fragment in fragments) {
      currentLine.addFragment(fragment);

      while (currentLine.isOverflowing) {
        if (currentLine.canHaveEllipsis) {
          currentLine.insertEllipsis();
          lines.add(currentLine.build());
          // TODO(mdebbar): Add tests for didExceedMaxLines.
          didExceedMaxLines = true;
          break outerLoop;
        }

        if (currentLine.isBreakable) {
          currentLine.revertToLastBreakOpportunity();
        } else {
          // The line can't be legally broken, so the last fragment (that caused
          // the line to overflow) needs to be force-broken.
          currentLine.forceBreakLastFragment();
        }
        lines.add(currentLine.build());
        currentLine = currentLine.nextLine();
      }

      if (currentLine.isHardBreak) {
        lines.add(currentLine.build());
        currentLine = currentLine.nextLine();
      }
    }

    final int? maxLines = paragraph.paragraphStyle.maxLines;
    if (maxLines != null && lines.length > maxLines) {
      didExceedMaxLines = true;
      // TODO(mdebbar): Should we remove these lines before or after calculating min/max intrinsic width?
      lines.removeRange(maxLines, lines.length);
    }

    // ***************************************************************** //
    // *** PARAGRAPH BASELINE & HEIGHT & LONGEST LINE & PAINT BOUNDS *** //
    // ***************************************************************** //

    double boundsLeft = double.infinity;
    double boundsRight = double.negativeInfinity;
    for (final ParagraphLine line in lines) {
      height += line.height;
      if (alphabeticBaseline == -1.0) {
        alphabeticBaseline = line.baseline;
        ideographicBaseline = alphabeticBaseline * baselineRatioHack;
      }
      final double longestLineWidth = longestLine?.width ?? 0.0;
      if (longestLineWidth < line.width) {
        longestLine = line;
      }

      final double left = line.left;
      if (left < boundsLeft) {
        boundsLeft = left;
      }
      final double right = left + line.width;
      if (right > boundsRight) {
        boundsRight = right;
      }
    }
    _paintBounds = ui.Rect.fromLTRB(
      boundsLeft,
      0,
      boundsRight,
      height,
    );

    // ************************** //
    // *** POSITION FRAGMENTS *** //
    // ************************** //

    if (lines.isNotEmpty) {
      final ParagraphLine lastLine = lines.last;
      final bool shouldJustifyParagraph = width.isFinite &&
          paragraph.paragraphStyle.textAlign == ui.TextAlign.justify;

      for (final ParagraphLine line in lines) {
        // Don't apply justification to the last line.
        final bool shouldJustifyLine =
            shouldJustifyParagraph && line != lastLine;
        _positionLineFragments(line, withJustification: shouldJustifyLine);
      }
    }

    // ******************************** //
    // *** MAX/MIN INTRINSIC WIDTHS *** //
    // ******************************** //

    // TODO(mdebbar): Handle maxLines https://github.com/flutter/flutter/issues/91254

    double runningMinIntrinsicWidth = 0;
    double runningMaxIntrinsicWidth = 0;

    for (final LayoutFragment fragment in fragments) {
      runningMinIntrinsicWidth += fragment.widthExcludingTrailingSpaces;
      // Max intrinsic width includes the width of trailing spaces.
      runningMaxIntrinsicWidth += fragment.widthIncludingTrailingSpaces;

      switch (fragment.type) {
        case LineBreakType.prohibited:
          break;

        case LineBreakType.opportunity:
          minIntrinsicWidth = math.max(minIntrinsicWidth, runningMinIntrinsicWidth);
          runningMinIntrinsicWidth = 0;
          break;

        case LineBreakType.mandatory:
        case LineBreakType.endOfText:
          minIntrinsicWidth = math.max(minIntrinsicWidth, runningMinIntrinsicWidth);
          maxIntrinsicWidth = math.max(maxIntrinsicWidth, runningMaxIntrinsicWidth);
          runningMinIntrinsicWidth = 0;
          runningMaxIntrinsicWidth = 0;
          break;
      }
    }
  }

  ui.TextDirection get _paragraphDirection =>
      paragraph.paragraphStyle.effectiveTextDirection;

  /// Positions the fragments in the given [line] and takes into account their
  /// directions, the paragraph's direction, and alignment justification.
  void _positionLineFragments(
    ParagraphLine line, {
    required bool withJustification,
  }) {
    final List<LayoutFragment> fragments = line.fragments;

    int i = 0;
    double cumulativeWidth = 0.0;
    while (i < fragments.length) {
      final LayoutFragment fragment = fragments[i];
      if (fragment.textDirection == _paragraphDirection) {
        // The fragment is in the same direction as the paragraph.
        fragment.setPosition(startOffset: cumulativeWidth, line: line);
        if (withJustification) {
          fragment.justifyTo(width, line);
        }

        cumulativeWidth += fragment.widthIncludingTrailingSpaces;
        i++;
        continue;
      }

      // At this point, we found a fragment that has the opposite direction to
      // the paragraph. This could be a sequence of one or more fragments.
      //
      // These fragments should flow in the opposite direction. So we need to
      // position them in reverse order.
      //
      // If the last fragment in the sequence is space-only (contains only
      // whitespace characters), it should be excluded from the sequence.
      //
      // Example: an LTR paragraph with the contents:
      //
      // "ABC rtl1 rtl2 rtl3 XYZ"
      //     ^    ^    ^    ^
      //    SP1  SP2  SP3  SP4
      //
      //
      // box direction:    LTR           RTL               LTR
      //                |------>|<-----------------------|------>
      //                +----------------------------------------+
      //                | ABC | | rtl3 | | rtl2 | | rtl1 | | XYZ |
      //                +----------------------------------------+
      //                       ^        ^        ^        ^
      //                      SP1      SP3      SP2      SP4
      //
      // Notice how SP2 and SP3 are flowing in the RTL direction because of the
      // surrounding RTL words. SP4 is also preceded by an RTL word, but it marks
      // the end of the RTL sequence, so it goes back to flowing in the paragraph
      // direction (LTR).

      final int first = i;
      int lastNonSpaceFragment = first;
      i++;
      while (i < fragments.length && fragments[i].textDirection != _paragraphDirection) {
        final LayoutFragment fragment = fragments[i];
        if (fragment.isSpaceOnly) {
          // Do nothing.
        } else {
          lastNonSpaceFragment = i;
        }
        i++;
      }
      final int last = lastNonSpaceFragment;
      i = lastNonSpaceFragment + 1;

      // The range (first:last) is the entire sequence of boxes that have the
      // opposite direction to the paragraph.
      final double sequenceWidth = _positionLineBoxesInReverse(
        line,
        first,
        last,
        startOffset: cumulativeWidth,
        withJustification: withJustification,
      );
      cumulativeWidth += sequenceWidth;
    }
  }

  /// Positions a sequence of boxes in the direction opposite to the paragraph
  /// text direction.
  ///
  /// This is needed when a right-to-left sequence appears in the middle of a
  /// left-to-right paragraph, or vice versa.
  ///
  /// Returns the total width of all the positioned boxes in the sequence.
  ///
  /// [first] and [last] are expected to be inclusive.
  double _positionLineBoxesInReverse(
    ParagraphLine line,
    int first,
    int last, {
    required double startOffset,
    required bool withJustification,
  }) {
    final List<LayoutFragment> fragments = line.fragments;
    double cumulativeWidth = 0.0;
    for (int i = last; i >= first; i--) {
      // Update the visual position of each fragment.
      final LayoutFragment fragment = fragments[i];
      assert(fragment.textDirection != _paragraphDirection);

      fragment.setPosition(startOffset: cumulativeWidth, line: line);
      if (withJustification) {
        fragment.justifyTo(width, line);
      }

      cumulativeWidth += fragment.widthIncludingTrailingSpaces;
    }
    return cumulativeWidth;
  }

  List<ui.TextBox> getBoxesForPlaceholders() {
    final List<ui.TextBox> boxes = <ui.TextBox>[];
    for (final ParagraphLine line in lines) {
      for (final LayoutFragment fragment in line.fragments) {
        if (fragment.isPlaceholder) {
          boxes.add(fragment.toTextBox());
        }
      }
    }
    return boxes;
  }

  List<ui.TextBox> getBoxesForRange(
    int start,
    int end,
    ui.BoxHeightStyle boxHeightStyle,
    ui.BoxWidthStyle boxWidthStyle,
  ) {
    // Zero-length ranges and invalid ranges return an empty list.
    if (start >= end || start < 0 || end < 0) {
      return <ui.TextBox>[];
    }

    final int length = paragraph.toPlainText().length;
    // Ranges that are out of bounds should return an empty list.
    if (start > length || end > length) {
      return <ui.TextBox>[];
    }

    final List<ui.TextBox> boxes = <ui.TextBox>[];

    for (final ParagraphLine line in lines) {
      if (line.overlapsWith(start, end)) {
        for (final LayoutFragment fragment in line.fragments) {
          if (!fragment.isPlaceholder && fragment.overlapsWith(start, end)) {
            boxes.add(fragment.toTextBox(start: start, end: end));
          }
        }
      }
    }
    return boxes;
  }

  ui.TextPosition getPositionForOffset(ui.Offset offset) {
    // After layout, each line has boxes that contain enough information to make
    // it possible to do hit testing. Once we find the box, we look inside that
    // box to find where exactly the `offset` is located.

    final ParagraphLine line = _findLineForY(offset.dy);
    // [offset] is to the left of the line.
    if (offset.dx <= line.left) {
      return ui.TextPosition(
        offset: line.startIndex,
      );
    }

    // [offset] is to the right of the line.
    if (offset.dx >= line.left + line.widthWithTrailingSpaces) {
      return ui.TextPosition(
        offset: line.endIndex - line.trailingNewlines,
        affinity: ui.TextAffinity.upstream,
      );
    }

    final double dx = offset.dx - line.left;
    for (final LayoutFragment fragment in line.fragments) {
      if (fragment.left <= dx && dx <= fragment.right) {
        return fragment.getPositionForX(dx);
      }
    }
    // Is this ever reachable?
    return ui.TextPosition(offset: line.startIndex);
  }

  ParagraphLine _findLineForY(double y) {
    // We could do a binary search here but it's not worth it because the number
    // of line is typically low, and each iteration is a cheap comparison of
    // doubles.
    for (final ParagraphLine line in lines) {
      if (y <= line.height) {
        return line;
      }
      y -= line.height;
    }
    return lines.last;
  }
}

/// Builds instances of [ParagraphLine] for the given [paragraph].
///
/// Usage of this class starts by calling [LineBuilder.first] to start building
/// the first line of the paragraph.
///
/// Then fragments can be added by calling [addFragment].
///
/// Before adding a fragment, the method [canAddFragment] helps determine
/// whether the line can fit a certain fragment or not.
///
/// Once the line is complete, it can be built by calling [build] that generates
/// a [ParagraphLine] instance.
///
/// To start building the next line, simply call [nextLine] to get a new
/// [LineBuilder] for the next line.
class LineBuilder {
  LineBuilder._(
    this.paragraph,
    this.spanometer, {
    required this.maxWidth,
    required this.lineNumber,
    required this.accumulatedHeight,
    required List<LayoutFragment> fragments,
  }) : _fragments = fragments {
    _recalculateMetrics();
  }

  /// Creates a [LineBuilder] for the first line in a paragraph.
  factory LineBuilder.first(
    CanvasParagraph paragraph,
    Spanometer spanometer, {
    required double maxWidth,
  }) {
    return LineBuilder._(
      paragraph,
      spanometer,
      maxWidth: maxWidth,
      lineNumber: 0,
      accumulatedHeight: 0.0,
      fragments: <LayoutFragment>[],
    );
  }

  final List<LayoutFragment> _fragments;
  List<LayoutFragment>? _fragmentsForNextLine;

  int get startIndex {
    assert(_fragments.isNotEmpty || _fragmentsForNextLine!.isNotEmpty);

    return isNotEmpty
      ? _fragments.first.start
      : _fragmentsForNextLine!.first.start;
  }

  int get endIndex {
    assert(_fragments.isNotEmpty || _fragmentsForNextLine!.isNotEmpty);

    return isNotEmpty
      ? _fragments.last.end
      : _fragmentsForNextLine!.first.start;
  }

  final double maxWidth;
  final CanvasParagraph paragraph;
  final Spanometer spanometer;
  final int lineNumber;

  /// The accumulated height of all preceding lines, excluding the current line.
  final double accumulatedHeight;

  /// The width of the line so far, excluding trailing white space.
  double width = 0.0;

  /// The width of the line so far, including trailing white space.
  double widthIncludingSpace = 0.0;

  double get _widthExcludingLastFragment => _fragments.length > 1
    ? widthIncludingSpace - _fragments.last.widthIncludingTrailingSpaces
    : 0;

  /// The distance from the top of the line to the alphabetic baseline.
  double ascent = 0.0;

  /// The distance from the bottom of the line to the alphabetic baseline.
  double descent = 0.0;

  /// The height of the line so far.
  double get height => ascent + descent;

  int _lastBreakableFragment = -1;
  int _breakCount = 0;

  /// Whether this line can be legally broken into more than one line.
  bool get isBreakable {
    if (_fragments.isEmpty) {
      return false;
    }
    if (_fragments.last.isBreak) {
      // We need one more break other than the last one.
      return _breakCount > 1;
    }
    return _breakCount > 0;
  }

  /// Returns true if the line can't be legally broken any further.
  bool get isNotBreakable => !isBreakable;

  int _spaceCount = 0;

  bool get isEmpty => _fragments.isEmpty;
  bool get isNotEmpty => _fragments.isNotEmpty;

  bool get isHardBreak => _fragments.isNotEmpty && _fragments.last.isHardBreak;

  /// The horizontal offset necessary for the line to be correctly aligned.
  double get alignOffset {
    final double emptySpace = maxWidth - width;
    final ui.TextAlign textAlign = paragraph.paragraphStyle.effectiveTextAlign;

    switch (textAlign) {
      case ui.TextAlign.center:
        return emptySpace / 2.0;
      case ui.TextAlign.right:
        return emptySpace;
      case ui.TextAlign.start:
        return _paragraphDirection == ui.TextDirection.rtl ? emptySpace : 0.0;
      case ui.TextAlign.end:
        return _paragraphDirection == ui.TextDirection.rtl ? 0.0 : emptySpace;
      default:
        return 0.0;
    }
  }

  bool get isOverflowing => width > maxWidth;

  bool get canHaveEllipsis {
    if (paragraph.paragraphStyle.ellipsis == null) {
      return false;
    }

    final int? maxLines = paragraph.paragraphStyle.maxLines;
    return (maxLines == null) || (maxLines == lineNumber + 1);
  }

  ui.TextDirection get _paragraphDirection =>
      paragraph.paragraphStyle.effectiveTextDirection;

  void addFragment(LayoutFragment fragment) {
    _updateMetrics(fragment);

    if (fragment.isBreak) {
      _lastBreakableFragment = _fragments.length;
    }

    _fragments.add(fragment);
  }

  /// Updates the [LineBuilder]'s metrics to take into account the new [fragment].
  void _updateMetrics(LayoutFragment fragment) {
    _spaceCount += fragment.trailingSpaces;

    if (!fragment.isSpaceOnly) {
      width = widthIncludingSpace + fragment.widthExcludingTrailingSpaces;
    }
    widthIncludingSpace += fragment.widthIncludingTrailingSpaces;

    if (fragment.isPlaceholder) {
      return _updateHeightForPlaceholder(fragment);
    }

    if (fragment.isBreak) {
      _breakCount++;
    }

    ascent = math.max(ascent, fragment.ascent);
    descent = math.max(descent, fragment.descent);
  }

  void _updateHeightForPlaceholder(LayoutFragment fragment) {
    final PlaceholderSpan placeholder = fragment.span as PlaceholderSpan;

    final double ascent, descent;
    switch (placeholder.alignment) {
      case ui.PlaceholderAlignment.top:
        // The placeholder is aligned to the top of text, which means it has the
        // same `ascent` as the remaining text. We only need to extend the
        // `descent` enough to fit the placeholder.
        ascent = this.ascent;
        descent = placeholder.height - this.ascent;
        break;

      case ui.PlaceholderAlignment.bottom:
        // The opposite of `top`. The `descent` is the same, but we extend the
        // `ascent`.
        ascent = placeholder.height - this.descent;
        descent = this.descent;
        break;

      case ui.PlaceholderAlignment.middle:
        final double textMidPoint = height / 2;
        final double placeholderMidPoint = placeholder.height / 2;
        final double diff = placeholderMidPoint - textMidPoint;
        ascent = this.ascent + diff;
        descent = this.descent + diff;
        break;

      case ui.PlaceholderAlignment.aboveBaseline:
        ascent = placeholder.height;
        descent = 0.0;
        break;

      case ui.PlaceholderAlignment.belowBaseline:
        ascent = 0.0;
        descent = placeholder.height;
        break;

      case ui.PlaceholderAlignment.baseline:
        ascent = placeholder.baselineOffset;
        descent = placeholder.height - ascent;
        break;
    }

    this.ascent = math.max(this.ascent, ascent);
    this.descent = math.max(this.descent, descent);

    // Update the metrics of the fragment to reflect the calculated ascent and
    // descent.
    fragment.setMetrics(spanometer,
      ascent: ascent,
      descent: descent,
      widthExcludingTrailingSpaces: fragment.widthExcludingTrailingSpaces,
      widthIncludingTrailingSpaces: fragment.widthIncludingTrailingSpaces,
    );
  }

  void _recalculateMetrics() {
    width = 0;
    widthIncludingSpace = 0;
    ascent = 0;
    descent = 0;
    _spaceCount = 0;
    _breakCount = 0;
    _lastBreakableFragment = -1;

    for (int i = 0; i < _fragments.length; i++) {
      _updateMetrics(_fragments[i]);
      if (_fragments[i].isBreak) {
        _lastBreakableFragment = i;
      }
    }
  }

  void forceBreakLastFragment({ double? availableWidth, bool allowEmptyLine = false }) {
    assert(isNotEmpty);

    availableWidth ??= maxWidth;
    assert(widthIncludingSpace > availableWidth);

    _fragmentsForNextLine ??= <LayoutFragment>[];

    // When the line has fragments other than the last one, we can always allow
    // the last fragment to be empty (i.e. completely removed from the line).
    final bool hasOtherFragments = _fragments.length > 1;
    final bool allowLastFragmentToBeEmpty = hasOtherFragments || allowEmptyLine;

    final LayoutFragment lastFragment = _fragments.removeLast();
    _recalculateMetrics();

    final ParagraphSpan span = lastFragment.span;
    if (span is FlatTextSpan) {
      spanometer.currentSpan = span;
      final double availableWidthForFragment = availableWidth - widthIncludingSpace;
      final int forceBreakEnd = lastFragment.end - lastFragment.trailingNewlines;

      final int breakingPoint = spanometer.forceBreak(
        lastFragment.start,
        forceBreakEnd,
        availableWidth: availableWidthForFragment,
        allowEmpty: allowLastFragmentToBeEmpty,
      );

      if (breakingPoint == forceBreakEnd) {
        // The entire fragment remained intact. Let's put it back without any
        // changes.
        addFragment(lastFragment);
        return;
      }

      final List<LayoutFragment?> split = lastFragment.split(breakingPoint);
      final LayoutFragment? first = split.first;
      final LayoutFragment? second = split.last;
      if (first != null) {
        spanometer.measureFragment(first);
        addFragment(first);
      }
      if (second != null) {
        spanometer.measureFragment(second);
        _fragmentsForNextLine!.insert(0, second);
      }
    } else {
      // This is a placeholder and we can't force-break a placeholder.

      if (allowLastFragmentToBeEmpty) {
        _fragmentsForNextLine!.insert(0, lastFragment);
      } else {
        // TODO(mdebbar): Add test for the case of a single placeholder that
        //                doesn't fit in one line.
        addFragment(lastFragment);
      }
    }
  }

  void insertEllipsis() {
    assert(canHaveEllipsis);
    assert(isOverflowing);

    final String ellipsisText = paragraph.paragraphStyle.ellipsis!;

    _fragmentsForNextLine = <LayoutFragment>[];

    spanometer.currentSpan = _fragments.last.span;
    double ellipsisWidth = spanometer.measureText(ellipsisText);
    double availableWidth = math.max(0, maxWidth - ellipsisWidth);

    while (_widthExcludingLastFragment > availableWidth) {
      _fragmentsForNextLine!.insert(0, _fragments.removeLast());
      _recalculateMetrics();

      spanometer.currentSpan = _fragments.last.span;
      ellipsisWidth = spanometer.measureText(ellipsisText);
      availableWidth = maxWidth - ellipsisWidth;
    }

    final LayoutFragment lastFragment = _fragments.last;
    forceBreakLastFragment(availableWidth: availableWidth, allowEmptyLine: true);

    final EllipsisFragment ellipsisFragment = EllipsisFragment(
      endIndex,
      lastFragment.textDirection,
      lastFragment.span,
    );
    ellipsisFragment.setMetrics(spanometer,
      ascent: lastFragment.ascent,
      descent: lastFragment.descent,
      widthExcludingTrailingSpaces: ellipsisWidth,
      widthIncludingTrailingSpaces: ellipsisWidth,
    );
    addFragment(ellipsisFragment);
  }

  void revertToLastBreakOpportunity() {
    assert(isBreakable);

    // The last fragment in the line may or may not be breakable. Regardless,
    // it needs to be removed.
    //
    // We need to find the latest breakable fragment in the line (other than the
    // last fragment). Such breakable fragment is guaranteed to be found because
    // the line `isBreakable`.

    // Start from the end and skip the last fragment.
    int i = _fragments.length - 2;
    while (!_fragments[i].isBreak) {
      i--;
    }

    _fragmentsForNextLine = _fragments.getRange(i + 1, _fragments.length).toList();
    _fragments.removeRange(i + 1, _fragments.length);
    _recalculateMetrics();
  }

  /// Builds the [ParagraphLine] instance that represents this line.
  ParagraphLine build() {
    if (_fragmentsForNextLine == null) {
      _fragmentsForNextLine = _fragments.getRange(_lastBreakableFragment + 1, _fragments.length).toList();
      _fragments.removeRange(_lastBreakableFragment + 1, _fragments.length);
    }

    final int trailingNewlines = isEmpty ? 0 : _fragments.last.trailingNewlines;
    final int trailingSpaces = _processTrailingSpaces();

    return ParagraphLine(
      lineNumber: lineNumber,
      startIndex: startIndex,
      endIndex: endIndex,
      trailingNewlines: trailingNewlines,
      trailingSpaces: trailingSpaces,
      spaceCount: _spaceCount,
      hardBreak: isHardBreak,
      width: width,
      widthWithTrailingSpaces: widthIncludingSpace,
      left: alignOffset,
      height: height,
      baseline: accumulatedHeight + ascent,
      ascent: ascent,
      descent: descent,
      fragments: _fragments,
    );
  }

  int _processTrailingSpaces() {
    int trailingSpaces = 0;
    int i;
    for (i = _fragments.length - 1; i >= 0; i--) {
      final LayoutFragment fragment = _fragments[i];
      trailingSpaces += fragment.trailingSpaces;

      if (fragment.trailingSpaces > 0 && fragment.textDirection != _paragraphDirection) {
        _swapDirectionOfTrailingSpaces(i);
      }

      // If we're done with trailing spaces, stop processing.
      if (!fragment.isSpaceOnly) {
        break;
      }
    }
    return trailingSpaces;
  }

  void _swapDirectionOfTrailingSpaces(int fragmentIndex) {
    final LayoutFragment fragment = _fragments[fragmentIndex];
    assert(fragment.trailingSpaces > 0);
    assert(fragment.textDirection != _paragraphDirection);

    if (fragment.isSpaceOnly) {
      _fragments[fragmentIndex] = _swapTextDirection(fragment, _paragraphDirection);
    } else {
      // The fragment contains text and spaces. We need to split them first,
      // then swap the direction of the space-only fragment.
      final List<LayoutFragment?> split = _splitTrailingSpaces(fragment);
      final LayoutFragment textFragment = split.first!;
      final LayoutFragment spaceFragment = split.last!;
      _fragments[fragmentIndex] = textFragment;
      _fragments.insert(fragmentIndex + 1, _swapTextDirection(spaceFragment, _paragraphDirection));
    }
  }

  List<LayoutFragment> _splitTrailingSpaces(LayoutFragment fragment) {
    // The fragment has to contain text AND spaces.
    assert(fragment.trailingSpaces > 0);
    assert(!fragment.isSpaceOnly);

    final List<LayoutFragment> split = fragment.split(fragment.end - fragment.trailingSpaces) as List<LayoutFragment>;
    // We can reuse existing metrics with some adjustments instead of measuring again.
    split.first.setMetrics(spanometer,
      ascent: fragment.ascent,
      descent: fragment.descent,
      widthExcludingTrailingSpaces: fragment.widthExcludingTrailingSpaces,
      // There's no trailing spaces anymore.
      widthIncludingTrailingSpaces: fragment.widthExcludingTrailingSpaces,
    );
    split.last.setMetrics(spanometer,
      ascent: fragment.ascent,
      descent: fragment.descent,
      // There's no text anymore, only spaces.
      widthExcludingTrailingSpaces: 0.0,
      widthIncludingTrailingSpaces: fragment.widthIncludingTrailingSpaces,
    );
    return split;
  }

  LayoutFragment _swapTextDirection(LayoutFragment fragment, ui.TextDirection newDirection) {
    assert(fragment.textDirection != newDirection);
    return LayoutFragment(
      fragment.start,
      fragment.end,
      fragment.type,
      newDirection,
      fragment.span,
      trailingNewlines: fragment.trailingNewlines,
      trailingSpaces: fragment.trailingSpaces,
    )..setMetrics(
        spanometer,
        ascent: fragment.ascent,
        descent: fragment.descent,
        widthExcludingTrailingSpaces: fragment.widthExcludingTrailingSpaces,
        widthIncludingTrailingSpaces: fragment.widthIncludingTrailingSpaces,
      );
  }

  /// Creates a new [LineBuilder] to build the next line in the paragraph.
  LineBuilder nextLine() {
    return LineBuilder._(
      paragraph,
      spanometer,
      maxWidth: maxWidth,
      lineNumber: lineNumber + 1,
      accumulatedHeight: accumulatedHeight + height,
      fragments: _fragmentsForNextLine ?? <LayoutFragment>[],
    );
  }
}

/// Responsible for taking measurements within spans of a paragraph.
///
/// Can't perform measurements across spans. To measure across spans, multiple
/// measurements have to be taken.
///
/// Before performing any measurement, the [currentSpan] has to be set. Once
/// it's set, the [Spanometer] updates the underlying [context] so that
/// subsequent measurements use the correct styles.
class Spanometer {
  Spanometer(this.paragraph, this.context);

  final CanvasParagraph paragraph;
  final DomCanvasRenderingContext2D context;

  static final RulerHost _rulerHost = RulerHost();

  static final Map<TextHeightStyle, TextHeightRuler> _rulers =
      <TextHeightStyle, TextHeightRuler>{};

  @visibleForTesting
  static Map<TextHeightStyle, TextHeightRuler> get rulers => _rulers;

  /// Clears the cache of rulers that are used for measuring text height and
  /// baseline metrics.
  static void clearRulersCache() {
    _rulers.forEach((TextHeightStyle style, TextHeightRuler ruler) {
      ruler.dispose();
    });
    _rulers.clear();
  }

  String _cssFontString = '';

  double? get letterSpacing => currentSpan.style.letterSpacing;

  TextHeightRuler? _currentRuler;
  ParagraphSpan? _currentSpan;

  ParagraphSpan get currentSpan => _currentSpan!;
  set currentSpan(ParagraphSpan? span) {
    if (span == _currentSpan) {
      return;
    }
    _currentSpan = span;

    // No need to update css font string when `span` is null.
    if (span == null) {
      _currentRuler = null;
      return;
    }

    // Update the height ruler.
    // If the ruler doesn't exist in the cache, create a new one and cache it.
    final TextHeightStyle heightStyle = span.style.heightStyle;
    TextHeightRuler? ruler = _rulers[heightStyle];
    if (ruler == null) {
      ruler = TextHeightRuler(heightStyle, _rulerHost);
      _rulers[heightStyle] = ruler;
    }
    _currentRuler = ruler;

    // Update the font string if it's different from the previous span.
    final String cssFontString = span.style.cssFontString;
    if (_cssFontString != cssFontString) {
      _cssFontString = cssFontString;
      context.font = cssFontString;
    }
  }

  /// Whether the spanometer is ready to take measurements.
  bool get isReady => _currentSpan != null;

  /// The distance from the top of the current span to the alphabetic baseline.
  double get ascent => _currentRuler!.alphabeticBaseline;

  /// The distance from the bottom of the current span to the alphabetic baseline.
  double get descent => height - ascent;

  /// The line height of the current span.
  double get height => _currentRuler!.height;

  double measureText(String text) {
    return measureSubstring(context, text, 0, text.length);
  }

  double measureRange(int start, int end) {
    assert(_currentSpan != null);

    // Make sure the range is within the current span.
    assert(start >= currentSpan.start && start <= currentSpan.end);
    assert(end >= currentSpan.start && end <= currentSpan.end);

    return _measure(start, end);
  }

  void measureFragment(LayoutFragment fragment) {
    if (fragment.isPlaceholder) {
      final PlaceholderSpan placeholder = fragment.span as PlaceholderSpan;
      // The ascent/descent values of the placeholder fragment will be finalized
      // later when the line is built.
      fragment.setMetrics(this,
        ascent: placeholder.height,
        descent: 0,
        widthExcludingTrailingSpaces: placeholder.width,
        widthIncludingTrailingSpaces: placeholder.width,
      );
    } else {
      currentSpan = fragment.span as FlatTextSpan;
      final double widthExcludingTrailingSpaces = _measure(fragment.start, fragment.end - fragment.trailingSpaces);
      final double widthIncludingTrailingSpaces = _measure(fragment.start, fragment.end - fragment.trailingNewlines);
      fragment.setMetrics(this,
        ascent: ascent,
        descent: descent,
        widthExcludingTrailingSpaces: widthExcludingTrailingSpaces,
        widthIncludingTrailingSpaces: widthIncludingTrailingSpaces,
      );
    }
  }

  /// In a continuous, unbreakable block of text from [start] to [end], finds
  /// the point where text should be broken to fit in the given [availableWidth].
  ///
  /// The [start] and [end] indices have to be within the same text span.
  ///
  /// When [allowEmpty] is true, the result is guaranteed to be at least one
  /// character after [start]. But if [allowEmpty] is false and there isn't
  /// enough [availableWidth] to fit the first character, then [start] is
  /// returned.
  ///
  /// See also:
  /// - [LineBuilder.forceBreak].
  int forceBreak(
    int start,
    int end, {
    required double availableWidth,
    required bool allowEmpty,
  }) {
    assert(_currentSpan != null);

    final FlatTextSpan span = currentSpan as FlatTextSpan;

    // Make sure the range is within the current span.
    assert(start >= span.start && start <= span.end);
    assert(end >= span.start && end <= span.end);

    if (availableWidth <= 0.0) {
      return allowEmpty ? start : start + 1;
    }

    int low = start;
    int high = end;
    do {
      final int mid = (low + high) ~/ 2;
      final double width = _measure(start, mid);
      if (width < availableWidth) {
        low = mid;
      } else if (width > availableWidth) {
        high = mid;
      } else {
        low = high = mid;
      }
    } while (high - low > 1);

    if (low == start && !allowEmpty) {
      low++;
    }
    return low;
  }

  double _measure(int start, int end) {
    assert(_currentSpan != null);
    final FlatTextSpan span = currentSpan as FlatTextSpan;

    // Make sure the range is within the current span.
    assert(start >= span.start && start <= span.end);
    assert(end >= span.start && end <= span.end);

    final String text = paragraph.toPlainText();
    return measureSubstring(
      context,
      text,
      start,
      end,
      letterSpacing: letterSpacing,
    );
  }
}
