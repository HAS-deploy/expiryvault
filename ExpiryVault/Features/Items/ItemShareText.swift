import Foundation

enum ItemShareText {
    static func summary(for item: TrackedItem, reference: Date = .now) -> String {
        let dateStyle = Date.FormatStyle.dateTime.month(.wide).day().year()
        var lines: [String] = []
        lines.append(item.name)
        lines.append("Category: \(item.category.title)")
        lines.append("Expires: \(item.expirationDate.formatted(dateStyle))")

        let days = item.daysUntilExpiration(reference: reference)
        let countdown: String
        if days < 0 {
            let n = abs(days)
            countdown = "Expired \(n) day\(n == 1 ? "" : "s") ago"
        } else if days == 0 {
            countdown = "Expires today"
        } else {
            countdown = "\(days) day\(days == 1 ? "" : "s") remaining"
        }
        lines.append(countdown)

        if !item.ownerName.isEmpty {
            lines.append("Owner: \(item.ownerName)")
        }
        if !item.referenceCode.isEmpty {
            lines.append("Reference: \(item.referenceCode)")
        }
        if !item.notes.isEmpty {
            lines.append("")
            lines.append("Notes:")
            lines.append(item.notes)
        }
        return lines.joined(separator: "\n")
    }
}
