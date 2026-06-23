//
//  SugiyamaLayout.swift
//  Cangjie
//
//  Sugiyama 分层布局算法纯 Swift 实现（用于 DAG 可视化）。
//  包含：cycle breaking、layer assignment、crossing reduction、coordinate assignment。
//  对齐 vue-flow dagre 布局的 TB（自上而下）方向和间距参数。
//

import Foundation
import CoreGraphics

/// Sugiyama 分层布局算法
///
/// 四阶段流水线：
/// 1. Cycle Breaking — 反转反馈边，使图变为 DAG
/// 2. Layer Assignment — 拓扑排序分配层级
/// 3. Crossing Reduction — 交换同层节点顺序减少交叉
/// 4. Coordinate Assignment — 计算 x/y 坐标
struct SugiyamaLayout {

    // MARK: - 配置

    /// 布局方向
    enum Direction {
        case topToBottom  // TB：自上而下
        case leftToRight  // LR：从左到右
    }

    /// 布局参数
    struct Config {
        /// 布局方向
        var direction: Direction = .topToBottom
        /// 节点间距（水平）
        var nodeSpacingX: CGFloat = 120
        /// 节点间距（垂直，层间距）
        var nodeSpacingY: CGFloat = 100
        /// 层间距倍数
        var layerMultiplier: CGFloat = 1.2
        /// 节点默认宽度
        var nodeWidth: CGFloat = 160
        /// 节点默认高度
        var nodeHeight: CGFloat = 60
        /// 边间距
        var edgeSpacing: CGFloat = 40
        /// 画布边距
        var margin: CGFloat = 40

        static let `default` = Config()
    }

    // MARK: - 输入/输出

    /// 布局输入节点
    struct LayoutNode {
        let id: String
        var width: CGFloat
        var height: CGFloat
    }

    /// 布局输入边
    struct LayoutEdge {
        let id: String
        let source: String
        let target: String
    }

    /// 布局结果：节点坐标
    struct PositionedNode {
        let id: String
        let x: CGFloat
        let y: CGFloat
        let layer: Int
    }

    /// 布局结果：边路径点
    struct PositionedEdge {
        let id: String
        let source: String
        let target: String
        let points: [CGPoint]
    }

    /// 完整布局结果
    struct LayoutResult {
        let nodes: [PositionedNode]
        let edges: [PositionedEdge]
        let totalWidth: CGFloat
        let totalHeight: CGFloat
    }

    // MARK: - 执行布局

    /// 执行完整的 Sugiyama 布局
    /// - Parameters:
    ///   - nodes: 节点列表
    ///   - edges: 边列表
    ///   - config: 布局配置
    /// - Returns: 布局结果
    static func layout(nodes: [LayoutNode], edges: [LayoutEdge], config: Config = .default) -> LayoutResult {
        guard !nodes.isEmpty else {
            return LayoutResult(nodes: [], edges: [], totalWidth: 0, totalHeight: 0)
        }

        // 构建邻接表
        var adjacency: [String: [String]] = [:]
        var reverseAdjacency: [String: [String]] = [:]
        var nodeMap: [String: LayoutNode] = [:]

        for node in nodes {
            adjacency[node.id] = []
            reverseAdjacency[node.id] = []
            nodeMap[node.id] = node
        }

        // Phase 1: Cycle Breaking
        let (acyclicEdges, reversedEdges) = breakCycles(nodes: nodes, edges: edges, adjacency: &adjacency)

        // 重建邻接表（无环）
        for edge in acyclicEdges {
            adjacency[edge.source]?.append(edge.target)
            reverseAdjacency[edge.target]?.append(edge.source)
        }

        // Phase 2: Layer Assignment (最长路径法)
        var layers = assignLayers(nodes: nodes, adjacency: adjacency, reverseAdjacency: reverseAdjacency)

        // Phase 3: Crossing Reduction (中位数法)
        layers = reduceCrossings(layers: &layers, adjacency: adjacency, reverseAdjacency: reverseAdjacency)

        // Phase 4: Coordinate Assignment
        let result = assignCoordinates(
            layers: layers,
            nodeMap: nodeMap,
            edges: acyclicEdges,
            config: config
        )

        return result
    }

