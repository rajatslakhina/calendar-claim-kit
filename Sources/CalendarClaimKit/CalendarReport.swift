/// Every calendar claim found in one answer, checked.
public struct CalendarReport: Sendable, Hashable {
    public enum Verdict: String, Sendable, Hashable {
        case noClaims = "no calendar claims"
        case verified
        case conventionDependent = "depends on convention"
        case contradicted
        /// There were claims, and none could be checked (no year, no clock).
        case unverifiable
    }

    public let checks: [CalendarCheck]
    /// The day "today" meant, when the checker was given the time.
    public let today: CivilDate?
    let questionYears: [Int]
    let answerYears: [Int]

    public func count(_ status: CheckStatus) -> Int { checks.filter { $0.status == status }.count }

    public var verdict: Verdict {
        if checks.isEmpty { return .noClaims }
        if count(.contradicted) + count(.impossibleDate) > 0 { return .contradicted }
        if count(.conventionDependent) > 0 { return .conventionDependent }
        return count(.verified) > 0 ? .verified : .unverifiable
    }

    /// One line per wrong claim or impossible date: what the calendar says, and what the answer said.
    public var corrections: [String] {
        checks.compactMap { check in
            switch check.status {
            case .contradicted:
                "\(check.truth) (the answer said \(check.claim.flatMap(Describe.assertedValue) ?? quoted(check)))."
            case .impossibleDate: "\(check.statement) does not exist: \(check.truth)."
            default: nil
            }
        }
    }

    func quoted(_ check: CalendarCheck) -> String { "\"\(check.statement)\"" }

    /// One line per claim that holds only under one reading.
    public var caveats: [String] {
        checks.compactMap { check in
            check.status == .conventionDependent ? check.reason.map { "\(check.statement): \($0)." } : nil
        }
    }

    /// A note for the person reading the answer, or nil when there is nothing to say.
    public var note: String? {
        let lines = corrections + caveats
        return lines.isEmpty ? nil : "Calendar check: " + lines.joined(separator: " ")
    }

    /// A prompt that gives the model the computed values, or nil when nothing was wrong.
    public var feedback: String? {
        let truths = checks.filter { $0.status == .contradicted || $0.status == .impossibleDate }.map(\.truth)
        guard !truths.isEmpty else { return nil }
        return "Some calendar facts in your answer are wrong. These values were computed on the Gregorian calendar:\n"
            + truths.map { "- \($0)" }.joined(separator: "\n")
            + "\nCorrect the answer with these values and keep everything else."
    }
}
