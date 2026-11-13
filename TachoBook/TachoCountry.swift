//
//  TachoCountry.swift
//  TachoBook
//

import Foundation

/// A country from the EU tachograph nation code list (JRC Digital Tachograph laboratory,
/// https://dtc.jrc.ec.europa.eu/dtc_nation_codes.php.html — Appendix 1 of Reg. (EC) 1360/2002 and (EU) 2016/799).
/// The tachograph code is what the driver enters on the tachograph; it often differs from ISO (Germany D, Spain E).
nonisolated public struct TachoCountry: Hashable, Identifiable, Sendable {
    /// Tachograph nation code, e.g. "D". The stored value.
    public let code: String
    /// ISO 3166-1 alpha-2, e.g. "DE". For the flag, the localized name and matching the phone's location.
    public let iso: String

    public var id: String { code }

    /// The 55 current countries. Obsolete codes (FR Faroe Islands, YU, RFU) and group codes (EC, EUR, WLD) are left out.
    public static let all: [TachoCountry] = [
        ("AL", "AL"), ("AND", "AD"), ("ARM", "AM"), ("A", "AT"), ("AZ", "AZ"), ("BY", "BY"), ("B", "BE"),
        ("BIH", "BA"), ("BG", "BG"), ("HR", "HR"), ("CY", "CY"), ("CZ", "CZ"), ("DK", "DK"), ("EST", "EE"),
        ("FIN", "FI"), ("F", "FR"), ("GE", "GE"), ("D", "DE"), ("GR", "GR"), ("H", "HU"), ("IS", "IS"),
        ("IRL", "IE"), ("IL", "IL"), ("I", "IT"), ("KZ", "KZ"), ("KG", "KG"), ("LV", "LV"), ("FL", "LI"),
        ("LT", "LT"), ("L", "LU"), ("M", "MT"), ("MD", "MD"), ("MC", "MC"), ("MNE", "ME"), ("NL", "NL"),
        ("MK", "MK"), ("N", "NO"), ("PL", "PL"), ("P", "PT"), ("RO", "RO"), ("RUS", "RU"), ("RSM", "SM"),
        ("SRB", "RS"), ("SK", "SK"), ("SLO", "SI"), ("E", "ES"), ("S", "SE"), ("CH", "CH"), ("TJ", "TJ"),
        ("TR", "TR"), ("TM", "TM"), ("UA", "UA"), ("UK", "GB"), ("UZ", "UZ"), ("V", "VA"),
    ].map { TachoCountry(code: $0.0, iso: $0.1) }

    public static let spain = TachoCountry(code: "E", iso: "ES")

    private static let byCode = Dictionary(uniqueKeysWithValues: all.map { ($0.code, $0) })
    private static let byISO = Dictionary(uniqueKeysWithValues: all.map { ($0.iso, $0) })

    public init?(code: String) {
        guard let country = Self.byCode[code] else { return nil }
        self = country
    }

    /// The country for an ISO 3166-1 alpha-2 code from the phone's location; nil outside the tachograph list.
    public init?(iso: String) {
        guard let country = Self.byISO[iso.uppercased()] else { return nil }
        self = country
    }

    private init(code: String, iso: String) {
        self.code = code
        self.iso = iso
    }

    public var flag: String {
        String(String.UnicodeScalarView(iso.unicodeScalars.compactMap { Unicode.Scalar(127_397 + $0.value) }))
    }

    public func name(locale: Locale = .current) -> String {
        locale.localizedString(forRegionCode: iso) ?? iso
    }

    /// Figma «Country 4» row and the popup: "🇵🇱 Poland · PL".
    public func listTitle(locale: Locale = .current) -> String { "\(flag) \(name(locale: locale)) · \(code)" }

    /// Figma «Country 2» menu item: "🇵🇱 Poland (PL)".
    public func menuTitle(locale: Locale = .current) -> String { "\(flag) \(name(locale: locale)) (\(code))" }

    /// Search by the shown name, the English name or either code.
    public func matches(_ query: String, locale: Locale = .current) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        let english = Locale(identifier: "en").localizedString(forRegionCode: iso) ?? ""
        return [name(locale: locale), english].contains { $0.localizedStandardContains(query) }
            || code.caseInsensitiveCompare(query) == .orderedSame || iso.caseInsensitiveCompare(query) == .orderedSame
    }

    /// All countries in the order of their shown names.
    public static func sorted(locale: Locale = .current) -> [TachoCountry] {
        all.sorted { $0.name(locale: locale).localizedStandardCompare($1.name(locale: locale)) == .orderedAscending }
    }
}

