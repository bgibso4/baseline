import Testing
import Foundation
@testable import Baseline

@Suite("APIClient Tests")
struct APIClientTests {

    private let baseURL = URL(string: "https://api.example.com")!
    private let token = "test-token-123"

    @Test("buildPushRequest creates correct URL for table")
    func testBuildPushRequest() {
        let client = APIClient(baseURL: baseURL, authToken: token)
        let entry = WeightEntry(weight: 185.0, unit: "lb")
        let request = client.buildPushRequest(for: entry)

        #expect(request != nil)
        #expect(request?.url?.absoluteString == "https://api.example.com/v1/weight_entries")
        #expect(request?.httpMethod == "POST")
        #expect(request?.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer test-token-123")
    }

    @Test("buildPushRequest body contains record payload")
    func testBuildPushRequestBody() throws {
        let client = APIClient(baseURL: baseURL, authToken: token)
        let entry = WeightEntry(weight: 200.0, unit: "lb", date: Date(), notes: "Test")
        let request = client.buildPushRequest(for: entry)

        let body = try #require(request?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(json["weight"] as? Double == 200.0)
        #expect(json["unit"] as? String == "lb")
        #expect(json["notes"] as? String == "Test")
        #expect(json["id"] as? String == entry.id.uuidString)
    }

    @Test("buildPushRequest uses correct table for Scan")
    func testBuildPushRequestForScan() throws {
        let client = APIClient(baseURL: baseURL, authToken: token)
        let payload = InBodyPayload(
            weightKg: 84.0,
            skeletalMuscleMassKg: 38.5,
            bodyFatMassKg: 12.0,
            bodyFatPct: 14.3,
            totalBodyWaterL: 52.0,
            bmi: 24.5,
            basalMetabolicRate: 1850
        )
        let data = try JSONEncoder().encode(payload)
        let scan = Scan(date: Date(), type: .inBody, source: .manual, payload: data)
        let request = client.buildPushRequest(for: scan)

        #expect(request?.url?.absoluteString == "https://api.example.com/v1/scans")
    }

    @Test("buildPushRequest uses correct table for Measurement")
    func testBuildPushRequestForMeasurement() {
        let client = APIClient(baseURL: baseURL, authToken: token)
        let measurement = Measurement(date: Date(), type: .waist, valueCm: 82.5)
        let request = client.buildPushRequest(for: measurement)

        #expect(request?.url?.absoluteString == "https://api.example.com/v1/measurements")
    }
}
