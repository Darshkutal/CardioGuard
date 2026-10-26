import XCTest
@testable import CardioGuard

final class StatsTests: XCTestCase {
    func testEmptyReturnsNil() {
        XCTAssertNil(Stats.summary([]))
    }

    func testSingleValueHasZeroStdDev() {
        let s = Stats.summary([72])!
        XCTAssertEqual(s.mean, 72)
        XCTAssertEqual(s.stdDev, 0)
        XCTAssertEqual(s.count, 1)
    }

    func testMeanAndSampleStdDev() {
        let s = Stats.summary([2, 4, 4, 4, 5, 5, 7, 9])!
        XCTAssertEqual(s.mean, 5, accuracy: 1e-9)
        XCTAssertEqual(s.stdDev, 2.13809, accuracy: 1e-4)
        XCTAssertEqual(s.min, 2)
        XCTAssertEqual(s.max, 9)
    }

    func testTimeRangeCutoff() {
        let now = Date()
        XCTAssertNil(TimeRange.all.cutoff(from: now))
        let week = TimeRange.week.cutoff(from: now)!
        XCTAssertEqual(now.timeIntervalSince(week), 7 * 86400, accuracy: 3700) // DST slack
    }

    func testCSVEscape() {
        XCTAssertEqual(CSV.escape("plain"), "plain")
        XCTAssertEqual(CSV.escape("a,b"), "\"a,b\"")
        XCTAssertEqual(CSV.escape("say \"hi\""), "\"say \"\"hi\"\"\"")
    }

    func testPlausibleRanges() {
        XCTAssertTrue(VitalType.heartRate.plausibleRange.contains(72))
        XCTAssertFalse(VitalType.heartRate.plausibleRange.contains(5000))
        XCTAssertTrue(VitalType.bloodPressure.hasSecondary)
    }
}
