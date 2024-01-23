// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../dom.dart';
import '../semantics.dart';

/// Provides accessibility for links.
class Link extends PrimaryRoleManager {
  Link(SemanticsObject semanticsObject) : super.withBasics(PrimaryRole.link, semanticsObject);

  @override
  DomElement createElement() {
    final DomElement element = domDocument.createElement('a');
    // TODO(chunhtai): Fill in the real link once the framework sends entire uri.
    // https://github.com/flutter/flutter/issues/102535.
    element.setAttribute('href', '#');
    element.style.display = 'block';
    // Prevent the default action of clicking the anchor tag, which is to
    // navigate to the href. Instead the click action is handled by the
    // framework.
    element.addEventListener('click', createDomEventListener((DomEvent event) {
      event.preventDefault();
    }));
    return element;
  }

  @override
  bool focusAsRouteDefault() => focusable?.focusAsRouteDefault() ?? false;
}
