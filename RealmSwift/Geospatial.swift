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

import CoreLocation
import Realm

//public typealias GeoBox = RLMGeospatialBox

// Cannot be used within a Realm model, is only to be used to construct a GeoShape.
public struct GeoPoint: Equatable {
    private(set) var latitude: Double
    private(set) var longitude: Double

    public init?(_ latitude: Double, _ longitude: Double) {
        guard (-90...90).contains(latitude),
           (-180...180).contains(longitude) else {
            return nil
        }
        self.latitude = latitude
        self.longitude = longitude
    }
    
    public init(location: CLLocation) { fatalError() }
}

// A protocol to conform to guarantee type safety on the Swift Type Safe Query API.
public protocol GeoShape: RLMSwiftGeospatial {}

// Cannot be used within a Realm model, only to be used within Query.
public class GeoBox: GeoShape, Equatable {
    public static func == (lhs: GeoBox, rhs: GeoBox) -> Bool {
        return lhs.bottomLeft == rhs.bottomLeft && lhs.topRight == rhs.topRight
    }
    
    public func _convertedValue() -> RLMGeospatial {
        return RLMGeospatialBox(bottomLeft: RLMGeospatialPoint(latitude: bottomLeft.latitude, longitude: bottomLeft.longitude), topRight: RLMGeospatialPoint(latitude: topRight.latitude, longitude: topRight.longitude))
    }
    
    private(set) var bottomLeft: GeoPoint
    private(set) var topRight: GeoPoint

    public convenience init?(bottom: Double, left: Double, top: Double, right: Double) {
        guard (-90...90).contains(bottom), (-90...90).contains(top),
           (-180...180).contains(left) , (-180...180).contains(right) else {
            return nil
        }
        self.init(bottomLeft: GeoPoint(bottom, left)!, topRight: GeoPoint(top, right)!)
    }

    public init?(bottomLeft: GeoPoint, topRight: GeoPoint) {
        guard (-90...90).contains(bottomLeft.latitude), (-90...90).contains(bottomLeft.longitude),
           (-180...180).contains(topRight.latitude) , (-180...180).contains(topRight.latitude) else {
            return nil
        }
        self.bottomLeft = bottomLeft
        self.topRight = topRight
    }
}

// Cannot be used within a Realm model, only to be used within Query.
public class GeoPolygon: GeoShape {
    public func _convertedValue() -> RLMGeospatial {
        return RLMGeospatialPolygon(outerRing: outerRing.map { RLMGeospatialPoint(latitude: $0.latitude, longitude: $0.longitude) }, holes: holes?.map { $0.map { RLMGeospatialPoint(latitude: $0.latitude, longitude: $0.longitude) }} ?? nil)
    }

    private(set) var outerRing: [GeoPoint]
    private(set) var holes: [[GeoPoint]]?

    public init?(outerRing: [GeoPoint], holes: [[GeoPoint]]? = nil) {
        guard outerRing.count > 3, outerRing.first == outerRing.last else { return nil }
        if let holes = holes {
            for hole in holes {
                guard hole.count > 3, hole.first == hole.last else {
                    return nil
                }
            }
        }
        self.outerRing = outerRing
        self.holes = holes
    }
    public convenience init?(outerRing: GeoPoint..., holes: [GeoPoint]...) {
        self.init(outerRing: outerRing, holes: holes)
    }
}

// Cannot be used within a Realm model, only to be used to build a GeoSphere.
public struct Distance {
    private static let EarthRadiusMeters = 6378100.0;
    public private(set) var radians: Double

    public static func fromKilometers(_ kilometers: Double) -> Distance? {
        guard kilometers >= 0 else { return nil }
        return Distance(radians: (kilometers * 1000) / EarthRadiusMeters)
    }
    // American miles, i.e. 1.609344 km pr. mile
    public static func fromMiles(_ miles: Double) -> Distance? {
        guard miles >= 0 else { return nil }
        return Distance(radians: (miles * 1609.344) / EarthRadiusMeters)
    }

    public static func fromRadians(_ radians: Double) -> Distance? {
        guard radians >= 0 else { return nil }
        return Distance(radians: radians)
    }

    public var asKilometers: Double {
        return (radians * Distance.EarthRadiusMeters) / 1000
    }
    public var asMiles: Double {
        return (radians * Distance.EarthRadiusMeters) / 1609.344
    }

    private init(radians: Double) {
        self.radians = radians
    }
}

// Cannot be used within a Realm model, only to be used within Query.
public class GeoCircle: GeoShape {
    public func _convertedValue() -> RLMGeospatial {
        return RLMGeospatialCircle(center: RLMGeospatialPoint(latitude: center.latitude, longitude: center.longitude), radians: radius)
    }

    private(set) var center: GeoPoint
    private(set) var radius: Double

    // Using radius in radians
    public init?(center: GeoPoint, radiusInRadians: Double) {
        guard radiusInRadians >= 0 else {
            return nil
        }
        self.center = center
        self.radius = radiusInRadians
    }
    // Using distance
    public init?(center: GeoPoint, radius: Distance) {
        let radiusInRadians = radius.radians
        guard radiusInRadians >= 0 else {
            return nil
        }
        self.center = center
        self.radius = radiusInRadians
    }
}
