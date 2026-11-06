import Foundation

enum SampleAccent: String, Sendable {
    case cyan, amber, violet, green, rose
}

struct SampleNote: Identifiable, Equatable, Sendable {
    let id: String
    /// Substring used to find the source line the note belongs to.
    let anchor: String?
    let stages: Set<MicroStage>?
    let text: String
}

struct SampleProgram: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let badge: String
    let accent: SampleAccent
    let source: String
    let notes: [SampleNote]
}

enum SampleCatalog {

    static let all: [SampleProgram] = [
        countdown,
        sum,
        multiply,
        fibonacci,
        blockCopy,
        subroutine,
        inputEcho,
        blank
    ]

    static var first: SampleProgram {
        all[0]
    }

    static func sample(id: String) -> SampleProgram? {
        all.first { $0.id == id }
    }

    // MARK: Countdown

    static let countdown = SampleProgram(
        id: "countdown",
        title: "Countdown",
        subtitle: "Write 5…1 to the display and watch the zero flag end the loop.",
        badge: "START HERE",
        accent: .cyan,
        source: """
        ; NOVA-8 · countdown
        ; The display lives at address 0xF0.
        .text
        start:
            LDI B, 5
        loop:
            OUT B
            DEC B
            JNZ loop
            HLT
        """,
        notes: [
            SampleNote(
                id: "countdown-ldi",
                anchor: "LDI B, 5",
                stages: [.fetch, .operand, .execute],
                text: "LDI is two bytes long. After the opcode, watch the extra operand fetch put 0x05 into T before B is loaded."
            ),
            SampleNote(
                id: "countdown-out",
                anchor: "OUT B",
                stages: [.decode, .execute],
                text: "OUT is assembler sugar for ST B, 0xF0. The display is a memory-mapped port, so this is an ordinary store."
            ),
            SampleNote(
                id: "countdown-dec",
                anchor: "DEC B",
                stages: [.execute],
                text: "DEC changes B and also updates the flags. When B reaches zero, Z becomes 1."
            ),
            SampleNote(
                id: "countdown-jnz",
                anchor: "JNZ loop",
                stages: [.decode, .execute],
                text: "JNZ reads the Z flag. While Z=0 the branch jumps back; when DEC makes B zero, it falls through to HLT."
            ),
            SampleNote(
                id: "countdown-hlt",
                anchor: "HLT",
                stages: [.execute],
                text: "HLT stops the clock. Reset reloads the program and starts again."
            )
        ]
    )

    // MARK: Sum

    static let sum = SampleProgram(
        id: "sum",
        title: "Sum 1…10",
        subtitle: "Accumulate ten numbers in A. The answer, 55, arrives over the bus.",
        badge: "ALU + FLAGS",
        accent: .amber,
        source: """
        ; NOVA-8 · sum 1..10
        .text
        start:
            LDI A, 0        ; running total
            LDI B, 10       ; counter
        loop:
            ADD B           ; A = A + B
            DEC B           ; counter -= 1
            JNZ loop        ; repeat until B == 0
            OUT A           ; show 55
            HLT
        """,
        notes: [
            SampleNote(
                id: "sum-add",
                anchor: "ADD B",
                stages: [.execute],
                text: "A is the accumulator: every ALU result is written back to it. B is the second operand."
            ),
            SampleNote(
                id: "sum-dec",
                anchor: "DEC B",
                stages: [.execute],
                text: "DEC preserves carry but refreshes Z and N. That is how the loop knows when to stop."
            ),
            SampleNote(
                id: "sum-jnz",
                anchor: "JNZ loop",
                stages: [.decode, .execute],
                text: "The branch is taken while Z=0. On the last iteration Z=1, so execution falls through to OUT."
            ),
            SampleNote(
                id: "sum-out",
                anchor: "OUT A",
                stages: [.execute],
                text: "The final value is 0x37 (55). Writing it to 0xF0 lights the display."
            )
        ]
    )

    // MARK: Multiply

    static let multiply = SampleProgram(
        id: "multiply",
        title: "Multiply",
        subtitle: "6 × 7 by repeated addition — a nested idea in a tiny loop.",
        badge: "LOOPS",
        accent: .violet,
        source: """
        ; NOVA-8 · multiply by repeated addition
        .text
        start:
            LDI A, 0        ; product
            LDI B, 6        ; add 6...
            LDI C, 7        ; ...seven times
        loop:
            ADD B
            DEC C
            JNZ loop
            OUT A           ; 42
            HLT
        """,
        notes: [
            SampleNote(
                id: "multiply-add",
                anchor: "ADD B",
                stages: [.execute],
                text: "Six is added to A seven times. That is multiplication without a multiply instruction."
            ),
            SampleNote(
                id: "multiply-dec",
                anchor: "DEC C",
                stages: [.execute],
                text: "C counts down from 7. Each pass through the loop is one addition."
            ),
            SampleNote(
                id: "multiply-out",
                anchor: "OUT A",
                stages: [.execute],
                text: "0x2A is 42. Change LDI B and LDI C to multiply other pairs."
            )
        ]
    )

    // MARK: Fibonacci

