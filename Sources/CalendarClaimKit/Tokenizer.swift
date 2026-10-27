struct Token: Sendable, Hashable {
    enum Kind: Sendable, Hashable {
        case word, number, iso, mark, boundary
    }

    let kind: Kind
    let text: String
    let range: Range<String.Index>

    var lower: String { text.lowercased() }
}

/// Splits text into words, numbers (with any ordinal suffix: "17th"), ISO dates, punctuation marks and
/// sentence boundaries. Curly apostrophes become straight ones.
enum Tokenizer {
    static func tokens(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            let end: String.Index
            let kind: Token.Kind
            if character.isLetter {
                end = wordEnd(text, from: index)
                kind = .word
            } else if character.isASCII && character.isNumber {
                (end, kind) = numberEnd(text, from: index)
            } else if character.isNewline || ".!?;".contains(character) {
                end = text.index(after: index)
                kind = .boundary
            } else if character.isWhitespace {
                index = text.index(after: index)
                continue
            } else {
                end = text.index(after: index)
                kind = .mark
            }
            let raw = String(text[index..<end]).replacingOccurrences(of: "\u{2019}", with: "'")
            tokens.append(Token(kind: kind, text: raw, range: index..<end))
            index = end
        }
        return tokens
    }

    /// Letters, joined by an apostrophe or a hyphen when a letter follows: "isn't", "twenty-one".
    static func wordEnd(_ text: String, from start: String.Index) -> String.Index {
        var end = text.index(after: start)
        while end < text.endIndex {
            if text[end].isLetter {
                end = text.index(after: end)
            } else if "'\u{2019}-".contains(text[end]), letterFollows(text, end) {
                end = text.index(after: end)
            } else {
                break
            }
        }
        return end
    }

    /// Digits and any letters stuck to them ("17th"). Four digits, a hyphen, digits, a hyphen and digits
    /// make one ISO date token. A decimal ("6.5") is one word token, so its point does not end a sentence.
    static func numberEnd(_ text: String, from start: String.Index) -> (String.Index, Token.Kind) {
        let digitsEnd = digitRun(text, from: start)
        if text.distance(from: start, to: digitsEnd) == 4, let iso = isoEnd(text, from: digitsEnd) {
            return (iso, .iso)
        }
        if digitsEnd < text.endIndex, text[digitsEnd] == "." {
            let fraction = text.index(after: digitsEnd)
            let fractionEnd = digitRun(text, from: fraction)
            if fractionEnd > fraction { return (fractionEnd, .word) }
        }
        var end = digitsEnd
        while end < text.endIndex, text[end].isLetter { end = text.index(after: end) }
        return (end, .number)
    }

    static func letterFollows(_ text: String, _ index: String.Index) -> Bool {
        let next = text.index(after: index)
        return next < text.endIndex && text[next].isLetter
    }

    static func digitRun(_ text: String, from start: String.Index) -> String.Index {
        var end = start
        while end < text.endIndex, text[end].isASCII, text[end].isNumber { end = text.index(after: end) }
        return end
    }

    /// "-03-17" after the year: one or two digits, a hyphen, one or two digits.
    static func isoEnd(_ text: String, from yearEnd: String.Index) -> String.Index? {
        var cursor = yearEnd
        for _ in 0..<2 {
            guard cursor < text.endIndex, text[cursor] == "-" else { return nil }
            let digitsStart = text.index(after: cursor)
            let digitsEnd = digitRun(text, from: digitsStart)
            let length = text.distance(from: digitsStart, to: digitsEnd)
            guard (1...2).contains(length) else { return nil }
            cursor = digitsEnd
        }
        return cursor
    }
}
