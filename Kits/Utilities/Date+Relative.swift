import Foundation

extension Date {
    var relativeTimeDescription: String {
        let now = Date()
        let secondsAgo = now.timeIntervalSince(self)
        
        // Handle very recent times
        if secondsAgo < Constants.TimeFormatting.justNowThreshold {
            return NSLocalizedString("just now", comment: "")
        } else if secondsAgo < Constants.TimeFormatting.secondsThreshold {
            let format = NSLocalizedString("%d sec ago", comment: "")
            return String(format: format, Int(secondsAgo))
        }
        
        // Use RelativeDateTimeFormatter for longer times
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let result = formatter.localizedString(for: self, relativeTo: now)
        
        // Fix weird phrasing like "in 0 sec" -> "just now"
        if result.contains("in 0") || result.contains("0 sec") {
            return NSLocalizedString("just now", comment: "")
        }
        
        return result
    }
}
