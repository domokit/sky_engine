// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
// @dart = 2.6
part of engine;

class SkParagraphStyle implements ui.ParagraphStyle {
  SkParagraphStyle({
    ui.TextAlign textAlign,
    ui.TextDirection textDirection,
    int maxLines,
    String fontFamily,
    double fontSize,
    double height,
    ui.TextHeightBehavior textHeightBehavior,
    ui.FontWeight fontWeight,
    ui.FontStyle fontStyle,
    ui.StrutStyle strutStyle,
    String ellipsis,
    ui.Locale locale,
  }) {
    skParagraphStyle = toSkParagraphStyle(
      textAlign,
      textDirection,
      maxLines,
      fontFamily,
      fontSize,
      height,
      textHeightBehavior,
      fontWeight,
      fontStyle,
      ellipsis,
    );
    assert(skParagraphStyle != null);
    _textDirection = textDirection ?? ui.TextDirection.ltr;
    _fontFamily = fontFamily;
  }

  js.JsObject skParagraphStyle;
  ui.TextDirection _textDirection;
  String _fontFamily;

  static Map<String, dynamic> toSkTextStyle(
    String fontFamily,
    double fontSize,
    ui.FontWeight fontWeight,
    ui.FontStyle fontStyle,
  ) {
    final Map<String, dynamic> skTextStyle = <String, dynamic>{};
    if (fontWeight != null || fontStyle != null) {
      skTextStyle['fontStyle'] = toSkFontStyle(fontWeight, fontStyle);
    }

    if (fontSize != null) {
      skTextStyle['fontSize'] = fontSize;
    }

    if (fontFamily == null ||
        !skiaFontCollection.registeredFamilies.contains(fontFamily)) {
      fontFamily = 'Roboto';
    }
    if (skiaFontCollection.fontFamilyOverrides.containsKey(fontFamily)) {
      fontFamily = skiaFontCollection.fontFamilyOverrides[fontFamily];
    }
    skTextStyle['fontFamilies'] = [fontFamily];

    return skTextStyle;
  }

  static js.JsObject toSkParagraphStyle(
    ui.TextAlign textAlign,
    ui.TextDirection textDirection,
    int maxLines,
    String fontFamily,
    double fontSize,
    double height,
    ui.TextHeightBehavior textHeightBehavior,
    ui.FontWeight fontWeight,
    ui.FontStyle fontStyle,
    String ellipsis,
  ) {
    final Map<String, dynamic> skParagraphStyle = <String, dynamic>{};

    if (textAlign != null) {
      switch (textAlign) {
        case ui.TextAlign.left:
          skParagraphStyle['textAlign'] = canvasKit['TextAlign']['Left'];
          break;
        case ui.TextAlign.right:
          skParagraphStyle['textAlign'] = canvasKit['TextAlign']['Right'];
          break;
        case ui.TextAlign.center:
          skParagraphStyle['textAlign'] = canvasKit['TextAlign']['Center'];
          break;
        case ui.TextAlign.justify:
          skParagraphStyle['textAlign'] = canvasKit['TextAlign']['Justify'];
          break;
        case ui.TextAlign.start:
          skParagraphStyle['textAlign'] = canvasKit['TextAlign']['Start'];
          break;
        case ui.TextAlign.end:
          skParagraphStyle['textAlign'] = canvasKit['TextAlign']['End'];
          break;
      }
    }

    if (textDirection != null) {
      switch (textDirection) {
        case ui.TextDirection.ltr:
          skParagraphStyle['textDirection'] = canvasKit['TextDirection']['LTR'];
          break;
        case ui.TextDirection.rtl:
          skParagraphStyle['textDirection'] = canvasKit['TextDirection']['RTL'];
          break;
      }
    }

    if (height != null) {
      skParagraphStyle['heightMultiplier'] = height;
    }

    if (textHeightBehavior != null) {
      skParagraphStyle['textHeightBehavior'] = textHeightBehavior.encode();
    }

    if (maxLines != null) {
      skParagraphStyle['maxLines'] = maxLines;
    }

    if (ellipsis != null) {
      skParagraphStyle['ellipsis'] = ellipsis;
    }

    skParagraphStyle['textStyle'] =
        toSkTextStyle(fontFamily, fontSize, fontWeight, fontStyle);

    return canvasKit.callMethod(
        'ParagraphStyle', <js.JsObject>[js.JsObject.jsify(skParagraphStyle)]);
  }
}

