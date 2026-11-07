import XCTest

extension XCUIAccessibilityAuditIssue {
    /// TEMPORARY exclusion (Serhii, 2026-10-20, F7 option A).
    ///
    /// The native tab bar dims the disabled tab Restrictions, but SwiftUI does not give it the accessibility
    /// "not enabled" trait, so the audit reports "Missing trait: UIAccessibilityTraitNotEnabled" for exactly that
    /// tab button. Only that issue, for only that button, is ignored. Every other audit issue still fails the test.
    /// History (25.10.2026) and Violations (violation counter, 07.11.2026) are active tabs and no longer excluded.
    ///
    /// REMOVE this exclusion (and its call sites in the audit helpers) when Restrictions becomes an active tab.
    var isNotEnabledTraitOnADisabledTab: Bool {
        guard auditType == .trait,
              compactDescription.contains("UIAccessibilityTraitNotEnabled"),
              let element,
              element.elementType == .button,
              element.label == "Restrictions" else { return false }
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
