import CalendarClaimKit
import Foundation

/// The demo's clock: Tuesday, October 27, 2026, 06:30 UTC, so every run prints the same thing.
let demoNow = Date(timeIntervalSince1970: 1_793_082_600)
let checker = CalendarChecker(timeZone: .gmt)

func heading(_ number: Int, _ title: String) {
    print("")
    print("── \(number). \(title)")
}

func show(_ report: CalendarReport, question: String? = nil, answer: String) {
    if let question { print("   Q: \(question)") }
    print("   A: \(answer)")
    for check in report.checks {
        let status = check.status.rawValue.padding(toLength: 22, withPad: " ", startingAt: 0)
        let origin = check.claim?.origin == .question ? " (answer to the question)" : ""
        print("   \(status)\(check.statement)\(origin)")
        if check.status != .verified { print("   \(String(repeating: " ", count: 22))→ \(check.truth)") }
        if let reason = check.reason { print("   \(String(repeating: " ", count: 22))  \(reason)") }
    }
    if report.checks.isEmpty { print("   (no calendar claims)") }
    print("   verdict: \(report.verdict.rawValue)")
}

func run(_ answer: String, question: String? = nil, now: Date? = demoNow) {
    show(checker.check(answer: answer, question: question, now: now), question: question, answer: answer)
}
