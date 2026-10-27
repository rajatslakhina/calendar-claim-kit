public enum CheckStatus: String, Sendable, Hashable, CaseIterable {
    case verified
    case contradicted
    case impossibleDate = "impossible date"
    /// True under one reading and false under another: "91 days" from March 3 to June 1 counts both ends;
    /// "next Friday" read as the one after this week's; a year the text never stated.
    case conventionDependent = "depends on convention"
    /// The calendar cannot answer it from what the text gives: no year, or "today" with no clock.
    case unresolved
}

/// One claim checked against the calendar.
public struct CalendarCheck: Sendable, Hashable {
    /// Nil for a date that does not exist, which is checked without being part of a statement.
    public let claim: CalendarClaim?
    public let status: CheckStatus
    /// What the text says: "March 17, 2026 is a Monday".
    public let statement: String
    /// What the calendar says: "March 17, 2026 is a Tuesday".
    public let truth: String
    /// Why a check depends on convention or could not be resolved.
    public let reason: String?

    init(claim: CalendarClaim?, status: CheckStatus, statement: String, truth: String, reason: String? = nil) {
        self.claim = claim
        self.status = status
        self.statement = statement
        self.truth = truth
        self.reason = reason
    }
}