class SkTextStyle implements ui.TextStyle {
  js.JsObject skTextStyle;

  SkTextStyle({
    ui.Color color,
    ui.TextDecoration decoration,
    ui.Color decorationColor,
    ui.TextDecorationStyle decorationStyle,
    double decorationThickness,
    ui.FontWeight fontWeight,
    ui.FontStyle fontStyle,
    ui.TextBaseline textBaseline,
    String fontFamily,
    List<String> fontFamilyFallback,
    double fontSize,
    double letterSpacing,
    double wordSpacing,
    double height,
    ui.Locale locale,
    SkPaint background,
    SkPaint foreground,
    List<ui.Shadow> shadows,
    List<ui.FontFeature> fontFeatures,
  }) {
    final js.JsObject style = js.JsObject(js.context['Object']);

    if (background != null) {
      style['backgroundColor'] = makeFreshSkColor(background.color);
    }

    if (color != null) {
      style['color'] = makeFreshSkColor(color);
    }

    if (decoration != null) {
      int decorationValue = canvasKit['NoDecoration'];
      if (decoration.contains(ui.TextDecoration.underline)) {
        decorationValue |= canvasKit['UnderlineDecoration'];
      }
      if (decoration.contains(ui.TextDecoration.overline)) {
        decorationValue |= canvasKit['OverlineDecoration'];
      }
      if (decoration.contains(ui.TextDecoration.lineThrough)) {
        decorationValue |= canvasKit['LineThroughDecoration'];
      }
      style['decoration'] = decorationValue;
    }

    if (decorationThickness != null) {
      style['decorationThickness'] = decorationThickness;
    }

    if (fontSize != null) {
      style['fontSize'] = fontSize;
    }

    if (fontFamily == null ||
        !skiaFontCollection.registeredFamilies.contains(fontFamily)) {
      fontFamily = 'Roboto';
    }

    if (skiaFontCollection.fontFamilyOverrides.containsKey(fontFamily)) {
      fontFamily = skiaFontCollection.fontFamilyOverrides[fontFamily];
    }
    List<String> fontFamilies = <String>[fontFamily];
    if (fontFamilyFallback != null &&
        !fontFamilyFallback.every((font) => fontFamily == font)) {
      fontFamilies.addAll(fontFamilyFallback);
    }

    style['fontFamilies'] = js.JsArray.from(fontFamilies);

    if (fontWeight != null || fontStyle != null) {
      style['fontStyle'] = toSkFontStyle(fontWeight, fontStyle);
    }

    if (foreground != null) {
      style['foregroundColor'] = makeFreshSkColor(foreground.color);
    }

    // TODO(hterkelsen): Add support for
    //   - decorationColor
    //   - decorationStyle
    //   - textBaseline
    //   - letterSpacing
    //   - wordSpacing
    //   - height
    //   - locale
    //   - shadows
    //   - fontFeatures
    skTextStyle = canvasKit.callMethod('TextStyle', <js.JsObject>[style]);
    assert(skTextStyle != null);
  }
}

Map<String, js.JsObject> toSkFontStyle(
    ui.FontWeight fontWeight, ui.FontStyle fontStyle) {
  Map<String, js.JsObject> style = <String, js.JsObject>{};
  if (fontWeight != null) {
    switch (fontWeight) {
      case ui.FontWeight.w100:
        style['weight'] = canvasKit['FontWeight']['Thin'];
        break;
      case ui.FontWeight.w200:
        style['weight'] = canvasKit['FontWeight']['ExtraLight'];
        break;
      case ui.FontWeight.w300:
        style['weight'] = canvasKit['FontWeight']['Light'];
        break;
      case ui.FontWeight.w400:
        style['weight'] = canvasKit['FontWeight']['Normal'];
        break;
      case ui.FontWeight.w500:
        style['weight'] = canvasKit['FontWeight']['Medium'];
        break;
      case ui.FontWeight.w600:
        style['weight'] = canvasKit['FontWeight']['SemiBold'];
        break;
      case ui.FontWeight.w700:
        style['weight'] = canvasKit['FontWeight']['Bold'];
        break;
      case ui.FontWeight.w800:
        style['weight'] = canvasKit['FontWeight']['ExtraBold'];
        break;
      case ui.FontWeight.w900:
        style['weight'] = canvasKit['FontWeight']['ExtraBlack'];
        break;
    }
  }

  if (fontStyle != null) {
    switch (fontStyle) {
      case ui.FontStyle.normal:
        style['slant'] = canvasKit['FontSlant']['Upright'];
        break;
      case ui.FontStyle.italic:
        style['slant'] = canvasKit['FontSlant']['Italic'];
        break;
    }
  }
  return style;
}

