import SwiftUI

@main struct DouglasHillCoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL(perform: { url in
                    Task.detached { 
                        try! await XCallbackURLHandler.shared.handleURL(url)    
                    }
                })
        }
    }
}
