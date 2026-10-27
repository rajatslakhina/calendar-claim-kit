/// Reads a text into clauses of pieces and gives every date a year: the text's own when it states one
/// nearby, then the conversation's, then today's. Where the year came from is kept on the date.
struct PieceReader: Sendable {
    let context: YearContext

    func read(_ text: String) -> TextReading {
        let tokens = Tokenizer.tokens(text)
        let scanner = PieceScanner(tokens: tokens)
        var clauses: [Clause] = []
        var current: [Piece] = []
        var firstToken = 0
        var index = 0
        func close(through last: Int) {
            if !current.isEmpty {
                let range = tokens[firstToken].range.lowerBound..<tokens[last].range.upperBound
                clauses.append(Clause(pieces: current, quote: String(text[range])))
            }
            current = []
        }
        while index < tokens.count {
            let (piece, next) = scanner.piece(at: index)
            if piece == .boundary {
                close(through: index)
            } else {
                if current.isEmpty { firstToken = index }
                current.append(piece)
            }
            index = next
        }
        close(through: tokens.count - 1)
        return fillYears(clauses)
    }

    func fillYears(_ clauses: [Clause]) -> TextReading {
        var filled: [Clause] = []
        var statedYears: [Int] = []
        var lastYear: Int?
        for var clause in clauses {
            let stated = clause.pieces.compactMap(\.statedYear)
            for index in clause.pieces.indices {
                clause.pieces[index] = resolve(clause.pieces[index], at: index, in: clause.pieces, textYear: lastYear)
                if yearSource(of: clause.pieces[index]) == .today { clause.guessedYear = true }
            }
            statedYears += stated
            lastYear = stated.last ?? lastYear
            filled.append(clause)
        }
        return TextReading(clauses: filled, statedYears: statedYears)
    }

    func resolve(_ piece: Piece, at index: Int, in pieces: [Piece], textYear: Int?) -> Piece {
        switch piece {
        case .date(var mention) where mention.year == nil:
            let monthDay = (mention.month, mention.day)
            (mention.year, mention.yearSource) = year(for: index, in: pieces, textYear: textYear, monthDay: monthDay)
            return .date(mention)
        case .month(var mention) where mention.year == nil:
            (mention.year, mention.yearSource) = year(for: index, in: pieces, textYear: textYear, monthDay: nil)
            return .month(mention)
        default:
            return piece
        }
    }

    /// The nearest stated year before the date in its clause; else the first after it ("between
    /// December 20 and January 5, 2027" gives December 20 the year before); else the text's last year
    /// so far; else the conversation's; else today's.
    func year(for index: Int, in pieces: [Piece], textYear: Int?, monthDay: (Int, Int)?) -> (Int?, YearSource) {
        if let before = pieces[..<index].last(where: { $0.statedYear != nil })?.statedYear { return (before, .text) }
        if let after = pieces[(index + 1)...].first(where: { $0.statedYear != nil }), let year = after.statedYear {
            if let monthDay, case .date(let later) = after, (monthDay.0, monthDay.1) > (later.month, later.day) {
                return (year - 1, .text)
            }
            return (year, .text)
        }
        if let textYear { return (textYear, .text) }
        if let year = context.contextYear { return (year, .context) }
        if let year = context.todayYear { return (year, .today) }
        return (nil, .missing)
    }

    func yearSource(of piece: Piece) -> YearSource? {
        switch piece {
        case .date(let mention): mention.yearSource
        case .month(let mention): mention.yearSource
        default: nil
        }
    }
}
