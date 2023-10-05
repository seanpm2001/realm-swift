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

import XCTest
import RealmSwift

// Template `EmbeddedObject` for storing GeoPoints in Realm.
public class Location: EmbeddedObject {
    @Persisted private(set) var coordinates: List<Double>
    @Persisted public var type: String = "Point" // public for testing

    public var latitude: Double { return coordinates[1] }
    public var longitude: Double { return coordinates[0] }

    convenience init(latitude: Double, longitude: Double) {
        self.init()
        coordinates.append(objectsIn: [longitude, latitude])
    }
}

public class PersonWithInvalidTypes: Object {
    @Persisted public var geoPointCoordinatesEmbedded: CoordinatesGeoPointEmbedded?
    @Persisted public var geoPointTypeEmbedded: TypeGeoPointEmbedded?
    @Persisted public var geoPoint: TopLevelGeoPoint?
}

public class CoordinatesGeoPointEmbedded: EmbeddedObject {
    @Persisted public var coordinates: List<Double>
}

public class TypeGeoPointEmbedded: EmbeddedObject {
    @Persisted public var type: String = "Point" // public for testing
}

public class TopLevelGeoPoint: Object {
    @Persisted public var coordinates: List<Double>
    @Persisted public var type: String = "Point" // public for testing
}

class PersonLocation: Object {
    @Persisted var name: String
    @Persisted var location: Location?

    convenience init(name: String, location: Location?) {
        self.init()
        self.name = name
        self.location = location
    }
}

class GeospatialTests: TestCase {
    func populatePersonLocationTable() throws {
        let realm = realmWithTestPath()
        try realm.write {
            realm.add(PersonLocation(name: "Diana", location: Location(latitude: 40.7128, longitude: -74.0060)))

            realm.add(PersonLocation(name: "Maria", location: Location(latitude: 55.6761, longitude: 12.5683)))

            realm.add(PersonLocation(name: "Tomas", location: Location(latitude: 55.6280, longitude: 12.0826)))

            realm.add(PersonLocation(name: "Manuela", location: nil))
        }
    }

    func testFilterShapes() throws {
        try populatePersonLocationTable()

        assertFilterShape(GeoBox(bottomLeft: GeoPoint(55.6281, 12.0826)!, topRight: GeoPoint(55.6762, 12.5684)!)!, count: 1, expectedMatches: ["Maria"])
        assertFilterShape(GeoBox(bottom: 55.6279, left: 12.0825, top: 55.6762, right: 12.5684)!, count: 2, expectedMatches: ["Maria", "Tomas"])
        assertFilterShape(GeoBox(bottomLeft: GeoPoint(0, -75)!, topRight: GeoPoint(60, 15)!)!, count: 3, expectedMatches: ["Diana", "Maria", "Tomas"])

        assertFilterShape(GeoPolygon(outerRing: [GeoPoint(55.6281, 12.0826)!, GeoPoint(55.6761, 12.0826)!, GeoPoint(55.6761, 12.5684)!, GeoPoint(55.6281, 12.5684)!, GeoPoint(55.6281, 12.0826)!])!, count: 1, expectedMatches: ["Maria"])
        assertFilterShape(GeoPolygon(outerRing: [GeoPoint(55, 12)!, GeoPoint(55.67, 12.5)!, GeoPoint(55.67, 11.5)!, GeoPoint(55, 12)!])!, count: 1, expectedMatches: ["Tomas"])
        assertFilterShape(GeoPolygon(outerRing: [GeoPoint(40.0096192, -75.5175781)!, GeoPoint(60, 20)!, GeoPoint(20, 20)!, GeoPoint(-75.5175781, -75.5175781)!, GeoPoint(40.0096192, -75.5175781)!])!, count: 3, expectedMatches: ["Diana", "Maria", "Tomas"])

        assertFilterShape(GeoCircle(center: GeoPoint(55.67, 12.56)!, radiusInRadians: 0.001)!, count: 1, expectedMatches: ["Maria"])
        assertFilterShape(GeoCircle(center: GeoPoint(55.67, 12.56)!, radius: Distance.fromKilometers(10)!)!, count: 1, expectedMatches: ["Maria"])
        assertFilterShape(GeoCircle(center: GeoPoint(55.67, 12.56)!, radius: Distance.fromKilometers(100)!)!, count: 2, expectedMatches: ["Maria", "Tomas"])
        assertFilterShape(GeoCircle(center: GeoPoint(45, -20)!, radius: Distance.fromKilometers(5000)!)!, count: 3, expectedMatches: ["Diana", "Maria", "Tomas"])

        func assertFilterShape<U: GeoShape>(_ shape: U, count: Int, expectedMatches: [String]) {
            let realm = realmWithTestPath()
            let resultsBox = realm.objects(PersonLocation.self).where { $0.location.geoWithin(shape) }
            XCTAssertEqual(resultsBox.count, count)
            expectedMatches.forEach { match in
                XCTAssertTrue(resultsBox.contains(where: { $0.name == match }))
            }

            let resultsBoxFilter = realm.objects(PersonLocation.self).filter("location IN %@", shape)
            XCTAssertEqual(resultsBoxFilter.count, count)
            expectedMatches.forEach { match in
                XCTAssertTrue(resultsBoxFilter.contains(where: { $0.name == match }))
            }

            let arguments = NSMutableArray()
            arguments.add(shape)
            let resultsBoxNSPredicate = realm.objects(PersonLocation.self).filter(NSPredicate(format: "location IN %@", argumentArray: arguments as? [Any]))
            XCTAssertEqual(resultsBoxNSPredicate.count, count)
            expectedMatches.forEach { match in
                XCTAssertTrue(resultsBoxNSPredicate.contains(where: { $0.name == match }))
            }
        }
    }