class SkParagraph extends SkiaObject implements ui.Paragraph {
  final ParagraphBuildBuffer buildBuffer;
  SkParagraph(
    this.buildBuffer,
  )   : this._textDirection = buildBuffer.textDirection,
        this._fontFamily = buildBuffer.fontFamily;

  @override
  js.JsObject createDefault() => buildBuffer.makeParagraph();

  @override
  js.JsObject resurrect() => buildBuffer.makeParagraph();

  final ui.TextDirection _textDirection;
  final String _fontFamily;

  @override
  double get alphabeticBaseline =>
      skiaObject.callMethod('getAlphabeticBaseline');

  @override
  bool get didExceedMaxLines => skiaObject.callMethod('didExceedMaxLines');

  @override
  double get height => skiaObject.callMethod('getHeight');

  @override
  double get ideographicBaseline =>
      skiaObject.callMethod('getIdeographicBaseline');

  @override
  double get longestLine => skiaObject.callMethod('getLongestLine');

  @override
  double get maxIntrinsicWidth => skiaObject.callMethod('getMaxIntrinsicWidth');

  @override
  double get minIntrinsicWidth => skiaObject.callMethod('getMinIntrinsicWidth');

  @override
  double get width => skiaObject.callMethod('getMaxWidth');

  // TODO(hterkelsen): Implement placeholders once it's in CanvasKit
  @override
  List<ui.TextBox> getBoxesForPlaceholders() {
    return const <ui.TextBox>[];
  }

  @override
  List<ui.TextBox> getBoxesForRange(
    int start,
    int end, {
    ui.BoxHeightStyle boxHeightStyle: ui.BoxHeightStyle.tight,
    ui.BoxWidthStyle boxWidthStyle: ui.BoxWidthStyle.tight,
  }) {
    if (start < 0 || end < 0) {
      return const <ui.TextBox>[];
    }

    js.JsObject heightStyle;
    switch (boxHeightStyle) {
      case ui.BoxHeightStyle.tight:
        heightStyle = canvasKit['RectHeightStyle']['Tight'];
        break;
      case ui.BoxHeightStyle.max:
        heightStyle = canvasKit['RectHeightStyle']['Max'];
        break;
      default:
        // TODO(hterkelsen): Support all height styles
        html.window.console.warn(
            'We do not support $boxHeightStyle. Defaulting to BoxHeightStyle.tight');
        heightStyle = canvasKit['RectHeightStyle']['Tight'];
        break;
    }

    js.JsObject widthStyle;
    switch (boxWidthStyle) {
      case ui.BoxWidthStyle.tight:
        widthStyle = canvasKit['RectWidthStyle']['Tight'];
        break;
      case ui.BoxWidthStyle.max:
        widthStyle = canvasKit['RectWidthStyle']['Max'];
        break;
    }

    List<js.JsObject> skRects =
        skiaObject.callMethod('getRectsForRange', <dynamic>[
      start,
      end,
      heightStyle,
      widthStyle,
    ]);

    List<ui.TextBox> result = List<ui.TextBox>(skRects.length);

    for (int i = 0; i < skRects.length; i++) {
      final js.JsObject rect = skRects[i];
      result[i] = ui.TextBox.fromLTRBD(
        rect['fLeft'],
        rect['fTop'],
        rect['fRight'],
        rect['fBottom'],
        _textDirection,
      );
    }

    return result;
  }

  @override
  ui.TextPosition getPositionForOffset(ui.Offset offset) {
    js.JsObject positionWithAffinity =
        skiaObject.callMethod('getGlyphPositionAtCoordinate', <double>[
      offset.dx,
      offset.dy,
    ]);
    return fromPositionWithAffinity(positionWithAffinity);
  }

  @override
  ui.TextRange getWordBoundary(ui.TextPosition position) {
    js.JsObject skRange =
        skiaObject.callMethod('getWordBoundary', <int>[position.offset]);
    return ui.TextRange(start: skRange['start'], end: skRange['end']);
  }

