import SwiftUI

/// 氯化钠分支的 IPCC 产品入口。界面沿用 AirBeep 的卡片式排版：
/// 首个标签页是锁定主页面，第二个标签页是说明页，不再包含通话提示音功能。
struct NaClRootView: View {
    var body: some View {
        TabView {
            NaClLockView()
                .tabItem { Label("锁定 IPCC", systemImage: "antenna.radiowaves.left.and.right") }
            NavigationStack {
                NaClAboutContent()
                    .navigationTitle("关于 NaCl IPCC")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .tint(NaClTheme.accent)
    }
}

#Preview {
    NaClRootView()
}