    func testInvalidTypeValueForObjectGeoPoint() throws {
        try populatePersonLocationTable()

        let realm = realmWithTestPath()
        let persons = realm.objects(PersonLocation.self)

        let shape = GeoBox(bottomLeft: GeoPoint(55.6281, 12.0826)!, topRight: GeoPoint(55.6762, 12.5684)!)!
        // Executing the query will return one object which is in the region of the GeoBox
        XCTAssertEqual(realm.objects(PersonLocation.self).where { $0.location.geoWithin(shape) }.count, 1)

        try realm.write {
            for person in persons {
                person.location?.type = "Polygon"
            }
        }

        // Even though one of the GeoPoints is within the box regions, having the type set as
        // Polygon will cause to return not found.
        XCTAssertEqual(realm.objects(PersonLocation.self).where { $0.location.geoWithin(shape) }.count, 0)
    }

    func testInvalidObjectTypesForGeoQuery() throws {
        let realm = realmWithTestPath()

        // Populate
        try realm.write {
            let geoPointCoordinatesEmbedded = CoordinatesGeoPointEmbedded()
            geoPointCoordinatesEmbedded.coordinates.append(objectsIn: [2, 1])

            let geoPointTypeEmbedded = TypeGeoPointEmbedded()
            let topLevelGeoPoint = TopLevelGeoPoint()

            let object = PersonWithInvalidTypes()
            object.geoPointCoordinatesEmbedded = geoPointCoordinatesEmbedded
            object.geoPointTypeEmbedded = geoPointTypeEmbedded
            object.geoPoint = topLevelGeoPoint
            realm.add(object)
        }

        let shape = GeoCircle(center: GeoPoint(0, 0)!, radiusInRadians: 10.0)!

        assertThrows(realm.objects(PersonWithInvalidTypes.self).where { $0.geoPointCoordinatesEmbedded.geoWithin(shape) }, reason: "Query 'geoPointCoordinatesEmbedded GEOWITHIN GeoCircle([0, 0], 10)' links to data in the wrong format for a geoWithin query")
        assertThrowsFilterShape(shape, "geoPointCoordinatesEmbedded", reason: "Query 'geoPointCoordinatesEmbedded GEOWITHIN GeoCircle([0, 0], 10)' links to data in the wrong format for a geoWithin query")

        assertThrows(realm.objects(PersonWithInvalidTypes.self).where { $0.geoPointTypeEmbedded.geoWithin(shape) }, reason: "Query 'geoPointTypeEmbedded GEOWITHIN GeoCircle([0, 0], 10)' links to data in the wrong format for a geoWithin query")
        assertThrowsFilterShape(shape, "geoPointTypeEmbedded", reason: "Query 'geoPointTypeEmbedded GEOWITHIN GeoCircle([0, 0], 10)' links to data in the wrong format for a geoWithin query")

        assertThrowsFilterShape(shape, "geoPoint", reason: "A GEOWITHIN query can only operate on a link to an embedded class but 'TopLevelGeoPoint' is at the top level")

        func assertThrowsFilterShape<U: GeoShape>(_ shape: U, _ property: String, reason: String) {
            let realm = realmWithTestPath()
            assertThrows(realm.objects(PersonWithInvalidTypes.self).filter("\(property) IN %@", shape), reason: reason)

            let arguments = NSMutableArray()
            arguments.add(shape)
            assertThrows(realm.objects(PersonWithInvalidTypes.self).filter(NSPredicate(format: "\(property) IN %@", argumentArray: arguments as? [Any])), reason: reason)
        }
    }