    // MARK: - Phase 1: Cycle Breaking

    /// 贪心环打破：按入度-出度排序，反转反馈边
    private static func breakCycles(
        nodes: [LayoutNode],
        edges: [LayoutEdge],
        adjacency: inout [String: [String]]
    ) -> (acyclic: [LayoutEdge], reversed: [LayoutEdge]) {
        // 使用贪心算法：按 (outDegree - inDegree) 降序排列节点
        // 对于每条边，如果 source 在 target 之后，则反转

        var inDegree: [String: Int] = [:]
        var outDegree: [String: Int] = [:]
        for node in nodes {
            inDegree[node.id] = 0
            outDegree[node.id] = 0
        }
        for edge in edges {
            outDegree[edge.source, default: 0] += 1
            inDegree[edge.target, default: 0] += 1
        }

        // 按 (outDeg - inDeg) 降序排序
        let sortedNodes = nodes.sorted { a, b in
            let scoreA = (outDegree[a.id] ?? 0) - (inDegree[a.id] ?? 0)
            let scoreB = (outDegree[b.id] ?? 0) - (inDegree[b.id] ?? 0)
            return scoreA > scoreB
        }

        // 节点顺序（用于判断边方向）
        var nodeOrder: [String: Int] = [:]
        for (index, node) in sortedNodes.enumerated() {
            nodeOrder[node.id] = index
        }

        var acyclic: [LayoutEdge] = []
        var reversed: [LayoutEdge] = []

        for edge in edges {
            let sourceOrder = nodeOrder[edge.source] ?? 0
            let targetOrder = nodeOrder[edge.target] ?? 0

            if sourceOrder <= targetOrder {
                // 正常方向
                acyclic.append(edge)
            } else {
                // 反转边
                reversed.append(edge)
                acyclic.append(LayoutEdge(id: edge.id, source: edge.target, target: edge.source))
            }
        }

        return (acyclic, reversed)
    }

    // MARK: - Phase 2: Layer Assignment

    /// 最长路径法分配层级
    private static func assignLayers(
        nodes: [LayoutNode],
        adjacency: [String: [String]],
        reverseAdjacency: [String: [String]]
    ) -> [[String]] {
        var layer: [String: Int] = [:]
        for node in nodes {
            layer[node.id] = 0
        }

        // 拓扑排序
        var visited: Set<String> = []
        var queue: [String] = []

        // 找入度为 0 的节点
        for node in nodes {
            if (reverseAdjacency[node.id]?.isEmpty ?? true) {
                queue.append(node.id)
            }
        }

        // BFS 分层
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if visited.contains(current) { continue }
            visited.insert(current)

            let currentLayer = layer[current] ?? 0
            for neighbor in adjacency[current] ?? [] {
                let neighborLayer = layer[neighbor] ?? 0
                layer[neighbor] = max(neighborLayer, currentLayer + 1)
                queue.append(neighbor)
            }
        }

        // 按层级分组
        let maxLayer = layer.values.max() ?? 0
        var layers: [[String]] = Array(repeating: [], count: maxLayer + 1)

        for node in nodes {
            let l = layer[node.id] ?? 0
            layers[l].append(node.id)
        }

