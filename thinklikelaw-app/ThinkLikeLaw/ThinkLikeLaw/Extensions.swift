import Foundation

extension Int {
    func toLocaleString() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension NSNotification.Name {
    static let clearGuestData = NSNotification.Name("clearGuestData")
}
