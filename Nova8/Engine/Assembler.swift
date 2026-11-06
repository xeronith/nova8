import Foundation

enum ParseResult<Value> {
    case success(Value)
    case failure(String)
}

// MARK: - Diagnostics

enum DiagnosticSeverity: String, Comparable, Sendable {
    case warning
    case error

    private var rank: Int {
        switch self {
        case .warning: return 0
        case .error: return 1
        }
    }

    static func < (lhs: DiagnosticSeverity, rhs: DiagnosticSeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

struct Diagnostic: Identifiable, Equatable, Sendable {
    let line: Int
    let column: Int?
    let message: String
    let severity: DiagnosticSeverity

    var id: String {
        "\(line):\(column ?? 0):\(severity.rawValue):\(message)"
    }
}

// MARK: - Result types

struct ListingLine: Equatable, Sendable {
    let line: Int
    let address: UInt8
    let bytes: [UInt8]
}

struct AssembledProgram: Equatable, Sendable {
    var memory: [UInt8]
    var listing: [ListingLine]
    var symbols: [String: Int]
    var diagnostics: [Diagnostic]
    var lineToAddress: [Int: UInt8]
    var addressToLine: [UInt8: Int]
    var textBytes: Int
    var dataBytes: Int

    var hasErrors: Bool {
        diagnostics.contains { $0.severity == .error }
    }

    func address(forLine line: Int) -> UInt8? {
        lineToAddress[line]
    }

    func line(forAddress address: UInt8) -> Int? {
        addressToLine[address]
    }

    func bytes(at address: UInt8) -> [UInt8]? {
        listing.first { $0.address == address }?.bytes
    }

    static let empty = AssembledProgram(
        memory: Array(repeating: 0, count: 256),
        listing: [],
        symbols: [:],
        diagnostics: [],
        lineToAddress: [:],
        addressToLine: [:],
        textBytes: 0,
        dataBytes: 0
    )
}

// MARK: - Assembler

enum Assembler {

    private enum OperandSpec {
        case register
        case value
        case address
    }

    private struct MnemonicSpec {
        let opcode: Opcode
        let operands: [OperandSpec]
        let fixedValue: UInt8?

        var size: Int {
            opcode.operandKind == .none ? 1 : 2
        }
    }

    private enum Body {
        case instruction(line: Int, address: Int, mnemonic: String, operands: [String], spec: MnemonicSpec)
        case data(line: Int, address: Int, bytes: [UInt8])
    }

    private enum Section {
        case text
        case data
    }

    private static let predefinedSymbols: [String: Int] = [
        "DISPLAY": Int(MemoryMap.displayPort),
        "INPUT": Int(MemoryMap.inputPort),
        "PROGRAM_START": Int(MemoryMap.programStart),
        "DATA_START": Int(MemoryMap.dataStart)
    ]

    // MARK: Entry point

    static func assemble(_ source: String) -> AssembledProgram {
        let lines = source.components(separatedBy: .newlines)
        var diagnostics: [Diagnostic] = []
        var symbols = predefinedSymbols
        var bodies: [Body] = []
        var section: Section = .text
        var textPC = Int(MemoryMap.programStart)
        var dataPC = Int(MemoryMap.dataStart)
        var lineToAddress: [Int: UInt8] = [:]
        var addressToLine: [UInt8: Int] = [:]
        var textBytes = 0
        var dataBytes = 0

        func currentPC() -> Int {
            section == .text ? textPC : dataPC
        }

        func sectionLimit() -> Int {
            section == .text ? Int(MemoryMap.dataStart) : Int(MemoryMap.stackStart)
        }

        func advance(_ count: Int) {
            if section == .text {
                textPC += count
            } else {
                dataPC += count
            }
        }

        for (index, raw) in lines.enumerated() {
            let lineNumber = index + 1
            var text = stripComment(raw).trimmingCharacters(in: .whitespaces)
            if text.isEmpty { continue }

            // Label (label may share a line with an instruction)
            if let first = text.split(whereSeparator: { $0 == " " || $0 == "\t" }).first,
               first.hasSuffix(":") {
                let candidate = String(first.dropLast())
                if isValidIdentifier(candidate) {
                    if symbols[candidate] != nil {
                        diagnostics.append(Diagnostic(
                            line: lineNumber,
                            column: nil,
                            message: "Symbol '\(candidate)' is already defined.",
                            severity: .error
                        ))
                    } else {
                        symbols[candidate] = currentPC()
                    }
                    text = String(text.dropFirst(first.count)).trimmingCharacters(in: .whitespaces)
                    if text.isEmpty { continue }
                } else {
                    diagnostics.append(Diagnostic(
                        line: lineNumber,
                        column: nil,
                        message: "Invalid label '\(candidate)'.",
                        severity: .error
                    ))
                }
            }

            // Constant: NAME = expression
            if let equals = text.firstIndex(of: "=") {
                let name = String(text[..<equals]).trimmingCharacters(in: .whitespaces)
                if isValidIdentifier(name) {
                    let expression = String(text[text.index(after: equals)...])
                    switch evaluate(expression, symbols: symbols) {
                    case .success(let value):
                        if (0...255).contains(value) {
                            symbols[name] = value
                        } else {
                            diagnostics.append(Diagnostic(
                                line: lineNumber,
                                column: nil,
                                message: "Constant '\(name)' must fit in one byte (0–255).",
                                severity: .error
                            ))
                        }
                    case .failure(let message):
                        diagnostics.append(Diagnostic(
                            line: lineNumber,
                            column: nil,
                            message: "Invalid constant '\(name)': \(message)",
                            severity: .error
                        ))
                    }
                    continue
                }
            }

            // Directives
            let lowered = text.lowercased()
            if lowered == ".text" {
                section = .text
                continue
            }
            if lowered == ".data" {
                section = .data
                continue
            }
            if lowered.hasPrefix(".") && !lowered.hasPrefix(".byte") {
                diagnostics.append(Diagnostic(
                    line: lineNumber,
                    column: nil,
                    message: "Unknown directive '\(text)'.",
                    severity: .error
                ))
                continue
            }

            let head = headAndRest(text)
            let mnemonic = head.head.uppercased()
            let operands = splitOperands(head.rest)

            // Data bytes
            if mnemonic == "DB" || mnemonic == ".BYTE" {
                guard !operands.isEmpty else {
                    diagnostics.append(Diagnostic(
                        line: lineNumber,
                        column: nil,
                        message: "DB needs at least one value.",
                        severity: .error
                    ))
                    continue
                }

                var bytes: [UInt8] = []
                var failed = false
                for operand in operands {
                    switch parseDataItem(operand) {
                    case .success(let values):
                        bytes.append(contentsOf: values)
                    case .failure(let message):
                        diagnostics.append(Diagnostic(
                            line: lineNumber,
                            column: nil,
                            message: message,
                            severity: .error
                        ))
                        failed = true
                    }
                }
                if failed { continue }

                let address = currentPC()
                if address + bytes.count > sectionLimit() {
                    diagnostics.append(Diagnostic(
                        line: lineNumber,
                        column: nil,
                        message: section == .text
                            ? "Data exceeds the 128-byte program region (0x00–0x7F)."
                            : "Data exceeds the 64-byte data region (0x80–0xBF).",
                        severity: .error
                    ))
                }
                bodies.append(.data(line: lineNumber, address: address, bytes: bytes))
                advance(bytes.count)
                if section == .text { textBytes = max(textBytes, textPC) }
                else { dataBytes = max(dataBytes, dataPC - Int(MemoryMap.dataStart)) }
                continue
            }

            // Instruction
            guard let spec = mnemonicSpec(for: mnemonic) else {
                diagnostics.append(Diagnostic(
                    line: lineNumber,
                    column: nil,
                    message: "Unknown instruction '\(head.head)'.",
                    severity: .error
                ))
                continue
            }

            if operands.count != spec.operands.count {
                let expected = spec.operands.count
                diagnostics.append(Diagnostic(
                    line: lineNumber,
                    column: nil,
                    message: expected == 0
                        ? "\(mnemonic) takes no operands."
                        : "\(mnemonic) expects \(expected) operand\(expected == 1 ? "" : "s"), got \(operands.count).",
                    severity: .error
                ))
                continue
            }

            let address = currentPC()
            if address + spec.size > sectionLimit() {
                diagnostics.append(Diagnostic(
                    line: lineNumber,
                    column: nil,
                    message: section == .text
                        ? "Program exceeds the 128-byte program region (0x00–0x7F)."
                        : "Code exceeds the 64-byte data region (0x80–0xBF).",
                    severity: .error
                ))
            }

            if (0...255).contains(address) {
                lineToAddress[lineNumber] = UInt8(address)
                addressToLine[UInt8(address)] = lineNumber
            }

            bodies.append(.instruction(
                line: lineNumber,
                address: address,
                mnemonic: mnemonic,
                operands: operands,
                spec: spec
            ))
            advance(spec.size)
            if section == .text { textBytes = max(textBytes, textPC) }
            else { dataBytes = max(dataBytes, dataPC - Int(MemoryMap.dataStart)) }
        }

        // MARK: Pass 2 — encode

        var memory = Array(repeating: UInt8(0), count: 256)
        var listing: [ListingLine] = []

        for body in bodies {
            switch body {
            case .data(_, let address, let bytes):
                for (offset, byte) in bytes.enumerated() {
                    let target = address + offset
                    if target >= 0 && target < memory.count {
                        memory[target] = byte
                    }
                }

            case .instruction(let line, let address, let mnemonic, let operands, let spec):
                let encoded = encode(
                    mnemonic: mnemonic,
                    operands: operands,
                    spec: spec,
                    symbols: symbols,
                    line: line
                )
                switch encoded {
                case .success(let bytes):
                    for (offset, byte) in bytes.enumerated() {
                        let target = address + offset
                        if target >= 0 && target < memory.count {
                            memory[target] = byte
                        }
                    }
                    if (0...255).contains(address) {
                        listing.append(ListingLine(
                            line: line,
                            address: UInt8(address),
                            bytes: bytes
                        ))
                    }
                case .failure(let message):
                    diagnostics.append(Diagnostic(
                        line: line,
                        column: nil,
                        message: message,
                        severity: .error
                    ))
                }
            }
        }

        // Drop listing entries that collided with errors? Keep them: the byte
        // stream is best-effort and the UI only runs programs without errors.

        return AssembledProgram(
            memory: memory,
            listing: listing,
            symbols: symbols,
            diagnostics: diagnostics,
            lineToAddress: lineToAddress,
            addressToLine: addressToLine,
            textBytes: textBytes,
            dataBytes: dataBytes
        )
    }

    // MARK: Encoding

    private static func encode(
        mnemonic: String,
        operands: [String],
        spec: MnemonicSpec,
        symbols: [String: Int],
        line: Int
    ) -> ParseResult<[UInt8]> {
        var first = spec.opcode.rawValue << 3

        if spec.opcode.hasRegisterField {
            guard let registerText = operands.first,
                  let register = Register.named(registerText) else {
                return .failure("\(mnemonic) needs a register (A, B, C, D, or SP).")
            }
            first |= UInt8(register.rawValue)
        }

        var bytes: [UInt8] = [first]

        switch spec.opcode.operandKind {
        case .none:
            break

        case .register:
            guard operands.count > 1, let source = Register.named(operands[1]) else {
                return .failure("\(mnemonic) needs a second register operand.")
            }
            bytes.append(UInt8(source.rawValue))

        case .value, .address:
            if let fixed = spec.fixedValue {
                bytes.append(fixed)
            } else {
                let operandIndex = spec.opcode.hasRegisterField ? 1 : 0
                guard operands.indices.contains(operandIndex) else {
                    return .failure("\(mnemonic) needs a value.")
                }
                let operand = operands[operandIndex]
                switch evaluate(operand, symbols: symbols) {
                case .success(let value):
                    guard (0...255).contains(value) else {
                        return .failure("Operand \(operand) is out of range; it must fit in one byte (0–255).")
                    }
                    bytes.append(UInt8(value))
                case .failure(let message):
                    return .failure("Bad operand '\(operand)': \(message)")
                }
            }
        }

        return .success(bytes)
    }

    private static func mnemonicSpec(for mnemonic: String) -> MnemonicSpec? {
        switch mnemonic {
        case "NOP": return MnemonicSpec(opcode: .nop, operands: [], fixedValue: nil)
        case "HLT": return MnemonicSpec(opcode: .hlt, operands: [], fixedValue: nil)
        case "RET": return MnemonicSpec(opcode: .ret, operands: [], fixedValue: nil)
        case "SHL": return MnemonicSpec(opcode: .shl, operands: [], fixedValue: nil)
        case "SHR": return MnemonicSpec(opcode: .shr, operands: [], fixedValue: nil)
        case "LDI": return MnemonicSpec(opcode: .ldi, operands: [.register, .value], fixedValue: nil)
        case "LD": return MnemonicSpec(opcode: .ld, operands: [.register, .address], fixedValue: nil)
        case "ST": return MnemonicSpec(opcode: .st, operands: [.register, .address], fixedValue: nil)
        case "LDR": return MnemonicSpec(opcode: .ldr, operands: [.register, .register], fixedValue: nil)
        case "STR": return MnemonicSpec(opcode: .str, operands: [.register, .register], fixedValue: nil)
        case "MOV": return MnemonicSpec(opcode: .mov, operands: [.register, .register], fixedValue: nil)
        case "ADD": return MnemonicSpec(opcode: .add, operands: [.register], fixedValue: nil)
        case "SUB": return MnemonicSpec(opcode: .sub, operands: [.register], fixedValue: nil)
        case "AND": return MnemonicSpec(opcode: .and, operands: [.register], fixedValue: nil)
        case "OR": return MnemonicSpec(opcode: .or, operands: [.register], fixedValue: nil)
        case "XOR": return MnemonicSpec(opcode: .xor, operands: [.register], fixedValue: nil)
        case "CMP": return MnemonicSpec(opcode: .cmp, operands: [.register], fixedValue: nil)
        case "INC": return MnemonicSpec(opcode: .inc, operands: [.register], fixedValue: nil)
        case "DEC": return MnemonicSpec(opcode: .dec, operands: [.register], fixedValue: nil)
        case "NOT": return MnemonicSpec(opcode: .not, operands: [.register], fixedValue: nil)
        case "PUSH": return MnemonicSpec(opcode: .push, operands: [.register], fixedValue: nil)
        case "POP": return MnemonicSpec(opcode: .pop, operands: [.register], fixedValue: nil)
        case "JMP": return MnemonicSpec(opcode: .jmp, operands: [.address], fixedValue: nil)
        case "JZ": return MnemonicSpec(opcode: .jz, operands: [.address], fixedValue: nil)
        case "JNZ": return MnemonicSpec(opcode: .jnz, operands: [.address], fixedValue: nil)
        case "JC": return MnemonicSpec(opcode: .jc, operands: [.address], fixedValue: nil)
        case "JNC": return MnemonicSpec(opcode: .jnc, operands: [.address], fixedValue: nil)
        case "CALL": return MnemonicSpec(opcode: .call, operands: [.address], fixedValue: nil)
        case "ADDI": return MnemonicSpec(opcode: .addi, operands: [.value], fixedValue: nil)
        case "OUT": return MnemonicSpec(opcode: .st, operands: [.register], fixedValue: MemoryMap.displayPort)
        case "IN": return MnemonicSpec(opcode: .ld, operands: [.register], fixedValue: MemoryMap.inputPort)
        default: return nil
        }
    }

    // MARK: Lexing helpers

    private static func stripComment(_ line: String) -> String {
        var result = ""
        var quote: Character?
        var escaped = false

        for character in line {
            if escaped {
                result.append(character)
                escaped = false
                continue
            }
            if character == "\\" && quote != nil {
                result.append(character)
                escaped = true
                continue
            }
            if let current = quote {
                result.append(character)
                if character == current { quote = nil }
                continue
            }
            if character == "\"" || character == "'" {
                quote = character
                result.append(character)
                continue
            }
            if character == ";" { break }
            result.append(character)
        }
        return result
    }

    private static func headAndRest(_ text: String) -> (head: String, rest: String) {
        guard let index = text.firstIndex(where: { $0 == " " || $0 == "\t" }) else {
            return (text, "")
        }
        let head = String(text[..<index])
        let rest = String(text[index...]).trimmingCharacters(in: .whitespaces)
        return (head, rest)
    }

    static func splitOperands(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        var result: [String] = []
        var current = ""
        var quote: Character?
        var escaped = false

        for character in text {
            if escaped {
                current.append(character)
                escaped = false
                continue
            }
            if character == "\\" && quote != nil {
                current.append(character)
                escaped = true
                continue
            }
            if let currentQuote = quote {
                current.append(character)
                if character == currentQuote { quote = nil }
                continue
            }
            if character == "\"" || character == "'" {
                quote = character
                current.append(character)
                continue
            }
            if character == "," {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
                continue
            }
            current.append(character)
        }

        let last = current.trimmingCharacters(in: .whitespaces)
        if !last.isEmpty { result.append(last) }
        return result
    }

    // MARK: Expressions

    static func evaluate(_ expression: String, symbols: [String: Int]) -> ParseResult<Int> {
        var text = expression.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") {
            text.removeFirst()
            text = text.trimmingCharacters(in: .whitespaces)
        }
        guard !text.isEmpty else {
            return .failure("missing value")
        }

        // Find a top-level + or - (not the leading sign, not inside quotes).
        var quote: Character?
        var escaped = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if escaped {
                escaped = false
            } else if character == "\\" && quote != nil {
                escaped = true
            } else if let current = quote {
                if character == current { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if (character == "+" || character == "-") && index > text.startIndex {
                let lhs = String(text[..<index])
                let rhs = String(text[text.index(after: index)...])
                guard case .success(let left) = evaluate(lhs, symbols: symbols),
                      case .success(let right) = evaluate(rhs, symbols: symbols) else {
                    return .failure("could not evaluate '\(text)'")
                }
                return .success(character == "+" ? left + right : left - right)
            }
            index = text.index(after: index)
        }

        return evaluateAtom(text, symbols: symbols)
    }

    private static func evaluateAtom(_ text: String, symbols: [String: Int]) -> ParseResult<Int> {
        let token = text.trimmingCharacters(in: .whitespaces)
        guard !token.isEmpty else { return .failure("missing value") }

        if token.hasPrefix("'") {
            return parseCharacter(token)
        }

        if token.hasPrefix("0x") || token.hasPrefix("0X") {
            let digits = String(token.dropFirst(2))
            guard let value = Int(digits, radix: 16) else {
                return .failure("invalid hex literal '\(token)'")
            }
            return .success(value)
        }

        if token.hasPrefix("$") {
            let digits = String(token.dropFirst())
            guard let value = Int(digits, radix: 16) else {
                return .failure("invalid hex literal '\(token)'")
            }
            return .success(value)
        }

        if token.hasPrefix("0b") || token.hasPrefix("0B") {
            let digits = String(token.dropFirst(2))
            guard let value = Int(digits, radix: 2) else {
                return .failure("invalid binary literal '\(token)'")
            }
            return .success(value)
        }

        if let value = Int(token) {
            return .success(value)
        }

        if let value = symbols[token] {
            return .success(value)
        }

        // Allow case-insensitive symbol fallback.
        if let match = symbols.first(where: { $0.key.caseInsensitiveCompare(token) == .orderedSame }) {
            return .success(match.value)
        }

        return .failure("unknown symbol '\(token)'")
    }

    private static func parseCharacter(_ token: String) -> ParseResult<Int> {
        guard token.count >= 3, token.hasPrefix("'"), token.hasSuffix("'") else {
            return .failure("unterminated character literal")
        }
        let inner = String(token.dropFirst().dropLast())
        guard !inner.isEmpty else {
            return .failure("empty character literal")
        }

        if inner.hasPrefix("\\") {
            switch inner.dropFirst() {
            case "n": return .success(10)
            case "t": return .success(9)
            case "0": return .success(0)
            case "r": return .success(13)
            case "\\": return .success(92)
            case "'": return .success(39)
            case "\"": return .success(34)
            default: return .failure("unknown escape in character literal")
            }
        }

        guard inner.count == 1, let scalar = inner.unicodeScalars.first else {
            return .failure("character literals must contain exactly one character")
        }
        guard scalar.value < 128 else {
            return .failure("only ASCII characters are supported")
        }
        return .success(Int(scalar.value))
    }

    private static func parseDataItem(_ token: String) -> ParseResult<[UInt8]> {
        let text = token.trimmingCharacters(in: .whitespaces)

        if text.hasPrefix("\"") {
            guard text.hasSuffix("\""), text.count >= 2 else {
                return .failure("unterminated string literal")
            }
            let inner = String(text.dropFirst().dropLast())
            var bytes: [UInt8] = []
            var escaped = false

            for character in inner {
                if escaped {
                    switch character {
                    case "n": bytes.append(10)
                    case "t": bytes.append(9)
                    case "0": bytes.append(0)
                    case "r": bytes.append(13)
                    case "\\": bytes.append(92)
                    case "\"": bytes.append(34)
                    case "'": bytes.append(39)
                    default: bytes.append(character.asciiValue ?? 63)
                    }
                    escaped = false
                    continue
                }
                if character == "\\" {
                    escaped = true
                    continue
                }
                guard let ascii = character.asciiValue else {
                    return .failure("string '\(text)' contains a non-ASCII character")
                }
                bytes.append(ascii)
            }
            return .success(bytes)
        }

        if text.hasPrefix("'") {
            switch parseCharacter(text) {
            case .success(let value): return .success([UInt8(value)])
            case .failure(let message): return .failure(message)
            }
        }

        switch evaluate(text, symbols: [:]) {
        case .success(let value):
            guard (0...255).contains(value) else {
                return .failure("DB value \(text) is out of range (0–255).")
            }
            return .success([UInt8(value)])
        case .failure(let message):
            return .failure("DB values must be numeric, character, or string literals (\(message)).")
        }
    }

    private static func isValidIdentifier(_ text: String) -> Bool {
        guard let first = text.first, first.isLetter || first == "_" else {
            return false
        }
        return text.dropFirst().allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
