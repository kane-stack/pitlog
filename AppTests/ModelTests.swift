import Foundation
import PitlogCore
import SwiftData
import Testing
import UIKit

@testable import Pitlog

@MainActor
struct ModelTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelContainerFactory.inMemory())
    }

    @Test func createsAndFetchesAVehicleWithReadings() throws {
        let context = try makeContext()
        let vehicle = Vehicle(name: "Golf", licensePlate: "W 1 A")
        context.insert(vehicle)
        context.insert(OdometerReading(date: Date(timeIntervalSince1970: 1_000), kilometers: 10_000, vehicle: vehicle))
        context.insert(OdometerReading(date: Date(timeIntervalSince1970: 2_000), kilometers: 12_500, vehicle: vehicle))
        context.insert(OdometerReading(date: Date(timeIntervalSince1970: 1_500), kilometers: 11_000, vehicle: vehicle))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Vehicle>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.odometerReadings?.count == 3)
        #expect(fetched.first?.currentOdometerKm == 12_500)
    }

    @Test func deletingAVehicleCascadesToReadings() throws {
        let context = try makeContext()
        let vehicle = Vehicle(name: "Golf")
        context.insert(vehicle)
        context.insert(OdometerReading(kilometers: 1, vehicle: vehicle))
        context.insert(OdometerReading(kilometers: 2, vehicle: vehicle))
        let other = Vehicle(name: "Other")
        context.insert(other)
        context.insert(OdometerReading(kilometers: 3, vehicle: other))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<OdometerReading>()) == 3)

        context.delete(vehicle)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Vehicle>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<OdometerReading>()) == 1)
    }

    @Test func updatesAndArchives() throws {
        let context = try makeContext()
        let vehicle = Vehicle(name: "Golf")
        context.insert(vehicle)
        vehicle.name = "Golf GTI"
        vehicle.isArchived = true
        try context.save()
        let archived = try context.fetch(FetchDescriptor<Vehicle>(predicate: #Predicate { $0.isArchived }))
        #expect(archived.first?.name == "Golf GTI")
    }

    @Test func calendarComponentsRoundTrip() {
        let vehicle = Vehicle(name: "Golf")
        vehicle.firstRegistration = YearMonth(year: 2020, month: 6)
        vehicle.plaque = YearMonth(year: 2027, month: 3)
        vehicle.lastInspection = DayDate(year: 2025, month: 3, day: 14)
        #expect(vehicle.firstRegistrationYear == 2020 && vehicle.firstRegistrationMonth == 6)
        #expect(vehicle.plaque == YearMonth(year: 2027, month: 3))
        #expect(vehicle.lastInspection == DayDate(year: 2025, month: 3, day: 14))
        vehicle.plaque = nil
        #expect(vehicle.plaqueYear == nil && vehicle.plaqueMonth == nil)
    }

    @Test func unknownCategoryFallsBackToOther() {
        let vehicle = Vehicle(name: "Golf")
        vehicle.categoryRaw = "hovercraft"
        #expect(vehicle.category == .other)
    }

    @Test func entitlementsNeverLimitUnlimited() {
        let entitlements = UnlimitedEntitlements()
        #expect(entitlements.canAddVehicle(currentCount: 10_000))
        struct Limited: Entitlements {
            var isPro: Bool { false }
            var vehicleLimit: Int { 1 }
            var canScanReceipts: Bool { false }
            var canUseProReminders: Bool { false }
            var canViewMultiYearCosts: Bool { false }
            var canExportServiceRecord: Bool { false }
        }
        #expect(Limited().canAddVehicle(currentCount: 0))
        #expect(!Limited().canAddVehicle(currentCount: 1))
    }

    @Test func photoIsDownscaledToMaxPixel() throws {
        let size = CGSize(width: 3000, height: 2000)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.9) { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let data = try #require(PhotoDownscaler.jpegData(from: source, maxPixel: 1600))
        let image = try #require(UIImage(data: data))
        #expect(max(image.size.width * image.scale, image.size.height * image.scale) <= 1600)
        #expect(PhotoDownscaler.jpegData(from: Data([1, 2, 3])) == nil)
    }
}
