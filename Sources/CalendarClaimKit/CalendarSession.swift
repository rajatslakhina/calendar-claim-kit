import Foundation

/// Running totals across a conversation.
public struct CalendarTotals: Sendable, Hashable {
    public internal(set) var turns = 0
    public internal(set) var checks = 0
    public internal(set) var verified = 0
    public internal(set) var contradicted = 0
    public internal(set) var impossibleDates = 0
    public internal(set) var conventionDependent = 0
    public internal(set) var unresolved = 0

    mutating func add(_ report: CalendarReport) {
        turns += 1
        checks += report.checks.count
        verified += report.count(.verified)
        contradicted += report.count(.contradicted)
        impossibleDates += report.count(.impossibleDate)
        conventionDependent += report.count(.conventionDependent)
        unresolved += report.count(.unresolved)
    }
}

/// Checks a conversation's answers one turn at a time and remembers the year it is about, so "Is
/// March 17 a Tuesday?" two turns after "Plan our 2027 offsite" is checked against 2027, not this year.
///
/// An actor because the year a turn sets must be the one the next turn reads, whichever task reviews it.
public actor CalendarSession {
    public nonisolated let checker: CalendarChecker
    /// The last year the conversation stated: the question's if it gave one, else the answer's.
    public private(set) var contextYear: Int?
    public private(set) var totals = CalendarTotals()
    public private(set) var lastReport: CalendarReport?

    public init(checker: CalendarChecker = CalendarChecker()) {
        self.checker = checker
    }

    @discardableResult
    public func review(answer: String, question: String? = nil, now: Date? = nil) -> CalendarReport {
        let report = checker.check(answer: answer, question: question, now: now, contextYear: contextYear)
        contextYear = report.questionYears.last ?? report.answerYears.last ?? contextYear
        totals.add(report)
        lastReport = report
        return report
    }
}