    func testGeoPoints() throws {
        assertGeoPoint(90.000000001, 0, isNull: true)
        assertGeoPoint(-90.000000001, 0, isNull: true)
        assertGeoPoint(9999999, 0, isNull: true)
        assertGeoPoint(-9999999, 0, isNull: true)
        assertGeoPoint(90, 0)
        assertGeoPoint(-90, 0)
        assertGeoPoint(12.3456789, 0)
        assertGeoPoint(0, 180.000000001, isNull: true)
        assertGeoPoint(0, -180.000000001, isNull: true)
        assertGeoPoint(0, 9999999, isNull: true)
        assertGeoPoint(0, -9999999, isNull: true)
        assertGeoPoint(0, 180)
        assertGeoPoint(0, -180)
        assertGeoPoint(0, 12.3456789)

        func assertGeoPoint(_ latitude: Double, _ longitude: Double, isNull: Bool = false) {
            if isNull {
                XCTAssertNil(GeoPoint(latitude, longitude))
            } else {
                XCTAssertNotNil(GeoPoint(latitude, longitude))
            }
        }
    }

    func testGeoDistance() throws {
        assertGeoDistance(Distance.fromRadians(0))
        assertGeoDistance(Distance.fromRadians(20))
        assertGeoDistance(Distance.fromRadians(-20), isNull: true)

        assertGeoDistance(Distance.fromKilometers(0))
        assertGeoDistance(Distance.fromKilometers(10))
        assertGeoDistance(Distance.fromKilometers(-10), isNull: true)

        assertGeoDistance(Distance.fromMiles(0))
        assertGeoDistance(Distance.fromMiles(10))
        assertGeoDistance(Distance.fromMiles(-10), isNull: true)

        func assertGeoDistance(_ radius: Distance?, isNull: Bool = false) {
            if isNull {
                XCTAssertNil(radius)
            } else {
                XCTAssertNotNil(radius)
            }
        }
    }

    func testDistanceFromKilometers() throws {
        let EarthCircumferenceKM: Double = 40075
        let distance = Distance.fromKilometers(EarthCircumferenceKM)!
        XCTAssertEqual(distance.radians, Double.pi * 2, accuracy: distance.radians * 0.0001)
    }

    func testDistanceFromMiles() throws {
        let EarthCircumferenceMi: Double = 24901
        let distance = Distance.fromMiles(EarthCircumferenceMi)!
        XCTAssertEqual(distance.radians, Double.pi * 2, accuracy: distance.radians * 0.0001)
    }

    func testDistanceFromRadians() throws {
        let distance = Distance.fromRadians(Double.pi)!
        XCTAssertEqual(distance.radians, Double.pi)
    }

    func testGeoCircle() throws {
        assertGeoCircle(GeoPoint(0, 70)!, 0)
        assertGeoCircle(GeoPoint(0, 70)!, 500)
        assertGeoCircle(GeoPoint(0, 70)!, -500, isNull: true)

        func assertGeoCircle(_ center: GeoPoint, _ radius: Double, isNull: Bool = false) {
            if isNull {
                XCTAssertNil(GeoCircle(center: center, radiusInRadians: radius))
            } else {
                XCTAssertNotNil(GeoCircle(center: center, radiusInRadians: radius))
            }
        }
    }

