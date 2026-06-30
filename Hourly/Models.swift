import SwiftData
import Foundation

@Model
final class Client {
    var name: String
    var rate: Double
    var createdAt: Date

    init(name: String, rate: Double) {
        self.name = name
        self.rate = rate
        self.createdAt = Date()
    }
}

@Model
final class WorkSession {
    var clientName: String
    var rate: Double
    var start: Date
    var end: Date?
    var note: String
    var invoiced: Bool

    init(clientName: String, rate: Double, start: Date) {
        self.clientName = clientName
        self.rate = rate
        self.start = start
        self.end = nil
        self.note = ""
        self.invoiced = false
    }

    var hours: Double {
        guard let end else { return 0 }
        return end.timeIntervalSince(start) / 3600
    }

    var amount: Double { hours * rate }
}
