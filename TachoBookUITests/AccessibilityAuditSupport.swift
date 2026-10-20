import XCTest

extension XCUIAccessibilityAuditIssue {
    /// TEMPORARY exclusion (Serhii, 2026-10-20, F7 option A).
    ///
    /// The native tab bar dims the disabled tabs History, Violations and Restrictions, but SwiftUI does not
    /// give them the accessibility "not enabled" trait, so the audit reports
    /// "Missing trait: UIAccessibilityTraitNotEnabled" for exactly those three tab buttons.
    /// Only that issue, for only those three buttons, is ignored. Every other audit issue still fails the test.
    ///
    /// REMOVE this exclusion (and its two call sites in the audit helpers) when History, Violations and
    /// Restrictions become active tabs.
    var isNotEnabledTraitOnADisabledTab: Bool {
        guard auditType == .trait,
              compactDescription.contains("UIAccessibilityTraitNotEnabled"),
              let element,
              element.elementType == .button,
              ["History", "Violations", "Restrictions"].contains(element.label) else { return false }
        return true
    }
}
