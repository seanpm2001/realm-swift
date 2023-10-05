////////////////////////////////////////////////////////////////////////////
//
// Copyright 2023 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import <Realm/RLMConstants.h>

RLM_HEADER_AUDIT_BEGIN(nullability)

/// An enum representing different levels of sync-related logging that can be configured.
typedef RLM_CLOSED_ENUM(NSUInteger, RLMGeospatialType) {
    RLMGeospatialTypeBox,
    /// Only fatal errors will be logged.
    RLMGeospatialTypeCircle,
    /// Only errors will be logged.
    RLMLogLevelTypePolygon,
} NS_SWIFT_NAME(GeospatialType);

@interface RLMGeospatial : NSObject
@end

@protocol RLMSwiftGeospatial
- (RLMGeospatial *)_convertedValue;
@end

@interface RLMGeospatialPoint : NSObject
@property (readonly) double latitude;
@property (readonly) double longitude;

- (instancetype)initWithLatitude:(double)latitude longitude:(double)longitude;
@end

@interface RLMGeospatialBox : RLMGeospatial
@property (readonly, strong) RLMGeospatialPoint *bottomLeft;
@property (readonly, strong) RLMGeospatialPoint *topRight;

- (instancetype)initWithBottomLeft:(RLMGeospatialPoint *)bottomLeft topRight:(RLMGeospatialPoint *)topRight;
- (instancetype)initWithTop:(double)top left:(double)left bottom:(double)bottom right:(double)right;
@end

@interface RLMGeospatialPolygon : RLMGeospatial
@property (readonly, strong) NSArray<RLMGeospatialPoint *> *outerRing;
@property (readonly, strong, nullable) NSArray<NSArray<RLMGeospatialPoint *> *> *holes;

- (instancetype)initWithOuterRing:(NSArray<RLMGeospatialPoint *> *)outerRing holes:(nullable NSArray<NSArray<RLMGeospatialPoint *> *> *)holes;
@end

@interface RLMGeospatialCircle : RLMGeospatial
@property (readonly, strong) RLMGeospatialPoint *center;
@property (readonly) double radians;

- (instancetype)initWithCenter:(RLMGeospatialPoint *)center radians:(double)radians;
@end

RLM_HEADER_AUDIT_END(nullability)
