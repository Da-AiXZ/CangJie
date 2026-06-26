//
//  AdaptivePolling.swift
//  Cangjie
//
//  自适应轮询工具，对齐原版 composables/useAdaptivePolling.ts。
//  D-3/Q5：pauseWhenHidden 选项 + Store 层 NotificationCenter 监听 UIApplication 生命周期。
//

import Foundation
import UIKit

// MARK: - 自适应轮询器

/// 自适应轮询器，对齐原版 composables/useAdaptivePolling.ts。
///
/// D-3/Q5 决策：Store 层用 NotificationCenter 监听 UIApplication 生命周期，
/// 不依赖 View 的 @Environment(\.scenePhase)，Store 自治。
///
/// 支持 pauseWhenHidden 选项：当 App 进入后台时暂停轮询，回到前台时恢复。
final class AdaptivePolling {

    /// 轮询任务闭包
    private let task: () async -> Void

    /// 轮询延迟（毫秒），可以是固定值或计算函数
    private let delayMs: () -> Int

    /// 是否在 App 隐藏时暂停
    private let pauseWhenHidden: Bool

    /// 是否继续轮询的条件检查
    private let shouldContinue: (() -> Bool)?

    /// 错误回调
    private let onError: ((Error) -> Void)?

    /// 当前轮询 Task
    private var pollTask: Task<Void, Never>?

    /// 是否正在轮询
    private(set) var isPolling: Bool = false

    /// 是否正在执行
    private(set) var isExecuting: Bool = false

    /// NotificationCenter 观察者 token
    private var resignObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?

    /// 初始化
    /// - Parameters:
    ///   - task: 轮询任务
    ///   - delayMs: 轮询延迟（毫秒）
    ///   - pauseWhenHidden: 是否在 App 进入后台时暂停（D-3）
    ///   - shouldContinue: 是否继续轮询的条件
    ///   - onError: 错误回调
    init(
        task: @escaping () async -> Void,
        delayMs: @autoclosure @escaping () -> Int,
        pauseWhenHidden: Bool = false,
        shouldContinue: (() -> Bool)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        self.task = task
        self.delayMs = delayMs
        self.pauseWhenHidden = pauseWhenHidden
        self.shouldContinue = shouldContinue
        self.onError = onError
    }

    deinit {
        stop()
    }

    // MARK: - 启动/停止

    /// 启动轮询
    /// - Parameter immediate: 是否立即执行一次
    func start(immediate: Bool = false) {
        guard !isPolling else { return }
        isPolling = true

        if pauseWhenHidden {
            registerLifecycleObservers()
        }

        pollTask?.cancel()

        if immediate {
            pollTask = Task { [weak self] in
                await self?.execute()
                self?.scheduleNext()
            }
        } else {
            scheduleNext()
        }
    }

    /// 停止轮询
    func stop() {
        pollTask?.cancel()
        pollTask = nil
        isPolling = false
        unregisterLifecycleObservers()
    }

    /// 重启轮询
    /// - Parameter immediate: 是否立即执行一次
    func restart(immediate: Bool = false) {
        stop()
        start(immediate: immediate)
    }

    // MARK: - 内部调度

    /// 调度下一次轮询
    private func scheduleNext() {
        guard isPolling else { return }
        if let shouldContinue = shouldContinue, !shouldContinue() { return }
        if pauseWhenHidden && isAppHidden() { return }

        let delay = max(0, delayMs())

        pollTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
            guard let self = self else { return }
            guard self.isPolling else { return }
            await self.execute()
            self.scheduleNext()
        }
    }

    /// 执行任务
    private func execute() async {
        guard !isExecuting else { return }
        isExecuting = true
        do {
            await task()
        } catch {
            onError?(error)
        }
        isExecuting = false
    }

    // MARK: - App 生命周期监听（D-3/Q5）

    /// 注册 UIApplication 生命周期通知
    private func registerLifecycleObservers() {
        resignObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // App 进入后台 → 暂停轮询（清除定时器）
            self?.pollTask?.cancel()
            self?.pollTask = nil
        }

        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // App 回到前台 → 恢复轮询
            guard let self = self, self.isPolling else { return }
            self.scheduleNext()
        }
    }

    /// 注销通知观察者
    private func unregisterLifecycleObservers() {
        if let observer = resignObserver {
            NotificationCenter.default.removeObserver(observer)
            resignObserver = nil
        }
        if let observer = activeObserver {
            NotificationCenter.default.removeObserver(observer)
            activeObserver = nil
        }
    }

    /// 判断 App 是否在后台（非活跃状态）
    private func isAppHidden() -> Bool {
        return UIApplication.shared.applicationState != .active
    }
}