    static let fibonacci = SampleProgram(
        id: "fibonacci",
        title: "Fibonacci",
        subtitle: "Shuffle three registers to build 0, 1, 1, 2, 3, 5, 8, 13, 21, 34.",
        badge: "REGISTERS",
        accent: .green,
        source: """
        ; NOVA-8 · first ten Fibonacci numbers
        .text
        start:
            LDI A, 0        ; current
            LDI B, 1        ; next
            LDI D, 10       ; how many to print
        loop:
            OUT A
            MOV C, A        ; save current
            ADD B           ; A = current + next
            MOV B, C        ; B = old current
            DEC D
            JNZ loop
            HLT
        """,
        notes: [
            SampleNote(
                id: "fib-mov",
                anchor: "MOV C, A",
                stages: [.execute],
                text: "MOV is a plain register-to-register transfer. It uses the internal bus just like any other value."
            ),
            SampleNote(
                id: "fib-add",
                anchor: "ADD B",
                stages: [.execute],
                text: "At this point A is the old current value and B is the next one. The sum becomes the new current."
            ),
            SampleNote(
                id: "fib-out",
                anchor: "OUT A",
                stages: [.execute],
                text: "Each pass writes one number to 0xF0. The console keeps the full sequence."
            )
        ]
    )

    // MARK: Block copy

    static let blockCopy = SampleProgram(
        id: "blockcopy",
        title: "Block Copy",
        subtitle: "Use two pointer registers to copy eight bytes through memory.",
        badge: "MEMORY",
        accent: .rose,
        source: """
        ; NOVA-8 · copy 8 bytes from src to dst
        .text
        start:
            LDI A, src      ; source pointer
            LDI B, dst      ; destination pointer
            LDI C, 8        ; byte count
        loop:
            LDR D, A        ; D = memory[A]
            STR D, B        ; memory[B] = D
            INC A
            INC B
            DEC C
            JNZ loop
            LDI A, 0xAA
            OUT A
            HLT
        .data
        src:
            DB 1, 2, 3, 4, 5, 6, 7, 8
        dst:
            DB 0, 0, 0, 0, 0, 0, 0, 0
        """,
        notes: [
            SampleNote(
                id: "copy-ldr",
                anchor: "LDR D, A",
                stages: [.fetch, .execute],
                text: "LDR is register-indirect: A is not data, it is the address to read. Watch A drive MAR."
            ),
            SampleNote(
                id: "copy-str",
                anchor: "STR D, B",
                stages: [.execute],
                text: "STR writes D to the address held in B. The source and destination pointers march through memory."
            ),
            SampleNote(
                id: "copy-inc",
                anchor: "INC A",
                stages: [.execute],
                text: "Incrementing the pointers walks the data region, one byte at a time."
            ),
            SampleNote(
                id: "copy-data",
                anchor: "DB 1, 2, 3",
                stages: [.execute],
                text: "The .data section starts at 0x80. src and dst resolve to real addresses in the memory map."
            )
        ]
    )

    // MARK: Subroutine

    static let subroutine = SampleProgram(
        id: "subroutine",
        title: "Subroutine",
        subtitle: "CALL pushes a return address; PUSH and POP protect a register.",
        badge: "STACK",
        accent: .amber,
        source: """
        ; NOVA-8 · call, save, return
        .text
        start:
            LDI A, 5
            LDI B, 99
            CALL addten
            OUT A           ; 15
            OUT B           ; 99, restored
            HLT

        addten:
            PUSH B          ; save B
            LDI B, 10
            ADD B           ; A = A + 10
            POP B           ; restore B
            RET
        """,
        notes: [
            SampleNote(
                id: "sub-call",
                anchor: "CALL addten",
                stages: [.execute],
                text: "CALL pushes the address of the next instruction onto the stack, then jumps. Watch SP move down."
            ),
            SampleNote(
                id: "sub-push",
                anchor: "PUSH B",
                stages: [.execute],
                text: "PUSH stores B at the stack pointer and decrements SP. The stack grows downward from 0xEF."
            ),
            SampleNote(
                id: "sub-pop",
                anchor: "POP B",
                stages: [.execute],
                text: "POP increments SP and pulls the old value back into B. The caller's 99 is restored."
            ),
            SampleNote(
                id: "sub-ret",
                anchor: "RET",
                stages: [.execute],
                text: "RET pops the return address into PC. Execution continues right after the CALL."
            )
        ]
    )

    // MARK: Input echo

    static let inputEcho = SampleProgram(
        id: "input",
        title: "Input Echo",
        subtitle: "Read the switches at 0xF1 and mirror them on the display.",
        badge: "I/O",
        accent: .cyan,
        source: """
        ; NOVA-8 · memory-mapped input
        ; Drag the INPUT slider while this runs.
        .text
        start:
        loop:
            IN A            ; load from 0xF1
            OUT A           ; store to 0xF0
            JMP loop
        """,
        notes: [
            SampleNote(
                id: "input-in",
                anchor: "IN A",
                stages: [.execute],
                text: "IN is a load from the input port at 0xF1. The value comes from the slider in the output panel."
            ),
            SampleNote(
                id: "input-loop",
                anchor: "JMP loop",
                stages: [.execute],
                text: "This program never halts. Pause it, change the input, or press Reset to start over."
            )
        ]
    )

    // MARK: Blank

    static let blank = SampleProgram(
        id: "blank",
        title: "Empty Program",
        subtitle: "A clean slate with a tiny working example.",
        badge: "SANDBOX",
        accent: .green,
        source: """
        ; NOVA-8 · new program
        .text
        start:
            LDI A, 42
            OUT A
            HLT
        """,
        notes: []
    )
}
