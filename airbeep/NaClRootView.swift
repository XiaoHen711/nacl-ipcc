import SwiftUI

/// 氯化钠分支的 IPCC 产品入口：只做「锁定 IPCC」，不再包含通话提示音功能。
struct NaClRootView: View {
    var body: some View {
        IPCCView()
    }
}

#Preview {
    NaClRootView()
}