        return layers
    }

    // MARK: - Phase 3: Crossing Reduction

    /// 中位数法减少交叉：对每层的节点按上层中位数排序
    private static func reduceCrossings(
        layers: inout [[String]],
        adjacency: [String: [String]],
        reverseAdjacency: [String: [String]]
    ) -> [[String]] {
        // 从第二层开始，逐层向下排序
        for i in 1..<layers.count {
            let upperLayer = layers[i - 1]
            let upperPosition: [String: Int] = Dictionary(uniqueKeysWithValues: upperLayer.enumerated().map { ($1, $0) })

            // 计算当前层每个节点的中位数
            layers[i].sort { a, b in
                let medianA = medianPosition(of: a, in: upperPosition, adjacency: reverseAdjacency)
                let medianB = medianPosition(of: b, in: upperPosition, adjacency: reverseAdjacency)
                return medianA < medianB
            }
        }

        // 从倒数第二层开始，逐层向上排序
        for i in stride(from: layers.count - 2, through: 0, by: -1) {
            let lowerLayer = layers[i + 1]
            let lowerPosition: [String: Int] = Dictionary(uniqueKeysWithValues: lowerLayer.enumerated().map { ($1, $0) })

            layers[i].sort { a, b in
                let medianA = medianPosition(of: a, in: lowerPosition, adjacency: adjacency)
                let medianB = medianPosition(of: b, in: lowerPosition, adjacency: adjacency)
                return medianA < medianB
            }
        }

        return layers
    }

    /// 计算节点在邻居层中的中位数位置
    private static func medianPosition(
        of nodeId: String,
        in positions: [String: Int],
        adjacency: [String: [String]]
    ) -> CGFloat {
        let neighbors = adjacency[nodeId] ?? []
        let neighborPositions = neighbors.compactMap { positions[$0] }.sorted()

        guard !neighborPositions.isEmpty else { return CGFloat.greatestFiniteMagnitude }

        let mid = neighborPositions.count / 2
        if neighborPositions.count % 2 == 0 {
            return CGFloat(neighborPositions[mid - 1] + neighborPositions[mid]) / 2.0
        } else {
            return CGFloat(neighborPositions[mid])
        }
    }

    // MARK: - Phase 4: Coordinate Assignment

    /// 计算节点坐标
    private static func assignCoordinates(
        layers: [[String]],
        nodeMap: [String: LayoutNode],
        edges: [LayoutEdge],
        config: Config
    ) -> LayoutResult {
        var nodePositions: [String: (x: CGFloat, y: CGFloat, layer: Int)] = [:]

        // 计算每层的 y 坐标
        var currentY: CGFloat = config.margin
        for (layerIndex, layerNodes) in layers.enumerated() {
            // 计算该层最大高度
            let maxHeight = layerNodes.compactMap { nodeMap[$0]?.height }.max() ?? config.nodeHeight

            // 计算 x 坐标
            var currentX = config.margin
            for nodeId in layerNodes {
                let width = nodeMap[nodeId]?.width ?? config.nodeWidth
                nodePositions[nodeId] = (currentX + width / 2, currentY + maxHeight / 2, layerIndex)
                currentX += width + config.nodeSpacingX
            }

            currentY += (maxHeight + config.nodeSpacingY) * config.layerMultiplier
        }

        // 计算总宽高
        let totalWidth = (layers.map { layer in
            layer.compactMap { nodeMap[$0]?.width }.reduce(config.margin * 2) { $0 + $1 + config.nodeSpacingX }
        }.max() ?? 0)

        let totalHeight = currentY

        // 构建节点结果
        let rawPositionedNodes: [PositionedNode] = nodePositions.map { (id, pos) -> PositionedNode in
            PositionedNode(id: id, x: pos.x, y: pos.y, layer: pos.layer)
        }
        let positionedNodes = rawPositionedNodes.sorted { (a, b) -> Bool in
            if a.layer == b.layer {
                return a.x < b.x
            }
            return a.layer < b.layer
        }

        // 构建边结果（贝塞尔曲线控制点）
        let positionedEdges: [PositionedEdge] = edges.map { edge -> PositionedEdge in
            let sourcePos = nodePositions[edge.source] ?? (x: CGFloat(0), y: CGFloat(0), layer: 0)
            let targetPos = nodePositions[edge.target] ?? (x: CGFloat(0), y: CGFloat(0), layer: 0)

            // 贝塞尔控制点
            let midY = (sourcePos.y + targetPos.y) / 2
            let points: [CGPoint] = [
                CGPoint(x: sourcePos.x, y: sourcePos.y),
                CGPoint(x: sourcePos.x, y: midY),
                CGPoint(x: targetPos.x, y: midY),
                CGPoint(x: targetPos.x, y: targetPos.y)
            ]

            return PositionedEdge(id: edge.id, source: edge.source, target: edge.target, points: points)
        }

        return LayoutResult(
            nodes: positionedNodes,
            edges: positionedEdges,
            totalWidth: totalWidth,
            totalHeight: totalHeight
        )
    }
}
