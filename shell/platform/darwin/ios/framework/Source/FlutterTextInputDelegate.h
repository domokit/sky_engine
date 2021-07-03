// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef SHELL_PLATFORM_IOS_FRAMEWORK_SOURCE_FLUTTERTEXTINPUTDELEGATE_H_
#define SHELL_PLATFORM_IOS_FRAMEWORK_SOURCE_FLUTTERTEXTINPUTDELEGATE_H_

#import <Foundation/Foundation.h>

@class FlutterTextInputPlugin;
@class FlutterTextInputView;

typedef NS_ENUM(NSInteger, FlutterTextInputAction) {
  FlutterTextInputActionUnspecified,
  FlutterTextInputActionDone,
  FlutterTextInputActionGo,
  FlutterTextInputActionSend,
  FlutterTextInputActionSearch,
  FlutterTextInputActionNext,
  FlutterTextInputActionContinue,
  FlutterTextInputActionJoin,
  FlutterTextInputActionRoute,
  FlutterTextInputActionEmergencyCall,
  FlutterTextInputActionNewline,
};

typedef NS_ENUM(NSInteger, FlutterFloatingCursorDragState) {
  FlutterFloatingCursorDragStateStart,
  FlutterFloatingCursorDragStateUpdate,
  FlutterFloatingCursorDragStateEnd,
};

@protocol FlutterTextInputDelegate <NSObject>
- (void)flutterTextInputView:(FlutterTextInputView*)textInputView
         updateEditingClient:(int)client
                   withState:(NSDictionary*)state;
- (void)flutterTextInputView:(FlutterTextInputView*)textInputView
         updateEditingClient:(int)client
                   withState:(NSDictionary*)state
                     withTag:(NSString*)tag;
- (void)flutterTextInputView:(FlutterTextInputView*)textInputView
               performAction:(FlutterTextInputAction)action
                  withClient:(int)client;
- (void)flutterTextInputView:(FlutterTextInputView*)textInputView
        updateFloatingCursor:(FlutterFloatingCursorDragState)state
                  withClient:(int)client
                withPosition:(NSDictionary*)point;
- (void)flutterTextInputView:(FlutterTextInputView*)textInputView
    showAutocorrectionPromptRectForStart:(NSUInteger)start
                                     end:(NSUInteger)end
                              withClient:(int)client;
- (void)flutterTextInputView:(FlutterTextInputView*)textInputView showToolbar:(int)client;
- (void)flutterTextInputViewScribbleInteractionBegan:(FlutterTextInputView*)textInputView;
- (void)flutterTextInputViewScribbleInteractionFinished:(FlutterTextInputView*)textInputView;
- (void)flutterTextInputView:(FlutterTextInputView*)textInputView
    insertTextPlaceholderWithSize:(CGSize)size
                       withClient:(int)client;
- (void)flutterTextInputView:(FlutterTextInputView*)textInputView removeTextPlaceholder:(int)client;

// TODO(gaaclarke) Refactor these into their own delegate.
- (void)flutterTextInputPlugin:(FlutterTextInputPlugin*)textInputPlugin
                  focusElement:(UIScribbleElementIdentifier)elementIdentifier
                       atPoint:(CGPoint)referencePoint
                        result:(FlutterResult)callback;
- (void)flutterTextInputPlugin:(FlutterTextInputPlugin*)textInputPlugin
         requestElementsInRect:(CGRect)rect
                        result:(FlutterResult)callback;
@end

#endif  // SHELL_PLATFORM_IOS_FRAMEWORK_SOURCE_FLUTTERTEXTINPUTDELEGATE_H_