/// A Spanish region code the tachograph asks for in Spain
/// (JRC: https://dtc.jrc.ec.europa.eu/dtc_spain_region_codes.php.html). CE and ME exist on smart tachographs only.
nonisolated public struct SpainRegion: Hashable, Identifiable, Sendable {
    public let code: String
    public let name: String
    /// Names the phone's address may use (Spanish, English, co-official languages); compared without accents.
    let aliases: [String]

    public var id: String { code }

    public static let all: [SpainRegion] = [
        SpainRegion(code: "AN", name: "Andalucía", aliases: ["Andalusia"]),
        SpainRegion(code: "AR", name: "Aragón", aliases: []),
        SpainRegion(code: "AST", name: "Asturias", aliases: ["Principado de Asturias", "Principality of Asturias"]),
        SpainRegion(code: "C", name: "Cantabria", aliases: []),
        SpainRegion(code: "CAT", name: "Cataluña", aliases: ["Catalunya", "Catalonia"]),
        SpainRegion(code: "CL", name: "Castilla y León", aliases: ["Castilla-León", "Castile and León"]),
        SpainRegion(code: "CM", name: "Castilla-La Mancha", aliases: ["Castile-La Mancha"]),
        SpainRegion(code: "CV", name: "Valencia", aliases: ["Comunidad Valenciana", "Comunitat Valenciana",
                                                            "Valencian Community", "València"]),
        SpainRegion(code: "EXT", name: "Extremadura", aliases: []),
        SpainRegion(code: "G", name: "Galicia", aliases: []),
        SpainRegion(code: "IB", name: "Baleares", aliases: ["Islas Baleares", "Illes Balears", "Balearic Islands"]),
        SpainRegion(code: "IC", name: "Canarias", aliases: ["Islas Canarias", "Canary Islands"]),
        SpainRegion(code: "LR", name: "La Rioja", aliases: []),
        SpainRegion(code: "M", name: "Madrid", aliases: ["Comunidad de Madrid", "Community of Madrid"]),
        SpainRegion(code: "MU", name: "Murcia", aliases: ["Región de Murcia", "Region of Murcia"]),
        SpainRegion(code: "NA", name: "Navarra", aliases: ["Comunidad Foral de Navarra", "Navarre", "Nafarroa"]),
        SpainRegion(code: "PV", name: "País Vasco", aliases: ["Euskadi", "Basque Country"]),
        SpainRegion(code: "CE", name: "Ceuta", aliases: []),
        SpainRegion(code: "ME", name: "Melilla", aliases: []),
    ]

    public init?(code: String) {
        guard let region = Self.all.first(where: { $0.code == code }) else { return nil }
        self = region
    }

    private init(code: String, name: String, aliases: [String]) {
        self.code = code
        self.name = name
        self.aliases = aliases
    }

    /// The region named by one part of an address ("Barcelona, Cataluña, España"); nil when no part is a region.
    public static func matching(address: String) -> SpainRegion? {
        let parts = address.split(whereSeparator: { $0 == "," || $0.isNewline }).map { normalized(String($0)) }
        return all.first { region in ([region.name] + region.aliases).map(normalized).contains(where: parts.contains) }
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Where the driver was at a shift start or close: stable codes, never display strings.
nonisolated public struct ShiftPlace: Codable, Hashable, Sendable {
    /// Tachograph nation code, e.g. "PL".
    public var country: String
    /// Spanish region code; only for Spain (E).
    public var region: String?

    public init(country: String, region: String? = nil) {
        self.country = country
        self.region = region
    }

    public var tachoCountry: TachoCountry? { TachoCountry(code: country) }
    public var spainRegion: SpainRegion? { region.flatMap(SpainRegion.init(code:)) }
    public var isSpain: Bool { country == TachoCountry.spain.code }

    /// A known country; in Spain also a known region, elsewhere no region.
    public var isComplete: Bool {
        guard tachoCountry != nil else { return false }
        return isSpain ? spainRegion != nil : region == nil
    }

    /// Figma «Country 6» code under the time: "F", or "E·PV" in Spain (the flag is drawn next to it).
    public var codeLabel: String {
        country + (region.map { "\u{00B7}\($0)" } ?? "")
    }
}
