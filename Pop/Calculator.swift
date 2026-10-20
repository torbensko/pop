import Foundation

enum Calculator {
    static func evaluate(_ expression: String) -> String? {
        guard expression.count <= 256 else { return nil }
        var parser = Parser(chars: Array(expression.filter { !$0.isWhitespace }))
        guard let value = try? parser.expression(), parser.position == parser.chars.count, value.isFinite else { return nil }
        return value.formatted(.number.grouping(.never).precision(.significantDigits(1...14)))
    }
    private enum Invalid: Error { case expression }
    private struct Parser {
        let chars: [Character]
        var position = 0
        mutating func take(_ char: Character) -> Bool {
            guard position < chars.count, chars[position] == char else { return false }
            position += 1
            return true
        }
        mutating func expression() throws -> Double {
            var value = try term()
            while true {
                if take("+") { value += try term() }
                else if take("-") { value -= try term() }
                else { return value }
            }
        }
        mutating func term() throws -> Double {
            var value = try unary()
            while true {
                if take("*") { value *= try unary() }
                else if take("/") { value /= try unary() }
                else { return value }
            }
        }
        mutating func unary() throws -> Double {
            if take("+") { return try unary() }
            if take("-") { return try -unary() }
            return try power()
        }
        mutating func power() throws -> Double {
            let value = try atom()
            if take("^") { return pow(value, try unary()) }
            return value
        }
        mutating func atom() throws -> Double {
            if take("(") {
                let value = try expression()
                guard take(")") else { throw Invalid.expression }
                return value
            }
            let start = position
            while position < chars.count, chars[position].isNumber || chars[position] == "." { position += 1 }
            guard let value = Double(String(chars[start..<position])) else { throw Invalid.expression }
            return value
        }
    }
}
