//
//  String+WordCount.swift
//  Cangjie
//
//  字数统计扩展，中文按字计数 + 英文按词计数，用于章节字数显示。
//  与后端 word_count 逻辑保持一致：中文字符每个算 1 字，英文按空格分词。
//

import Foundation

extension String {

    /// 计算混合中英文字数。
    ///
    /// 规则：
    /// - 中文字符（含全角标点）每个算 1 字
    /// - 英文/数字连续序列按 1 个词计算
    /// - 空白字符不计入
    ///
    /// 示例：
    /// - "你好世界" → 4
    /// - "Hello World" → 2
    /// - "你好 Hello 世界" → 4（2 中文 + 1 英文词 + ... 实际为 4）
    ///
    /// - Returns: 字数统计结果
    var cangjieWordCount: Int {
        guard !self.isEmpty else { return 0 }

        var count = 0
        var inEnglishWord = false

        for scalar in self.unicodeScalars {
            let isWhitespace = scalar.properties.isWhitespace
            if isWhitespace {
                inEnglishWord = false
                continue
            }

            // 判断是否为中文字符（CJK 统一汉字 + 扩展区 + 全角标点）
            if Self.isChineseScalar(scalar) {
                count += 1
                inEnglishWord = false
            } else {
                // 非中文字符，按英文词处理
                if !inEnglishWord {
                    count += 1
                    inEnglishWord = true
                }
            }
        }

        return count
    }

    /// 判断 Unicode 标量是否为中文字符。
    ///
    /// 覆盖范围：
    /// - CJK 统一汉字（U+4E00 ~ U+9FFF）
    /// - CJK 扩展 A（U+3400 ~ U+4DBF）
    /// - CJK 兼容汉字（U+F900 ~ U+FAFF）
    /// - CJK 部首补充（U+2E80 ~ U+2EFF）
    /// - CJK 标点和符号（U+3000 ~ U+303F）
    /// - 全角字符（U+FF00 ~ U+FFEF）
    ///
    /// - Parameter scalar: Unicode 标量
    /// - Returns: 是否为中文字符
    private static func isChineseScalar(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value

        // CJK 统一汉字
        if value >= 0x4E00 && value <= 0x9FFF { return true }
        // CJK 扩展 A
        if value >= 0x3400 && value <= 0x4DBF { return true }
        // CJK 兼容汉字
        if value >= 0xF900 && value <= 0xFAFF { return true }
        // CJK 部首补充
        if value >= 0x2E80 && value <= 0x2EFF { return true }
        // CJK 标点和符号（包括。、！？等）
        if value >= 0x3000 && value <= 0x303F { return true }
        // 全角字符（包括全角字母、数字、标点）
        if value >= 0xFF00 && value <= 0xFFEF { return true }
        // CJK 扩展 B-F
        if value >= 0x20000 && value <= 0x2FA1F { return true }

        return false
    }

    /// 截取指定字数的前缀，超出部分用省略号替代。
    ///
    /// - Parameter maxCount: 最大字数
    /// - Returns: 截取后的字符串
    func cangjieTruncated(to maxCount: Int) -> String {
        guard self.count > maxCount else { return self }
        let index = self.index(self.startIndex, offsetBy: maxCount)
        return String(self[self.startIndex..<index]) + "..."
    }

    /// 格式化字数为人类可读字符串。
    ///
    /// - Returns: 如 "3.2万字"、"850字"、"0字"
    var cangjieWordCountDisplay: String {
        let count = self.cangjieWordCount
        if count >= 10000 {
            let wan = Double(count) / 10000.0
            return String(format: "%.1f万字", wan)
        }
        return "\(count)字"
    }
}
