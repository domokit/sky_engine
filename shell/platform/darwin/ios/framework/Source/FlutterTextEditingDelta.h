// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef SHELL_PLATFORM_IOS_FRAMEWORK_SOURCE_FLUTTERTEXTEDITINGDELTA_H_
#define SHELL_PLATFORM_IOS_FRAMEWORK_SOURCE_FLUTTERTEXTEDITINGDELTA_H_

#import <UIKit/UIKit.h>

@interface FlutterTextEditingDelta : NSObject <NSCopying>

@property(nonatomic, readonly) NSString* oldText;
@property(nonatomic, readonly) NSString* deltaText;
@property(nonatomic, readonly) NSString* deltaType;
@property(nonatomic, readonly) NSInteger deltaStart;
@property(nonatomic, readonly) NSInteger deltaEnd;

- (instancetype)initTextEditingDelta:(NSString*)textBeforeChange
                     textAfterChange:(NSString*)textAfterChange
                       replacedRange:(NSRange)range
                         updatedText:(NSString*)text;

- (instancetype)initWithEquality:(NSString*)text;

- (void)setDeltas:(NSString*)oldText
          newText:(NSString*)newTxt
             type:(NSString*)deltaType
       deltaStart:(NSInteger)newStart
         deltaEnd:(NSInteger)newEnd;

@end
#endif  // SHELL_PLATFORM_IOS_FRAMEWORK_SOURCE_FLUTTERTEXTEDITINGDELTA_H_
