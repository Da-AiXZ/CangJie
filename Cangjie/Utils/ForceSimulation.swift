//
//  ForceSimulation.swift
//  Cangjie
//
//  Fruchterman-Reingold 力导向布局算法纯 Swift 实现。
//  用于知识图谱、人物关系、地点关系图。
//  输入节点+边+画布尺寸，迭代计算节点位置，支持 repulsion/attraction/cooling。
//  用 async/await + Task 做后台迭代，@Published 暴露当前坐标供 View 渲染。
//

import Foundation
import CoreGraphics
import Combine

/// 力导向布局模拟器
///
/// Fruchterman-Reingold 算法：
/// - 每对节点间存在斥力（repulsion），正比于 k²/d
/// - 每条边存在引力（attraction），正比于 d²/k
/// - k = C * sqrt(area / n) 是理想距离
/// - 温度随迭代递减（cooling），控制位移幅度
final class ForceSimulation: ObservableObject {

    // MARK: - 数据模型

    /// 图节点
    struct GraphNode: Identifiable, Hashable {
        let id: String
        var label: String
        var type: String  // 实体类型（用于着色）
    }

    /// 图边
    struct GraphEdge: Identifiable, Hashable {
        let id: String
        let source: String
        let target: String
        var label: String
    }

    /// 节点位置
    struct NodePosition: Identifiable {
        let id: String
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat  // 速度 x
        var vy: CGFloat  // 速度 y
    }

    // MARK: - 配置

    struct Config {
        /// 理想距离系数
        var k: CGFloat = 80
        /// 斥力强度倍数
        var repulsionScale: CGFloat = 1.0
        /// 引力强度倍数
        var attractionScale: CGFloat = 1.0
        /// 初始温度
        var initialTemperature: CGFloat = 30
        /// 冷却系数（每轮温度乘以此值）
        var coolingFactor: CGFloat = 0.95
        /// 最小温度（低于此值停止）
        var minTemperature: CGFloat = 0.5
        /// 最大迭代次数
        var maxIterations: Int = 300
        /// 画布宽度
        var canvasWidth: CGFloat = 800
        /// 画布高度
        var canvasHeight: CGFloat = 600
        /// 边距
        var margin: CGFloat = 50
        /// 是否启用重力（向中心拉）
        var gravity: CGFloat = 0.1
        /// 是否启用防重叠
        var preventOverlap: Bool = true
        /// 节点半径（用于防重叠）
        var nodeRadius: CGFloat = 20

        static let `default` = Config()
    }

    // MARK: - 属性

    /// 当前节点位置（@Published 供 View 渲染）
    @Published private(set) var positions: [NodePosition] = []

    /// 当前迭代次数
    @Published private(set) var iteration: Int = 0

    /// 是否正在运行
    @Published private(set) var isRunning: Bool = false

    /// 图数据
    private var nodes: [GraphNode] = []
    private var edges: [GraphEdge] = []
    private var config: Config

    /// 位置索引（快速查找）
    private var positionMap: [String: Int] = [:]

    /// 当前温度
    private var temperature: CGFloat = 0

    /// 后台任务
    private var simulationTask: Task<Void, Never>?

    // MARK: - 初始化

    init(config: Config = .default) {
        self.config = config
    }

    // MARK: - 设置图数据

    /// 设置图数据并初始化位置
    /// - Parameters:
    ///   - nodes: 节点列表
    ///   - edges: 边列表
    func setGraph(nodes: [GraphNode], edges: [GraphEdge]) {
        self.nodes = nodes
        self.edges = edges
        initializePositions()
    }

    /// 更新配置
    /// - Parameter config: 新配置
    func updateConfig(_ config: Config) {
        self.config = config
    }

    // MARK: - 位置初始化

    /// 初始化节点位置（圆形分布）
    private func initializePositions() {
        positions.removeAll()
        positionMap.removeAll()

        let centerX = config.canvasWidth / 2
        let centerY = config.canvasHeight / 2
        let radius = min(config.canvasWidth, config.canvasHeight) / 3

        for (index, node) in nodes.enumerated() {
            let angle = CGFloat(index) / CGFloat(max(nodes.count, 1)) * 2 * .pi
            let x = centerX + radius * cos(angle)
            let y = centerY + radius * sin(angle)

            positionMap[node.id] = index
            positions.append(NodePosition(id: node.id, x: x, y: y, vx: 0, vy: 0))
        }
    }

    // MARK: - 模拟控制

