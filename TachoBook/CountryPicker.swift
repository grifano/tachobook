//
//  CountryPicker.swift
//  TachoBook
//

import SwiftUI

/// The country chosen in a Start, Close or edit sheet, and where the choice came from (Figma «Flow - Country selection»).
struct CountrySelection: Equatable {
    enum Source: Equatable {
        /// Found from the phone's location.
        case located
        /// No location: the country recorded last.
        case lastShift
        /// The value already stored for the event being edited.
        case recorded
        /// Picked by the driver in this sheet.
        case driver
        /// Nothing yet.
        case none
    }

    /// The country, possibly without its Spanish region yet.
    private(set) var place: ShiftPlace?
    private(set) var source: Source

    init(place: ShiftPlace?, source: Source) {
        self.place = place
        self.source = place == nil ? .none : source
    }

    /// A new Start or Close: the last recorded country until the location answers.
    static func newEvent(lastPlace: ShiftPlace?) -> CountrySelection {
        CountrySelection(place: lastPlace, source: .lastShift)
    }

    /// An edit: the stored country, if any.
    static func editing(_ place: ShiftPlace?) -> CountrySelection {
        CountrySelection(place: place, source: .recorded)
    }

    /// Another country clears the Spanish region; picking Spain again keeps it.
    mutating func select(country code: String) {
        if place?.country != code { place = ShiftPlace(country: code) }
        source = .driver
    }

    mutating func select(region code: String) {
        guard place?.isSpain == true else { return }
        place?.region = code
        source = .driver
    }

    /// The location answer replaces a guess, never the driver's own choice. A country outside the list is ignored.
    mutating func apply(detected: ShiftPlace?) {
        guard let detected, detected.tachoCountry != nil, source == .lastShift || source == .none else { return }
        place = detected.isSpain ? detected : ShiftPlace(country: detected.country)
        source = .located
    }

    /// Start and Close need a country (and in Spain a region); an edit of an older record may stay without one.
    func canConfirm(required: Bool) -> Bool {
        place.map(\.isComplete) ?? !required
    }

    /// The line under the popup.
    var hint: String {
        if place?.isSpain == true { return "In Spain, choose the region too." }
        switch source {
        case .located: return "Found by your location. Tap to change."
        case .lastShift: return "Same as your last shift. Tap to change."
        case .recorded, .driver: return "Picked the wrong country? Tap to fix it."
        case .none: return "Choose the country you\u{2019}re in."
        }
    }
}

