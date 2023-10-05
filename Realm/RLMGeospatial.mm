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

#import "RLMGeospatial.h"

#import <realm/geospatial.hpp>

@implementation RLMGeospatial
- (realm::Geospatial)geoSpatial {
    return realm::Geospatial{realm::GeoBox{realm::GeoPoint{1.1, 2.2}, realm::GeoPoint{1.1, 2,2}}};
}
@end

@implementation RLMGeospatialPoint
- (instancetype)initWithLatitude:(double)latitude longitude:(double)longitude {
    if (self = [super init]) {
        _latitude = latitude;
        _longitude = longitude;
    }
    return self;
}

- (realm::GeoPoint)value {
    return realm::GeoPoint{_longitude, _latitude};
}
@end

@implementation RLMGeospatialBox
- (instancetype)initWithBottomLeft:(RLMGeospatialPoint *)bottomLeft topRight:(RLMGeospatialPoint *)topRight {
    if (self = [super init]) {
        _bottomLeft = bottomLeft;
        _topRight = topRight;
    }
    return self;
}

- (instancetype)initWithTop:(double)top left:(double)left bottom:(double)bottom right:(double)right {
    if (self = [super init]) {
        _bottomLeft = [[RLMGeospatialPoint alloc] initWithLatitude:bottom longitude:left];
        _topRight = [[RLMGeospatialPoint alloc] initWithLatitude:top longitude:right];
    }
    return self;
}

- (realm::Geospatial)geoSpatial {
    realm::GeoBox geo_box{realm::GeoPoint{_bottomLeft.longitude, _bottomLeft.latitude}, realm::GeoPoint{_topRight.longitude, _topRight.latitude}};
    return realm::Geospatial{geo_box};
}
@end

@implementation RLMGeospatialPolygon
- (instancetype)initWithOuterRing:(NSArray<RLMGeospatialPoint *> *)outerRing holes:(nullable NSArray<NSArray<RLMGeospatialPoint *> *> *)holes {
    if (self = [super init]) {
        _outerRing = outerRing;
        _holes = holes;
    }
    return self;
}

- (realm::Geospatial)geoSpatial {
    std::vector<std::vector<realm::GeoPoint>> points;
    std::vector<realm::GeoPoint> outer_ring;
    for (RLMGeospatialPoint *point : _outerRing) {
        outer_ring.push_back(point.value);
    }
    points.push_back(outer_ring);

    if (_holes) {
        std::vector<realm::GeoPoint> holes;
        for (NSArray<RLMGeospatialPoint *> *array_points : _holes) {
            for (RLMGeospatialPoint *point : array_points) {
                holes.push_back(point.value);
            }
        }
        points.push_back(holes);
    }

    realm::GeoPolygon geo_polygon{points};
    return realm::Geospatial{geo_polygon};
}
@end

@implementation RLMGeospatialCircle
- (instancetype)initWithCenter:(RLMGeospatialPoint *)center radians:(double)radians {
    if (self = [super init]) {
        _center = center;
        _radians = radians;
    }
    return self;
}

- (realm::Geospatial)geoSpatial {
    realm::GeoCircle geo_circle{_radians, _center.value};
    return realm::Geospatial{geo_circle};
}
@end
