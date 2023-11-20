// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

class NotoFont {
  NotoFont(this.name, this.url, {this.enabled = true});

  final String name;
  final String url;

  /// `true` if this font is to be considered as a fallback font. Almost all
  /// fonts are enabled, but [enabled] may be `false` to exclude a font. This is
  /// used to choose between color and monochrome emoji fonts - only one of them
  /// is enabled.
  final bool enabled;

  final int index = _index++;
  static int _index = 0;

  /// During fallback font selection this is the number of missing code points
  /// that are covered by (i.e. in) this font.
  int coverCount = 0;

  /// During fallback font selection this is a list of [FallbackFontComponent]s
  /// from this font that are required to cover some of the missing code
  /// points. The cover count for the font is the sum of the cover counts for
  /// the components that make up the font.
  final List<FallbackFontComponent> coverComponents = <FallbackFontComponent>[];
}

/// A component is a set of code points common to some fonts. Each code point is
/// in a single component. Each font can be represented as a disjoint union of
/// components. We store the inverse of this relationship, the fonts that use
/// this component. The font fallback selection algorithm does not need the code
/// points in a component or a font, so this is not stored, but can be recovered
/// via the map from code-point to component.
class FallbackFontComponent {
  FallbackFontComponent(this._allFonts);
  final List<NotoFont> _allFonts;
  late final List<NotoFont> _activeFonts = List<NotoFont>.unmodifiable(
      _allFonts.where((NotoFont font) => font.enabled));

  List<NotoFont> get fonts => _activeFonts;

  /// During fallback font selection this is the number of missing code points
  /// that are covered by this component.
  int coverCount = 0;
}
