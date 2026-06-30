import SwiftUI
import SwiftData

@main
struct HourlyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Client.self, WorkSession.self])
    }
}