  @override
  void layout(ui.ParagraphConstraints constraints) {
    assert(constraints.width != null);

    // Infinite width breaks layout, just use a very large number instead.
    // TODO(het): Remove this once https://bugs.chromium.org/p/skia/issues/detail?id=9874
    //            is fixed.
    double width;
    const double largeFiniteWidth = 1000000;
    if (constraints.width.isInfinite) {
      width = largeFiniteWidth;
    } else {
      width = constraints.width;
    }
    // TODO(het): CanvasKit throws an exception when laid out with
    // a font that wasn't registered.
    try {
      skiaObject.callMethod('layout', <double>[width]);
    } catch (e) {
      html.window.console.warn('CanvasKit threw an exception while laying '
          'out the paragraph. The font was "$_fontFamily". Exception:\n$e');
      rethrow;
    }
  }

  @override
  ui.TextRange getLineBoundary(ui.TextPosition position) {
    // TODO(hterkelsen): Implement this when it's added to CanvasKit
    throw UnimplementedError('getLineBoundary');
  }

  @override
  List<ui.LineMetrics> computeLineMetrics() {
    // TODO(hterkelsen): Implement this when it's added to CanvasKit
    throw UnimplementedError('computeLineMetrics');
  }
}

enum ParagraphBuildCommand {
  pop,
  text,
  push,
}

class ParagraphBuildCommandData {
  final ParagraphBuildCommand command;
  final String text;
  final ui.TextStyle style;

  ParagraphBuildCommandData(this.command, {this.text, this.style});
}

class ParagraphBuildBuffer {
  final ui.ParagraphStyle style;
  final List<ParagraphBuildCommandData> commands = [];
  ParagraphBuildBuffer(this.style);

  ui.TextDirection get textDirection =>
      (style as SkParagraphStyle)._textDirection;
  String get fontFamily => (style as SkParagraphStyle)._fontFamily;

  js.JsObject makeParagraph() {
    SkParagraphStyle skStyle = style;
    js.JsObject builder = canvasKit['ParagraphBuilder'].callMethod(
      'Make',
      <js.JsObject>[
        skStyle.skParagraphStyle,
        skiaFontCollection.skFontMgr,
      ],
    );
    for (final command in commands) {
      switch (command.command) {
        case ParagraphBuildCommand.text:
          builder.callMethod('addText', <String>[command.text]);
          break;
        case ParagraphBuildCommand.pop:
          builder.callMethod('pop');
          break;
        case ParagraphBuildCommand.push:
          final SkTextStyle skStyle = command.style;
          builder.callMethod('pushStyle', <js.JsObject>[skStyle.skTextStyle]);
          break;
      }
    }

    js.JsObject paragraph = builder.callMethod('build');
    builder.callMethod('delete');
    return paragraph;
  }
}

class SkParagraphBuilder implements ui.ParagraphBuilder {
  final ParagraphBuildBuffer _buildBuffer;

  SkParagraphBuilder(ui.ParagraphStyle style)
      : _buildBuffer = ParagraphBuildBuffer(style) {}

  // TODO(hterkelsen): Implement placeholders.
  @override
  void addPlaceholder(
    double width,
    double height,
    ui.PlaceholderAlignment alignment, {
    double scale = 1.0,
    double baselineOffset,
    ui.TextBaseline baseline,
  }) {
    throw UnimplementedError('addPlaceholder');
  }

  @override
  void addText(String text) {
    _buildBuffer.commands
        .add(ParagraphBuildCommandData(ParagraphBuildCommand.text, text: text));
  }

  @override
  ui.Paragraph build() {
    return SkParagraph(_buildBuffer);
  }

  @override
  int get placeholderCount => throw UnimplementedError('placeholderCount');

  // TODO(hterkelsen): Implement this once CanvasKit exposes placeholders.
  @override
  List<double> get placeholderScales => const <double>[];

  @override
  void pop() {
    _buildBuffer.commands
        .add(ParagraphBuildCommandData(ParagraphBuildCommand.pop));
  }

  @override
  void pushStyle(ui.TextStyle style) {
    _buildBuffer.commands.add(
        ParagraphBuildCommandData(ParagraphBuildCommand.push, style: style));
  }
}
