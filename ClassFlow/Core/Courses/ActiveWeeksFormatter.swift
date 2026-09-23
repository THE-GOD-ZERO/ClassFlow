import Foundation

public enum ActiveWeeksFormatter {
    public static func string(_ weeks: [Int], totalWeeks: Int? = nil) -> String {
        let values = Array(Set(weeks)).sorted()
        guard !values.isEmpty else { return "未选择教学周" }
        if let totalWeeks, totalWeeks > 0 {
            let all = Array(1...totalWeeks)
            if values == all { return "每周（1–\(totalWeeks)周）" }
            if values == all.filter({ $0 % 2 == 1 }) { return "单周" }
            if values == all.filter({ $0 % 2 == 0 }) { return "双周" }
        }
        var parts = [String]()
        var start = values[0]
        var end = start
        for next in values.dropFirst() {
            if next == end + 1 { end = next }
            else {
                parts.append(start == end ? "\(start)" : "\(start)–\(end)")
                start = next; end = next
            }
        }
        parts.append(start == end ? "\(start)" : "\(start)–\(end)")
        return parts.joined(separator: ", ") + "周"
    }
}
