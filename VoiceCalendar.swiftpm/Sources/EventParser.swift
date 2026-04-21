import Foundation

struct ParsedEvent {
    let title: String
    let date: Date
}

struct EventParser {
    static func parse(_ text: String, locale: Locale) -> ParsedEvent? {
        guard let date = extractDate(from: text, locale: locale) else { return nil }
        let title = extractTitle(from: text, locale: locale)
        return ParsedEvent(title: title, date: date)
    }

    // MARK: - Date extraction

    private static func extractDate(from text: String, locale: Locale) -> Date? {
        let lower = text.lowercased()
        let isNL = locale.identifier.hasPrefix("nl")
        let cal = Calendar.current
        let now = Date()

        // Relative day keywords
        if isNL {
            if lower.contains("overmorgen") {
                return setTime(from: lower, base: cal.date(byAdding: .day, value: 2, to: now)!)
            }
            if lower.contains("morgen") {
                return setTime(from: lower, base: cal.date(byAdding: .day, value: 1, to: now)!)
            }
            if lower.contains("vandaag") {
                return setTime(from: lower, base: now)
            }
            let days = ["maandag": 2, "dinsdag": 3, "woensdag": 4,
                        "donderdag": 5, "vrijdag": 6, "zaterdag": 7, "zondag": 1]
            for (name, weekday) in days where lower.contains(name) {
                if let d = nextWeekday(weekday) { return setTime(from: lower, base: d) }
            }
        } else {
            if lower.contains("tomorrow") {
                return setTime(from: lower, base: cal.date(byAdding: .day, value: 1, to: now)!)
            }
            if lower.contains("today") {
                return setTime(from: lower, base: now)
            }
            if lower.contains("day after tomorrow") || lower.contains("overmorrow") {
                return setTime(from: lower, base: cal.date(byAdding: .day, value: 2, to: now)!)
            }
            let days = ["monday": 2, "tuesday": 3, "wednesday": 4,
                        "thursday": 5, "friday": 6, "saturday": 7, "sunday": 1]
            for (name, weekday) in days where lower.contains(name) {
                if let d = nextWeekday(weekday) { return setTime(from: lower, base: d) }
            }
        }

        // NSDataDetector as fallback (handles "21 april", "April 21", "21/04" etc.)
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = detector.firstMatch(in: text, range: range), let date = match.date {
                return setTime(from: lower, base: date)
            }
        }

        return nil
    }

    // MARK: - Time extraction

    private static func setTime(from lower: String, base: Date) -> Date {
        var hour = 9
        var minute = 0

        // "14:30" or "9:00"
        if let m = lower.range(of: #"\b(\d{1,2}):(\d{2})\b"#, options: .regularExpression) {
            let parts = lower[m].split(separator: ":")
            hour = Int(parts[0]) ?? 9
            minute = Int(parts[1]) ?? 0
        }
        // "om 10 uur" / "om 14" / "at 3"
        else if let m = lower.range(of: #"(?:om|at)\s+(\d{1,2})(?:\s*(?:uur|u|h))?"#, options: .regularExpression) {
            let sub = String(lower[m])
            if let nm = sub.range(of: #"\d{1,2}"#, options: .regularExpression) {
                hour = Int(sub[nm]) ?? 9
            }
        }
        // "3pm" / "10am"
        else if let m = lower.range(of: #"(\d{1,2})\s*(am|pm)"#, options: .regularExpression) {
            let sub = String(lower[m])
            if let nm = sub.range(of: #"\d{1,2}"#, options: .regularExpression) {
                var h = Int(sub[nm]) ?? 9
                if sub.contains("pm") && h < 12 { h += 12 }
                if sub.contains("am") && h == 12 { h = 0 }
                hour = h
            }
        }

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: base)
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? base
    }

    // MARK: - Next weekday helper

    private static func nextWeekday(_ weekday: Int) -> Date? {
        let cal = Calendar.current
        let today = cal.component(.weekday, from: Date())
        var diff = weekday - today
        if diff <= 0 { diff += 7 }
        return cal.date(byAdding: .day, value: diff, to: Date())
    }

    // MARK: - Title extraction

    private static func extractTitle(from text: String, locale: Locale) -> String {
        var result = text

        let patterns: [String] = [
            // Time patterns
            #"\b\d{1,2}:\d{2}\b"#,
            #"\b\d{1,2}\s*(am|pm)\b"#,
            #"\b(?:om|at)\s+\d{1,2}(?::\d{2})?\s*(?:uur|u|h)?\b"#,
            // Dutch date words
            #"\b(overmorgen|morgen|vandaag)\b"#,
            #"\b(maandag|dinsdag|woensdag|donderdag|vrijdag|zaterdag|zondag)\b"#,
            #"\b(volgende\s+week|deze\s+week)\b"#,
            // English date words
            #"\b(tomorrow|today|day after tomorrow)\b"#,
            #"\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b"#,
            #"\b(next\s+week|this\s+week)\b"#,
        ]

        for pattern in patterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        result = result
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return result.isEmpty ? (locale.identifier.hasPrefix("nl") ? "Afspraak" : "Event") : result
    }
}
