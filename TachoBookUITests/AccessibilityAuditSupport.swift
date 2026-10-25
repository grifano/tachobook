import XCTest

extension XCUIAccessibilityAuditIssue {
    /// TEMPORARY exclusion (Serhii, 2026-10-20, F7 option A).
    ///
    /// The native tab bar dims the disabled tabs Violations and Restrictions, but SwiftUI does not
    /// give them the accessibility "not enabled" trait, so the audit reports
    /// "Missing trait: UIAccessibilityTraitNotEnabled" for exactly those two tab buttons.
    /// Only that issue, for only those two buttons, is ignored. Every other audit issue still fails the test.
    /// History is an active tab since the History calendar task (25.10.2026) and is no longer excluded.
    ///
    /// REMOVE this exclusion (and its call sites in the audit helpers) when Violations and
    /// Restrictions become active tabs.
    var isNotEnabledTraitOnADisabledTab: Bool {
        guard auditType == .trait,
              compactDescription.contains("UIAccessibilityTraitNotEnabled"),
              let element,
              element.elementType == .button,
              ["Violations", "Restrictions"].contains(element.label) else { return false }
        return true
    }
}

extension XCUIAccessibilityAuditIssue {
    /// History calendar exclusion (owner decision 1 of 24.10.2026: native `UICalendarView`).
    ///
    /// The system calendar grows its day numbers only part of the way at the largest text sizes, so the audit
    /// reports "Dynamic Type font sizes are partially unsupported" for each day number (a UIKit label the app
    /// cannot change). Only that issue, only for a label that is a day number (1–31), is ignored; it is used
    /// only by the History audits, where every other day number is SwiftUI text with full Dynamic Type.
    var isNativeCalendarDayNumber: Bool {
        guard auditType == .dynamicType,
              let element,
              let day = Int(element.label), (1...31).contains(day) else { return false }
        return true
    }
}
