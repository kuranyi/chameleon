import SwiftUI

@main
struct ChameleonApp: App {
    @StateObject private var converter = Converter()

    var body: some Scene {
        WindowGroup("Chameleon") {
            ContentView()
                .environmentObject(converter)
                .frame(minWidth: 620, minHeight: 460)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}   // no "New Window"
        }
    }
}
