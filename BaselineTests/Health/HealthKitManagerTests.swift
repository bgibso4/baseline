import XCTest
import HealthKit
@testable import Baseline

final class HealthKitManagerTests: XCTestCase {

    // MARK: - Types

    func testHealthKitTypesAreCorrect() {
        let types = HealthKitManager.allWriteTypes
        XCTAssertTrue(types.contains(HKQuantityType(.bodyMass)))
        XCTAssertTrue(types.contains(HKQuantityType(.bodyFatPercentage)))
        XCTAssertTrue(types.contains(HKQuantityType(.leanBodyMass)))
        XCTAssertTrue(types.contains(HKQuantityType(.bodyMassIndex)))
        XCTAssertTrue(types.contains(HKQuantityType(.waistCircumference)))
    }

    // MARK: - Weight Samples

    func testBuildWeightSampleLb() {
        let date = Date()
        let sample = HealthKitManager.buildWeightSample(weight: 197.4, unit: "lb", date: date)
        XCTAssertEqual(sample.quantityType, HKQuantityType(.bodyMass))
        XCTAssertEqual(sample.quantity.doubleValue(for: .pound()), 197.4, accuracy: 0.01)
        XCTAssertEqual(sample.startDate, date)
    }

    func testBuildWeightSampleKg() {
        let date = Date()
        let sample = HealthKitManager.buildWeightSample(weight: 89.5, unit: "kg", date: date)
        XCTAssertEqual(sample.quantity.doubleValue(for: .gramUnit(with: .kilo)), 89.5, accuracy: 0.01)
    }

    // MARK: - Body Fat

    func testBuildBodyFatSample() {
        let date = Date()
        let sample = HealthKitManager.buildBodyFatSample(percentage: 16.9, date: date)
        XCTAssertEqual(sample.quantityType, HKQuantityType(.bodyFatPercentage))
        // HealthKit stores body fat as ratio (0.169), not percentage (16.9)
        XCTAssertEqual(sample.quantity.doubleValue(for: .percent()), 0.169, accuracy: 0.001)
    }

    // MARK: - Lean Body Mass

    func testBuildLeanBodyMassSample() {
        let date = Date()
        let sample = HealthKitManager.buildLeanBodyMassSample(kg: 74.4, date: date)
        XCTAssertEqual(sample.quantityType, HKQuantityType(.leanBodyMass))
        XCTAssertEqual(sample.quantity.doubleValue(for: .gramUnit(with: .kilo)), 74.4, accuracy: 0.01)
    }

    // MARK: - BMI

    func testBuildBMISample() {
        let date = Date()
        let sample = HealthKitManager.buildBMISample(bmi: 25.8, date: date)
        XCTAssertEqual(sample.quantityType, HKQuantityType(.bodyMassIndex))
        XCTAssertEqual(sample.quantity.doubleValue(for: .count()), 25.8, accuracy: 0.01)
    }

    // MARK: - Waist

    func testBuildWaistSample() {
        let date = Date()
        let sample = HealthKitManager.buildWaistSample(valueCm: 85.0, date: date)
        XCTAssertEqual(sample.quantityType, HKQuantityType(.waistCircumference))
        XCTAssertEqual(sample.quantity.doubleValue(for: .meterUnit(with: .centi)), 85.0, accuracy: 0.01)
    }
}