    /// 启动模拟（后台 Task 迭代）
    func start() {
        guard !isRunning else { return }
        guard !nodes.isEmpty else { return }

        isRunning = true
        temperature = config.initialTemperature
        iteration = 0

        simulationTask = Task { [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled && self.iteration < self.config.maxIterations {
                self.step()

                // 冷却
                self.temperature *= self.config.coolingFactor
                if self.temperature < self.config.minTemperature {
                    break
                }

                // 每 10 次迭代更新一次 UI（减少渲染压力）
                if self.iteration % 10 == 0 {
                    await MainActor.run {
                        self.objectWillChange.send()
                    }
                }

                // 短暂休眠让出主线程
                try? await Task.sleep(nanoseconds: 16_000_000) // ~60fps
            }

            await MainActor.run {
                self.isRunning = false
                self.objectWillChange.send()
            }
        }
    }

    /// 停止模拟
    func stop() {
        simulationTask?.cancel()
        simulationTask = nil
        isRunning = false
    }

    /// 重置并重新开始
    func restart() {
        stop()
        initializePositions()
        start()
    }

    // MARK: - 单步迭代

    /// 执行一次力计算迭代
    private func step() {
        iteration += 1

        var forces = Array(repeating: (fx: CGFloat(0), fy: CGFloat(0)), count: positions.count)

        // 计算斥力（每对节点）
        for i in 0..<positions.count {
            for j in (i + 1)..<positions.count {
                let dx = positions[i].x - positions[j].x
                let dy = positions[i].y - positions[j].y
                let distance = max(sqrt(dx * dx + dy * dy), 0.01)

                let repulsionForce = (config.k * config.k * config.repulsionScale) / distance
                let fx = (dx / distance) * repulsionForce
                let fy = (dy / distance) * repulsionForce

                forces[i].fx += fx
                forces[i].fy += fy
                forces[j].fx -= fx
                forces[j].fy -= fy
            }
        }

        // 计算引力（每条边）
        for edge in edges {
            guard let sourceIdx = positionMap[edge.source],
                  let targetIdx = positionMap[edge.target] else { continue }

            let dx = positions[sourceIdx].x - positions[targetIdx].x
            let dy = positions[sourceIdx].y - positions[targetIdx].y
            let distance = max(sqrt(dx * dx + dy * dy), 0.01)

            let attractionForce = (distance * distance / config.k) * config.attractionScale
            let fx = (dx / distance) * attractionForce
            let fy = (dy / distance) * attractionForce

            forces[sourceIdx].fx -= fx
            forces[sourceIdx].fy -= fy
            forces[targetIdx].fx += fx
            forces[targetIdx].fy += fy
        }

        // 计算重力（向中心拉）
        let centerX = config.canvasWidth / 2
        let centerY = config.canvasHeight / 2
        for i in 0..<positions.count {
            let dx = centerX - positions[i].x
            let dy = centerY - positions[i].y
            forces[i].fx += dx * config.gravity
            forces[i].fy += dy * config.gravity
        }

        // 应用力（带温度限制）
        for i in 0..<positions.count {
            let fx = forces[i].fx
            let fy = forces[i].fy
            let forceMag = max(sqrt(fx * fx + fy * fy), 0.01)

            // 限制最大位移为温度
            let limitedFx = (fx / forceMag) * min(forceMag, temperature)
            let limitedFy = (fy / forceMag) * min(forceMag, temperature)

            positions[i].x += limitedFx
            positions[i].y += limitedFy

            // 边界约束
            let margin = config.margin
            positions[i].x = max(margin, min(config.canvasWidth - margin, positions[i].x))
            positions[i].y = max(margin, min(config.canvasHeight - margin, positions[i].y))

            // 防重叠
            if config.preventOverlap {
                for j in 0..<positions.count where i != j {
                    let dx = positions[i].x - positions[j].x
                    let dy = positions[i].y - positions[j].y
                    let dist = sqrt(dx * dx + dy * dy)
                    let minDist = config.nodeRadius * 2 + 5
                    if dist < minDist && dist > 0.01 {
                        let push = (minDist - dist) / 2
                        positions[i].x += (dx / dist) * push
                        positions[i].y += (dy / dist) * push
                        positions[j].x -= (dx / dist) * push
                        positions[j].y -= (dy / dist) * push
                    }
                }
            }
        }
    }

    // MARK: - 查询

    /// 获取指定节点位置
    /// - Parameter id: 节点 ID
    /// - Returns: 位置坐标
    func position(for id: String) -> CGPoint? {
        guard let index = positionMap[id] else { return nil }
        return CGPoint(x: positions[index].x, y: positions[index].y)
    }

    /// 命中测试：查找指定坐标处的节点
    /// - Parameter point: 点击坐标
    /// - Returns: 命中的节点 ID，无则 nil
    func hitTest(point: CGPoint) -> String? {
        for position in positions {
            let dx = position.x - point.x
            let dy = position.y - point.y
            if sqrt(dx * dx + dy * dy) <= config.nodeRadius + 5 {
                return position.id
            }
        }
        return nil
    }

    /// 获取边的两端坐标
    /// - Parameter edge: 边
    /// - Returns: (起点, 终点)
    func edgeEndpoints(_ edge: GraphEdge) -> (CGPoint, CGPoint)? {
        guard let sourcePos = position(for: edge.source),
              let targetPos = position(for: edge.target) else { return nil }
        return (sourcePos, targetPos)
    }

    // MARK: - 手动拖拽

    /// 固定节点位置（拖拽时使用）
    /// - Parameters:
    ///   - id: 节点 ID
    ///   - position: 新位置
    func pinNode(_ id: String, to position: CGPoint) {
        guard let index = positionMap[id] else { return }
        positions[index].x = position.x
        positions[index].y = position.y
        positions[index].vx = 0
        positions[index].vy = 0
    }
}