    func testInvalidGeoPolygon() throws {
        assertGeoPolygon(outerRing: GeoPoint(0, 0)!)
        assertGeoPolygon(outerRing: GeoPoint(0, 0)!, GeoPoint(1, 1)!, GeoPoint(0, 0)!)
        assertGeoPolygon(outerRing: GeoPoint(0, 0)!, GeoPoint(1, 1)!, GeoPoint(2, 2)!)

        assertGeoPolygon(outerRing: GeoPoint(0, 0)!, GeoPoint(1, 1)!, GeoPoint(2, 2)!, GeoPoint(3, 3)!, holes: [GeoPoint(0, 0)!])
        assertGeoPolygon(outerRing: GeoPoint(0, 0)!, GeoPoint(1, 1)!, GeoPoint(2, 2)!, GeoPoint(0, 0)!, holes: [GeoPoint(0, 0)!, GeoPoint(1, 1)!, GeoPoint(0, 0)!])
        assertGeoPolygon(outerRing: GeoPoint(0, 0)!, GeoPoint(1, 1)!, GeoPoint(2, 2)!, GeoPoint(0, 0)!, holes: [GeoPoint(0, 0)!, GeoPoint(1, 1)!, GeoPoint(2, 2)!])
        assertGeoPolygon(outerRing: GeoPoint(0, 0)!, GeoPoint(1, 1)!, GeoPoint(2, 2)!, GeoPoint(0, 0)!, holes: [GeoPoint(0, 0)!, GeoPoint(1, 1)!, GeoPoint(2, 2)!, GeoPoint(3, 3)!])
        assertGeoPolygon(outerRing: GeoPoint(0, 0)!, GeoPoint(1, 1)!, GeoPoint(2, 2)!, GeoPoint(0, 0)!, holes: [GeoPoint(0, 0)!, GeoPoint(1, 1)!, GeoPoint(2, 2)!, GeoPoint(3, 3)!], [GeoPoint(0, 0)!])

        func assertGeoPolygon(outerRing: GeoPoint..., holes: [GeoPoint]..., isNull: Bool = false) {
            XCTAssertNil(GeoPolygon(outerRing: outerRing, holes: holes))
        }
    }

    func testHoleNotContainedOuterRingInGeoPolygon() throws {
        let realm = realmWithTestPath()
        assertThrows(realm.objects(PersonLocation.self).where { $0.location.geoWithin(GeoPolygon(outerRing: GeoPoint(0, 0)!, GeoPoint(0, 1)!, GeoPoint(1, 1)!, GeoPoint(1, 0)!, GeoPoint(0, 0)!, holes: [GeoPoint(2, 2)!, GeoPoint(2, 3)!, GeoPoint(3, 3)!, GeoPoint(3, 2)!, GeoPoint(2, 2)!])!) }, reason: "Invalid region in GEOWITHIN query for parameter 'GeoPolygon({[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]}, {[2, 2], [3, 2], [3, 3], [2, 3], [2, 2]})': 'Secondary ring 1 not contained by first exterior ring - secondary rings must be holes in the first ring")
        assertThrows(realm.objects(PersonLocation.self).where { $0.location.geoWithin(GeoPolygon(outerRing: GeoPoint(0, 0)!, GeoPoint(0, 1)!, GeoPoint(1, 1)!, GeoPoint(1, 0)!, GeoPoint(0, 0)!, holes: [GeoPoint(0, 0.1)!, GeoPoint(0.5, 0.1)!, GeoPoint(0.5, 0.5)!, GeoPoint(0, 0.5)!, GeoPoint(0, 0.1)!])!) }, reason: "Invalid region in GEOWITHIN query for parameter 'GeoPolygon({[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]}, {[0.1, 0], [0.1, 0.5], [0.5, 0.5], [0.5, 0], [0.1, 0]})': 'Secondary ring 1 not contained by first exterior ring - secondary rings must be holes in the first ring")
        assertThrows(realm.objects(PersonLocation.self).where { $0.location.geoWithin(GeoPolygon(outerRing: GeoPoint(0, 0)!, GeoPoint(0, 1)!, GeoPoint(1, 1)!, GeoPoint(1, 0)!, GeoPoint(0, 0)!, holes: [GeoPoint(0.25, 0.5)!, GeoPoint(0.75, 0.5)!, GeoPoint(0.75, 1.5)!, GeoPoint(0.25, 1.5)!, GeoPoint(0.25, 0.5)!])!) }, reason: "Invalid region in GEOWITHIN query for parameter 'GeoPolygon({[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]}, {[0.5, 0.25], [0.5, 0.75], [1.5, 0.75], [1.5, 0.25], [0.5, 0.25]})': 'Secondary ring 1 not contained by first exterior ring - secondary rings must be holes in the first ring")
    }

    func testGeoEquality() throws {
        XCTAssertEqual(GeoPoint(1, 1), GeoPoint(1, 1))
        XCTAssertNotEqual(GeoPoint(1, 1), GeoPoint(2, 1))

        XCTAssertEqual(GeoBox(bottom: 0, left: 0, top: 1, right: 1), GeoBox(bottomLeft: GeoPoint(0, 0)!, topRight: GeoPoint(1, 1)!))
    }
}