/// Figma «Country Row» and «Country Hint»: the country popup, the Spanish region popup next to it, and a hint.
struct CountryField: View {
    @Binding var selection: CountrySelection
    /// The most recently recorded countries, newest first.
    var recents: [TachoCountry]
    @State private var showAllCountries = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                countryControl
                if selection.place?.isSpain == true {
                    regionMenu
                        .transition(.opacity)
                }
            }
            .animation(.default, value: selection.place?.isSpain)
            Text(selection.hint)
                .font(.footnote)
                .foregroundStyle(Color.tachoTextOnLight)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .accessibilityIdentifier("countryHint")
        }
        .sheet(isPresented: $showAllCountries) {
            CountryListSheet(selected: selection.place?.country, recents: menuCountries) { selection.select(country: $0.code) }
        }
    }

    /// The selected country first, then the recent ones: at most four rows (decision 5, 13.11.2026).
    private var menuCountries: [TachoCountry] {
        var seen = Set<String>()
        let selected = selection.place?.tachoCountry.map { [$0] } ?? []
        return (selected + recents).filter { seen.insert($0.code).inserted }.prefix(4).map { $0 }
    }

    @ViewBuilder private var countryControl: some View {
        let country = selection.place?.tachoCountry
        let label = PopupLabel(title: country.map { "\($0.flag) \($0.name())" } ?? "Choose country")
        if menuCountries.isEmpty {
            // Nothing recent to offer: the full list straight away.
            Button { showAllCountries = true } label: { label }
                .countryControl(identifier: "countryPicker", label: "Country", value: "Not chosen")
        } else {
            Menu {
                // Figma «Section Title» "Recent"; menu toggles draw the native checkmark on the selected one.
                Section("Recent") {
                    ForEach(menuCountries) { country in
                        Toggle(country.menuTitle(), isOn: Binding(
                            get: { selection.place?.country == country.code },
                            set: { _ in selection.select(country: country.code) }))
                    }
                }
                Divider()
                Button("All countries\u{2026}") { showAllCountries = true }
                    .accessibilityIdentifier("allCountriesButton")
            } label: { label }
                // Figma order (Recent on top) also when the menu opens upwards.
                .menuOrder(.fixed)
                .countryControl(identifier: "countryPicker", label: "Country",
                                value: country.map { "\($0.name()), \($0.code)" } ?? "Not chosen")
        }
    }

    private var regionMenu: some View {
        Menu {
            Picker("Region", selection: regionBinding) {
                ForEach(SpainRegion.all) { Text("\($0.name) (\($0.code))").tag(Optional($0.code)) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            PopupLabel(title: selection.place?.spainRegion?.name ?? "Region")
        }
        .menuOrder(.fixed)
        .countryControl(identifier: "regionPicker", label: "Region in Spain",
                        value: selection.place?.spainRegion.map { "\($0.name), \($0.code)" } ?? "Not chosen")
    }

    private var regionBinding: Binding<String?> {
        Binding(get: { selection.place?.region }, set: { if let code = $0 { selection.select(region: code) } })
    }
}

/// Figma «Popup Button»: semibold title with an up-down chevron. Text stays navy (project rule: text #072B3C or white).
private struct PopupLabel: View {
    var title: String
    @ScaledMetric(relativeTo: .headline) private var size: CGFloat = 18

    var body: some View {
        HStack(spacing: 3) {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: size * 0.7, weight: .semibold))
                .accessibilityHidden(true)
        }
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(Color.tachoTextOnLight)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

private extension View {
    func countryControl(identifier: String, label: String, value: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityHint("Tap to change")
            .accessibilityIdentifier(identifier)
    }
}

/// Figma «Country 4»: every tachograph country with a search field, recent ones first.
struct CountryListSheet: View {
    var selected: String?
    var recents: [TachoCountry]
    var onSelect: (TachoCountry) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    /// Figma `Accents/Blue` for the selection checkmark (an icon, not text).
    private static let checkmarkBlue = Color(red: 0, green: 136 / 255, blue: 1)

    private var results: [TachoCountry] { TachoCountry.sorted().filter { $0.matches(query) } }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty && !recents.isEmpty {
                    Section { ForEach(recents, content: row) } header: { header("Recent") }
                }
                Section { ForEach(results, content: row) } header: { header("All countries") }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .overlay {
                if results.isEmpty { ContentUnavailableView.search(text: query) }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search country")
            .navigationTitle("Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Country")
                        .font(.headline)
                        .foregroundStyle(Color.tachoTextOnLight)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                        .accessibilityIdentifier("closeCountryListButton")
                }
            }
        }
        .foregroundStyle(Color.tachoTextOnLight)
        .environment(\.colorScheme, .light)
        .presentationDragIndicator(.hidden)
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.tachoOrange)
                .frame(width: 36, height: 5)
                .padding(.top, 5)
                .accessibilityHidden(true)
        }
        .presentationBackground(.white)
    }

    /// Figma «Section Header»: footnote, upper case.
    private func header(_ title: String) -> some View {
        Text(title)
            .font(.footnote)
            .textCase(.uppercase)
            .foregroundStyle(Color.tachoTextOnLight)
    }

    private func row(_ country: TachoCountry) -> some View {
        Button {
            onSelect(country)
            dismiss()
        } label: {
            HStack {
                Text(country.listTitle())
                    .foregroundStyle(Color.tachoTextOnLight)
                Spacer()
                if country.code == selected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Self.checkmarkBlue)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("\(country.name()), \(country.code)")
        .accessibilityAddTraits(country.code == selected ? .isSelected : [])
        .accessibilityIdentifier("countryRow-\(country.code)")
    }
}

/// A country flag drawn as an image that scales with the text. The flag emoji as `Text` reads as clipped
/// text to the accessibility audit at larger Dynamic Type sizes; the image looks the same.
struct FlagImage: View {
    var country: TachoCountry
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 17

    private static var cache: [String: UIImage] = [:]

    var body: some View {
        Image(uiImage: Self.image(for: country.flag))
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityLabel(country.name())
    }

    private static func image(for flag: String) -> UIImage {
        if let image = cache[flag] { return image }
        let text = NSAttributedString(string: flag, attributes: [.font: UIFont.systemFont(ofSize: 64)])
        let size = text.size()
        let image = UIGraphicsImageRenderer(size: size).image { _ in text.draw(at: .zero) }
        cache[flag] = image
        return image
    }
}
