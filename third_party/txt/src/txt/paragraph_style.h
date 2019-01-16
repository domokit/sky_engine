/*
 * Copyright 2017 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef LIB_TXT_SRC_PARAGRAPH_STYLE_H_
#define LIB_TXT_SRC_PARAGRAPH_STYLE_H_

#include <climits>
#include <string>

#include "font_style.h"
#include "font_weight.h"
#include "minikin/LineBreaker.h"
#include "text_style.h"

namespace txt {

enum class TextAlign {
  left,
  right,
  center,
  justify,
  start,
  end,
};

enum class TextDirection {
  rtl,
  ltr,
};

class ParagraphStyle {
 public:
  // Default TextStyle. Used in GetTextStyle() to obtain the base TextStyle to
  // inherit off of.
  FontWeight font_weight = FontWeight::w400;
  FontStyle font_style = FontStyle::normal;
  std::string font_family = "";
  double font_size = 14;
  double line_height = 1;

  // Strut properties. strut_enabled must be set to true for the rest of the
  // properties to take effect.
  // TODO(garyq): Break the strut properties into a separate class.
  bool strut_enabled = false;
  FontWeight strut_font_weight = FontWeight::w400;
  FontStyle strut_font_style = FontStyle::normal;
  std::vector<std::string> strut_font_families;
  double strut_font_size = 14;
  double strut_line_height = 1;
  double strut_leading = -1;  // Negative to use font leading. [0,inf) to use
                              // custom leading as a ratio of font size.
  bool force_strut_height = false;

  // General paragraph properties.
  TextAlign text_align = TextAlign::start;
  TextDirection text_direction = TextDirection::ltr;
  size_t max_lines = std::numeric_limits<size_t>::max();
  std::u16string ellipsis;
  std::string locale;

  // Default strategy is kBreakStrategy_Greedy. Sometimes,
  // kBreakStrategy_HighQuality will produce more desireable layouts (eg, very
  // long words are more likely to be reasonably placed).
  // kBreakStrategy_Balanced will balance between the two.
  minikin::BreakStrategy break_strategy =
      minikin::BreakStrategy::kBreakStrategy_Greedy;

  TextStyle GetTextStyle() const;

  bool unlimited_lines() const;
  bool ellipsized() const;

  // Return a text alignment value that is not dependent on the text direction.
  TextAlign effective_align() const;
};

}  // namespace txt

#endif  // LIB_TXT_SRC_PARAGRAPH_STYLE_H_
