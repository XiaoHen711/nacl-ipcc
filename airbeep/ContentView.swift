import AirliftFFI
import SwiftUI

@main
struct AirBeepApp: App {
    init() {
        // The configured host stays the primary target; the interface scan
        // adds the current LocalDevVPN/Wi-Fi addresses as extra candidates so
        // the tunnel adapts to the actual network without any probing.
        NetworkStatus.syncTargetHostsToAirlift()
        // Record the environment once, so an exported log explains itself.
        NaClDiagnostics.logStartup()
        Task { await NetworkStatus.selectReachableTarget() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
