import SwiftUI

struct RootView: View {
    @StateObject private var store = LockStore()

    var body: some View {
        TabView {
            LockView()
                .tabItem { Label("锁定", systemImage: "lock.shield") }
            LogsView()
                .tabItem { Label("日志", systemImage: "list.bullet.rectangle") }
            AboutView()
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .tint(Theme.accent)
        .environmentObject(store)
        .preferredColorScheme(.dark)
    }
}
