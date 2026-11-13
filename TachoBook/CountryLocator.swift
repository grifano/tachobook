//
//  CountryLocator.swift
//  TachoBook
//

import CoreLocation
import MapKit

/// Finds the country (and Spanish region) the phone is in, once, when a Start or Close sheet opens.
/// Never blocks a shift: no permission, no fix, no network or a country outside the tachograph list all give nil.
struct CountryLocator {
    var locate: @MainActor () async -> ShiftPlace?

    /// The phone's location: one when-in-use fix, then the address of that point.
    static let device = CountryLocator {
        guard let location = await firstLocation(timeout: .seconds(20)) else { return nil }
        return await place(at: location)
    }

    /// No location (permission denied, offline): the sheet falls back to the last country.
    static let none = CountryLocator { nil }

    static func fixed(_ place: ShiftPlace?) -> CountryLocator { CountryLocator { place } }

    /// DEBUG launch arguments keep UI tests away from the system location prompt:
    /// `-stubCountry PL` (or `E:CAT` for Spain with a region), `-stubCountry none`. UI test runs default to Poland.
    static var forLaunch: CountryLocator {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-stubCountry"), index + 1 < args.count {
            let parts = args[index + 1].split(separator: ":").map(String.init)
            return parts.first == "none" ? .none : .fixed(ShiftPlace(country: parts[0], region: parts.dropFirst().first))
        }
        let uiTestFlags = ["-sampleData", "-persistenceUITest", "-timerUITest", "-homeFlowUITest"]
        if uiTestFlags.contains(where: args.contains) { return .fixed(ShiftPlace(country: "PL")) }
        #endif
        return .device
    }

    private static func firstLocation(timeout: Duration) async -> CLLocation? {
        // The session asks for when-in-use permission the first time and keeps it while the fix is taken.
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        return await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask {
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                            return nil
                        }
                        if let location = update.location { return location }
                    }
                } catch {}
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private static func place(at location: CLLocation) async -> ShiftPlace? {
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        // Spanish names match the tachograph region list best; the country code does not depend on the language.
        request.preferredLocale = Locale(identifier: "es_ES")
        guard let item = try? await request.mapItems.first,
              let iso = item.addressRepresentations?.region?.identifier,
              let country = TachoCountry(iso: iso) else { return nil }
        guard country == .spain else { return ShiftPlace(country: country.code) }
        let address = [item.addressRepresentations?.cityWithContext(.full), item.address?.fullAddress]
            .compactMap { $0 }.joined(separator: "\n")
        return ShiftPlace(country: country.code, region: SpainRegion.matching(address: address)?.code)
    }
}
