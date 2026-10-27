import CalendarClaimKit

func benchFailures() {
    heading(1, "The failures date-math-bench reported, as answers")
    run(
        "One month after March 31, 2025 is April 31, 2025.",
        question: "What is the date one month after March 31, 2025?"
    )
    run("The day after Monday, July 27, 2026 is July 29, 2026.")
    run("The third Tuesday of March 2026 is March 16.", question: "When is the third Tuesday of March 2026?")
    run(
        "There are 14 business days between Monday, March 2, 2026 and Monday, March 16, 2026.",
        question: "How many business days are there between March 2 and March 16, 2026?"
    )
}

func weekdays() {
    heading(2, "Weekdays of dates")
    run("The review is on Tuesday, March 17, 2026.")
    run("Christmas Day 2026, December 25, 2026, falls on a Thursday.")
    run("July 4, 1976 was not a Monday.")
}

func spans() {
    heading(3, "Spans, and the off-by-one that depends on counting both ends")
    run("From March 3 to June 1, 2026 is 91 days.")
    run("There are 44 days between January 1 and February 14, 2026, or about 6 weeks.")
    run("Between January 1 and February 14, 2026 there are exactly 7 weeks.")
    run("2100 is a leap year, and February 2100 has 29 days.")
}

func relativeToToday() {
    heading(4, "Relative to today")
    run("Today is Tuesday, October 27, 2026.")
    run("There are 59 days until December 25, 2026.")
    run("100 days from today is February 3, 2027.")
    run("Next Friday is November 6.")
    run("Next Friday is November 6.", now: nil)
}

func answersToQuestions() {
    heading(5, "Answers that only make sense with the question")
    run("It was a Sunday.", question: "What day of the week was July 4, 1976?")
    run(
        "Counting from March 3: 28 days to March 31, 30 more to April 30, 31 more to May 31, "
            + "and 1 more lands on June 1, 2026.",
        question: "What date is 90 days after March 3, 2026?"
    )
    run("Yes. 2100 is divisible by 4, so it is a leap year.", question: "Is 2100 a leap year?")
    run("59.", question: "How many days are there until December 25, 2026?")
}

func yearNotStated() {
    heading(6, "A year nobody stated")
    run("March 17 is a Wednesday.", question: "What day of the week is March 17?")
    run("March 17 is a Wednesday.", question: "What day of the week is March 17?", now: nil)
}

func acrossTurns() async {
    heading(7, "A conversation that set the year two turns earlier")
    let session = CalendarSession(checker: checker)
    let turns: [(String, String)] = [
        ("We're planning the 2027 offsite. Which spring months work?", "March or April both work well for an offsite."),
        ("Is March 17 a good day?", "March 17 is a Wednesday, so it avoids the Monday all-hands."),
        ("And the second Monday of April?", "The second Monday of April is April 12.")
    ]
    for (question, answer) in turns {
        let report = await session.review(answer: answer, question: question, now: demoNow)
        show(report, question: question, answer: answer)
        print("   year carried: \(await session.contextYear.map(String.init) ?? "none")")
    }
    let totals = await session.totals
    print("   session: \(totals.turns) turns, \(totals.checks) checks, \(totals.verified) verified, "
        + "\(totals.contradicted) contradicted")
}

func noteAndFeedback() {
    heading(8, "What the person sees, and what goes back to the model")
    let answer = "Your 90-day trial started on March 3, 2026, so it ends 90 days later on June 2, 2026, a Tuesday."
    let report = checker.check(answer: answer, now: demoNow)
    show(report, answer: answer)
    print("   note: \(report.note ?? "-")")
    print("   feedback:")
    for line in (report.feedback ?? "-").split(separator: "\n") { print("   | \(line)") }
}
