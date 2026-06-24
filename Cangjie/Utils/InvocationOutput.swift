//
//  InvocationOutput.swift
//  Cangjie
//
//  AI Invocation 输出 JSON 解析工具。
//  对齐原版 invocationOutput.ts:1-165 全部9个函数。
//  补充 AIInvocationReviewPanel.vue:258-456 的 parseAttemptContent + recoverTruncatedArrayObject。
//  机制4：每个函数标注原版文件+行号。
//

import Foundation

// MARK: - JSON 解析工具（invocationOutput.ts:3-164）

/// 解析类 JSON 记录 — invocationOutput.ts:3-22
/// 尝试：直接parse → markdown代码块提取 → 外层花括号提取；只接受object。
func parseJsonLikeRecord(_ raw: String) -> [String: Any]? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }
    let candidates = [trimmed, extractJsonFromMarkdown(trimmed), extractOuterJson(trimmed)].filter { !$0.isEmpty }
    for candidate in candidates {
        if let data = candidate.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any] {
            return parsed
        }
    }
    return nil
}

/// 从 Markdown 代码块提取 JSON — invocationOutput.ts:24-27
func extractJsonFromMarkdown(_ raw: String) -> String {
    // 匹配 ```json ... ``` 或 ``` ... ```
    let pattern = "```(?:json)?\\s*([\\s\\S]*?)```"
    if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
       let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
       match.numberOfRanges > 1,
       let range = Range(match.range(at: 1), in: raw) {
        return String(raw[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return ""
}

/// 提取最外层花括号 JSON — invocationOutput.ts:29-34
func extractOuterJson(_ raw: String) -> String {
    guard let startIndex = raw.firstIndex(of: "{"),
          let endIndex = raw.lastIndex(of: "}") else { return "" }
    if endIndex <= startIndex { return "" }
    return String(raw[startIndex...endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
}

/// 按路径取值 — invocationOutput.ts:36-52
/// 支持 $. 开头、. 分隔、[] 索引、[*] 遍历。
func pickPath(source: Any?, path: String) -> Any? {
    guard let source = source, !path.isEmpty else { return nil }
    var normalized = path.trimmingCharacters(in: .whitespacesAndNewlines)
    if normalized.isEmpty || normalized == "$" { return source }
    if normalized.hasPrefix("$.") {
        normalized = String(normalized.dropFirst(2))
    } else if normalized.hasPrefix("$") {
        normalized = String(normalized.dropFirst())
        if normalized.hasPrefix(".") { normalized = String(normalized.dropFirst()) }
    }
    var current: Any? = source
    for segment in normalized.split(separator: ".").map(String.init).filter({ !$0.isEmpty }) {
        current = pickPathSegment(source: current, segment: segment)
        if current == nil { return nil }
    }
    return current
}

/// 路径段解析 — invocationOutput.ts:54-99（内部函数）
func pickPathSegment(source: Any?, segment: String) -> Any? {
    let raw = segment.trimmingCharacters(in: .whitespacesAndNewlines)
    if raw.isEmpty || raw == "$" { return source }
    if raw == "[]" || raw == "[*]" || raw == "*" {
        if let array = source as? [Any] { return array }
        return nil
    }
    // 数组处理
    if let array = source as? [Any] {
        if raw.hasPrefix("[") && raw.hasSuffix("]") {
            let inner = String(raw.dropFirst().dropLast())
            return pickListIndex(values: array, selector: inner)
        }
        // 对数组的每个元素递归
        return array.compactMap { pickPathSegment(source: $0, segment: raw) }
    }
    // 对象处理
    guard let dict = source as? [String: Any] else { return nil }
    var key = raw
    var selectors: [String] = []
    if let bracketIndex = raw.firstIndex(of: "[") {
        key = String(raw[raw.startIndex..<bracketIndex])
        var rest = String(raw[bracketIndex...])
        while rest.hasPrefix("[") {
            guard let closeIndex = rest.firstIndex(of: "]") else { return nil }
            selectors.append(String(rest[rest.index(after: rest.startIndex)..<closeIndex]))
            rest = String(rest[rest.index(after: closeIndex)...])
        }
        if !rest.isEmpty { return nil }
    }
    var value: Any? = dict
    if !key.isEmpty {
        value = dict[key]
    }
    for selector in selectors {
        guard let array = value as? [Any] else { return nil }
        if selector.isEmpty || selector == "*" { continue }
        value = pickListIndex(values: array, selector: selector)
    }
    return value
}

/// 数组索引取值 — invocationOutput.ts:101-107（内部函数）
func pickListIndex(values: [Any], selector: String) -> Any? {
    guard let index = Int(selector) else { return nil }
    let normalized = index < 0 ? values.count + index : index
    if normalized < 0 || normalized >= values.count { return nil }
    return values[normalized]
}

/// 精确 key 或点号前缀子键提取 — invocationOutput.ts:109-133
func pickExactOrDottedChildren(source: Any?, key: String) -> Any? {
    guard let dict = source as? [String: Any], !dict.isEmpty, !key.isEmpty else { return nil }
    if let value = dict[key] { return value }
    let prefix = "\(key)."
    let nestedEntries = dict.filter { $0.key.hasPrefix(prefix) }
    if nestedEntries.isEmpty { return nil }
    // 递归构建嵌套字典
    var root: [String: Any] = [:]
    for (entryKey, entryValue) in nestedEntries {
        let remainder = String(entryKey.dropFirst(prefix.count))
        if remainder.isEmpty { continue }
        let parts = remainder.split(separator: ".").map(String.init).filter { !$0.isEmpty }
        if parts.isEmpty { continue }
        insertIntoNestedDict(&root, path: parts, value: entryValue)
    }
    return root.isEmpty ? nil : root
}

/// 递归插入嵌套字典（辅助函数）
private func insertIntoNestedDict(_ dict: inout [String: Any], path: [String], value: Any) {
    guard let first = path.first else { return }
    if path.count == 1 {
        dict[first] = value
    } else {
        if dict[first] == nil {
            dict[first] = [String: Any]()
        }
        if var nested = dict[first] as? [String: Any] {
            insertIntoNestedDict(&nested, path: Array(path.dropFirst()), value: value)
            dict[first] = nested
        }
    }
}

/// 解析绑定输出值 — invocationOutput.ts:135-149
func resolveBoundOutputValue(source: Any?, binding: InvocationVariableBinding) -> Any? {
    let candidates: [String?] = [binding.sourcePath, binding.alias, binding.variableKey]
    for candidate in candidates {
        let normalized = (candidate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty { continue }
        let exact = pickExactOrDottedChildren(source: source, key: normalized)
        if exact != nil { return exact }
        let picked = pickPath(source: source, path: normalized)
        if picked != nil { return picked }
    }
    return nil
}

/// 批量提取绑定输出 — invocationOutput.ts:151-164
func extractBoundOutputMaps(_ source: Any?, bindings: [InvocationVariableBinding]) -> (byAlias: [String: Any], byVariableKey: [String: Any]) {
    var byAlias: [String: Any] = [:]
    var byVariableKey: [String: Any] = [:]
    for binding in bindings {
        let value = resolveBoundOutputValue(source: source, binding: binding)
        guard let value = value else { continue }
        if !binding.alias.isEmpty {
            byAlias[binding.alias] = value
        }
        if let variableKey = binding.variableKey, !variableKey.isEmpty {
            byVariableKey[variableKey] = value
        }
    }
    return (byAlias, byVariableKey)
}

// MARK: - 面板专用函数（AIInvocationReviewPanel.vue:258-456）
// 主理人决策：放入 InvocationOutput.swift 作为扩展函数

/// 解析 attempt.content 为 JSON 对象 — AIInvocationReviewPanel.vue:258-277
/// 候选列表：[trim, extractJsonFromMarkdown, extractOuterJson]
/// 失败时尝试 recoverTruncatedArrayObject 恢复截断的 JSON
func parseAttemptContent(_ content: String) -> [String: Any]? {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }
    let candidates = [trimmed, extractJsonFromMarkdown(trimmed), extractOuterJson(trimmed)].filter { !$0.isEmpty }
    for candidate in candidates {
        if let data = candidate.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any] {
            return parsed
        }
    }
    // 尝试恢复截断的数组对象（AIInvocationReviewPanel.vue:291-344）
    if let recovered = recoverTruncatedArrayObject(trimmed, arrayKey: "characters") {
        return recovered
    }
    if let recovered = recoverTruncatedArrayObject(trimmed, arrayKey: "locations") {
        return recovered
    }
    return nil
}

/// 恢复截断的 JSON 数组对象 — AIInvocationReviewPanel.vue:291-344
/// 手动解析截断的 JSON 数组，逐个 {}/[] 解析，容错处理。
func recoverTruncatedArrayObject(_ raw: String, arrayKey: String) -> [String: Any]? {
    // 查找 `"arrayKey":` 后的数组开始
    let searchKey = "\"\(arrayKey)\":"
    guard let keyRange = raw.range(of: searchKey) else { return nil }
    let afterKey = raw[keyRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
    guard afterKey.hasPrefix("[") else { return nil }

    // 逐个解析数组元素（{} 对象）
    var items: [[String: Any]] = []
    var depth = 0
    var currentStart: String.Index?
    var inString = false
    var escape = false

    for (index, char) in afterKey.enumerated() {
        let pos = afterKey.index(afterKey.startIndex, offsetBy: index)
        if escape {
            escape = false
            continue
        }
        if char == "\\" {
            escape = true
            continue
        }
        if char == "\"" {
            inString.toggle()
            continue
        }
        if inString { continue }
        if char == "{" {
            if depth == 0 {
                currentStart = pos
            }
            depth += 1
        } else if char == "}" {
            depth -= 1
            if depth == 0, let start = currentStart {
                let objStr = String(afterKey[start...pos])
                if let data = objStr.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    items.append(obj)
                }
                currentStart = nil
            }
        } else if char == "]" && depth == 0 {
            break
        }
    }

    if items.isEmpty { return nil }
    // 构建最小结果对象
    var result: [String: Any] = [:]
    result[arrayKey] = items
    // 尝试提取其他顶层字段
    return result
}

// MARK: - 安全 JSON 预览（AIInvocationReviewPanel.vue:458-466）

/// 安全 JSON 预览格式化 — AIInvocationReviewPanel.vue:458-466
func safeJsonPreview(_ value: Any?) -> String {
    guard let value = value else { return "" }
    if let str = value as? String { return str }
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .fragmentsAllowed]),
       let str = String(data: data, encoding: .utf8) {
        return str
    }
    return "\(value)"
}

/// 格式化值 — AIInvocationReviewPanel.vue:167-175
func formatInvocationValue(_ value: Any?) -> String {
    guard let value = value else { return "" }
    if let str = value as? String { return str }
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .fragmentsAllowed]),
       let str = String(data: data, encoding: .utf8) {
        return str
    }
    return "\(value)"
}
