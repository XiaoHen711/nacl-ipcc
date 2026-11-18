import Foundation

/// 写入层的抽象。
///
/// 真机上的实现必须满足三个条件，缺一不可，所以不在本包里：
///   1. 进程以 root 运行（TrollStore 的 `platform-application` 或越狱环境）；
///   2. 能连上 `airtrafficd`（AirTraffic 私有框架 / XPC）；
///   3. 能写 `/System/Library/Carrier Bundles/iPhone/Overlay` 下的登记项。
///
/// 本仓库只提供 `MockCarrierOverlayService`：完整跑通 UI 状态机与日志，
/// 但不触碰系统分区。接入真实实现时，替换 `LockStore` 的 `service` 即可。
@MainActor
protocol CarrierOverlayService {
    func lock(imsi: String,
              bundleID: String,
              onStep: @MainActor (Int) -> Void) async throws -> LockReceipt
    func restore(onStep: @MainActor (Int) -> Void) async throws
}

/// 纯内存实现：按步骤回调，可选在第 4 步失败，用来演示错误分支。
@MainActor
final class MockCarrierOverlayService: CarrierOverlayService {
    /// 0-based 步骤下标；设成 3 就是「写入 Overlay 链接」失败。
    var failureStep: Int?

    private let stepDelay: Duration

    init(stepDelay: Duration = .milliseconds(340)) {
        self.stepDelay = stepDelay
    }

    func lock(imsi: String,
              bundleID: String,
              onStep: @MainActor (Int) -> Void) async throws -> LockReceipt {
        for index in LockFlow.steps.indices {
            try await Task.sleep(for: stepDelay)
            if failureStep == index {
                onStep(index)
                throw NaClError.overlayWriteDenied
            }
            onStep(index)
        }
        return LockReceipt(imsi: imsi, bundleID: bundleID, date: Date())
    }

    func restore(onStep: @MainActor (Int) -> Void) async throws {
        for index in LockFlow.restoreSteps.indices {
            try await Task.sleep(for: stepDelay)
            onStep(index)
        }
    }
}
