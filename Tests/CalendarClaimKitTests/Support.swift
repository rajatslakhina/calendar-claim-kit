@testable import CalendarClaimKit
import Foundation

/// Tuesday, October 27, 2026, 06:30 UTC.
let october27 = Date(timeIntervalSince1970: 1_793_082_600)
let utcChecker = CalendarChecker(timeZone: .gmt)

func date(_ year: Int, _ month: Int, _ day: Int) -> CivilDate {
    CivilDate(valid: year, month, day)
}

func check(_ answer: String, question: String? = nil, now: Date? = october27, contextYear: Int? = nil) -> CalendarReport {
    utcChecker.check(answer: answer, question: question, now: now, contextYear: contextYear)
}

func statuses(_ report: CalendarReport) -> [CheckStatus] { report.checks.map(\.status) }

func read(_ text: String, context: Int? = nil, today: Int? = nil) -> TextReading {
    PieceReader(context: YearContext(contextYear: context, todayYear: today)).read(text)
}

func pieces(_ text: String) -> [Piece] { read(text).pieces }

func claims(_ text: String, today: Int? = 2026) -> [CalendarClaim] {
    ClaimReader().claims(in: read(text, today: today))
}

func view(_ text: String) -> ClauseView { ClauseView(pieces: pieces(text)) }

func mention(_ month: Int, _ day: Int, _ year: Int?) -> DateMention {
    DateMention(month: month, day: day, year: year)
}
