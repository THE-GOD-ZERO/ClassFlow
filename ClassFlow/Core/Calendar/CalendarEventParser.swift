import Foundation

/// Conservative, deterministic import. Only user-selected calendars are passed to this parser.
public struct CalendarEventParser: Sendable {
    public init() {}

    public func parse(_ event: CalendarEventSnapshot, in range: DayRange,
                      schoolTimeZone: TimeZone) throws -> [ImportedOverride] {
        guard event.isAllDay, event.end > event.start, !event.eventID.isEmpty,
              let classification = classify(event) else { return [] }
        // All-day boundaries are floating civil dates in the source calendar/event zone.
        let zone = event.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? schoolTimeZone
        let first = LocalDay(date: event.start, timeZone: zone)
        let last = LocalDay(date: event.end, timeZone: zone)
        // EventKit all-day end is exclusive. Never spill a holiday into the following day.
        guard first < last else { return [] }
        let start = max(first, range.start)
        let end = min(last, range.endExclusive)
        guard start < end else { return [] }
        let source: OverrideSource = event.role == .school ? .schoolCalendar : .systemCalendar
        let duration = try first.distance(to: last)
        let explicitMappingIsSafe = classification.weekday == nil ||
            (duration == 1 && datesAgree(in: event.title + "\n" + event.notes, with: first))
        let confirmed = classification.confirmed && explicitMappingIsSafe
        let fingerprint = framed([event.title, event.notes, first.key, last.key, event.role.rawValue,
                                  classification.type.rawValue, String(classification.weekday?.rawValue ?? 0)])
        var results = [ImportedOverride]()
        var day = start
        while day < end {
            let rule = try OverrideDefinition(day: day, type: classification.type,
                replacementWeekday: explicitMappingIsSafe ? classification.weekday : nil,
                title: event.title, note: event.notes, source: source, isConfirmed: confirmed)
            // Recurrences share identifiers on some providers: occurrence start + civil day disambiguate them.
            let key = "calendar:" + framed([event.calendarID, event.eventID, first.key, day.key])
            results.append(ImportedOverride(syncKey: key, calendarID: event.calendarID,
                eventID: event.eventID, fingerprint: fingerprint, rule: rule))
            day = try day.adding(days: 1)
        }
        return results
    }

    private struct Classification {
        let type: OverrideType
        let weekday: Weekday?
        let confirmed: Bool
    }

    private func classify(_ event: CalendarEventSnapshot) -> Classification? {
        let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = (title + "\n" + event.notes).replacingOccurrences(of: " ", with: "")
        // Reject negation, speculation and cancellation rather than interpreting fragments out of context.
        let uncertain = ["不", "取消", "无需", "无须", "拟", "可能", "待定", "待通知", "？", "?", "是否", "原定"]
            .contains { text.contains($0) }
        if uncertain { return nil }
        if event.role == .school {
            let mappings = explicitWeekdays(in: text)
            if mappings.count == 1, let weekday = mappings.first {
                return Classification(type: .schoolOverride, weekday: weekday, confirmed: true)
            }
            if mappings.count > 1 {
                return Classification(type: .adjustedWorkday, weekday: nil, confirmed: false)
            }
            if ["正常上课", "按原课表上课", "按当天课表上课"].contains(title) {
                return Classification(type: .schoolOverride, weekday: nil, confirmed: true)
            }
        }
        if ["调休", "上班", "补班", "补课", "调课"].contains(where: { title.contains($0) }) {
            return Classification(type: .adjustedWorkday, weekday: nil, confirmed: false)
        }
        let holidays = ["元旦", "春节", "清明节", "劳动节", "端午节", "中秋节", "国庆节"]
        if holidays.contains(title) || ["放假", "休", "休息", "假期", "今日放假"].contains(title) ||
            holidays.contains(where: { title == $0 + "放假" || title == $0 + "（休）" || title == $0 + "(休)" }) {
            return Classification(type: .holiday, weekday: nil, confirmed: true)
        }
        return nil
    }

    private func explicitWeekdays(in text: String) -> Set<Weekday> {
        // Do not treat a mention of “周一” on its own as a timetable instruction.
        let pattern = "(?:按|执行)(?:星期|周)([一二三四五六日天])课表(?:上课)?|补(?:星期|周)([一二三四五六日天])课程"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let string = text as NSString
        let symbols = ["一", "二", "三", "四", "五", "六", "日"]
        var result = Set<Weekday>()
        for match in regex.matches(in: text, range: NSRange(location: 0, length: string.length)) {
            for index in 1..<match.numberOfRanges where match.range(at: index).location != NSNotFound {
                let symbol = string.substring(with: match.range(at: index))
                if symbol == "天" { result.insert(.sunday) }
                else if let offset = symbols.firstIndex(of: symbol), let weekday = Weekday(rawValue: offset + 1) {
                    result.insert(weekday)
                }
            }
        }
        return result
    }

    private func framed(_ parts: [String]) -> String { parts.map { "\($0.utf8.count):\($0)" }.joined() }

    private func datesAgree(in text: String, with day: LocalDay) -> Bool {
        // An instruction for another explicit date must never be applied to the event's date.
        let pattern = "(?:(\\d{4})年)?(\\d{1,2})月(\\d{1,2})日"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let string = text as NSString
        for match in regex.matches(in: text, range: NSRange(location: 0, length: string.length)) {
            if match.range(at: 1).location != NSNotFound,
               Int(string.substring(with: match.range(at: 1))) != day.year { return false }
            if Int(string.substring(with: match.range(at: 2))) != day.month ||
                Int(string.substring(with: match.range(at: 3))) != day.day { return false }
        }
        // Other date formats are outside this grammar; decline automatic mapping rather than ignoring them.
        return text.range(of: "[0-9]{1,4}[-/.][0-9]{1,2}", options: .regularExpression) == nil
    }
}
