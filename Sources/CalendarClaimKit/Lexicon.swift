enum Lexicon {
    static let months: [String: Int] = [
        "january": 1, "jan": 1, "february": 2, "feb": 2, "march": 3, "mar": 3, "april": 4, "apr": 4,
        "may": 5, "june": 6, "jun": 6, "july": 7, "jul": 7, "august": 8, "aug": 8,
        "september": 9, "sep": 9, "sept": 9, "october": 10, "oct": 10, "november": 11, "nov": 11,
        "december": 12, "dec": 12
    ]

    static let weekdays: [String: Weekday] = [
        "monday": .monday, "mon": .monday, "tuesday": .tuesday, "tue": .tuesday, "tues": .tuesday,
        "wednesday": .wednesday, "wed": .wednesday, "thursday": .thursday, "thu": .thursday,
        "thur": .thursday, "thurs": .thursday, "friday": .friday, "fri": .friday,
        "saturday": .saturday, "sat": .saturday, "sunday": .sunday, "sun": .sunday
    ]

    static let units: [String: CalendarUnit] = [
        "day": .day, "days": .day, "week": .week, "weeks": .week, "month": .month, "months": .month,
        "year": .year, "years": .year, "weekday": .businessDay, "weekdays": .businessDay
    ]

    static let numberWords: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
        "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
        "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70,
        "eighty": 80, "ninety": 90
    ]

    static let ordinals: [String: Int] = [
        "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5, "last": -1
    ]

    static let anchors: [String: Anchor] = [
        "today": .today, "today's": .today, "tomorrow": .tomorrow, "tomorrow's": .tomorrow,
        "yesterday": .yesterday, "yesterday's": .yesterday
    ]

    static let qualifiers: [String: Qualifier] = [
        "about": .approximately, "around": .approximately, "roughly": .approximately,
        "approximately": .approximately, "nearly": .approximately, "almost": .approximately,
        "some": .approximately, "over": .over, "under": .under
    ]

    /// "twenty-one" → 21, "seven" → 7.
    static func numberWord(_ word: String) -> Int? {
        if let value = numberWords[word] { return value }
        let parts = word.split(separator: "-").map(String.init)
        guard parts.count == 2, let tens = numberWords[parts[0]], let ones = numberWords[parts[1]],
              tens >= 20, tens % 10 == 0, ones < 10 else { return nil }
        return tens + ones
    }

    /// "17th" → 17, "3rd" → 3; nil for "17" or "17x".
    static func suffixedNumber(_ text: String) -> Int? {
        let digits = text.prefix { $0.isASCII && $0.isNumber }
        let suffix = text.dropFirst(digits.count).lowercased()
        guard !digits.isEmpty, ["st", "nd", "rd", "th"].contains(suffix) else { return nil }
        return Int(digits)
    }

    /// A plain run of digits, at most six of them.
    static func plainNumber(_ text: String) -> Int? {
        guard text.count <= 6, text.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(text)
    }

    /// A four-digit year from 1000 to 2999.
    static func year(_ text: String) -> Int? {
        guard text.count == 4, let value = plainNumber(text), (1000...2999).contains(value) else { return nil }
        return value
    }
}
