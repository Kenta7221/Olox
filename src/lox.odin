package olox

import "core:fmt"
import "core:os"
import "core:strings"
import vmem "core:mem/virtual"

Lox :: struct {
    arena: vmem.Arena,
    scanner: Scanner,
    parser: Parser,
    interp: Interpreter,
    had_error: bool
}

lox_init :: proc(filepath: string) -> (l: Lox) {
    arena_err := vmem.arena_init_growing(&l.arena)
    if arena_err != nil {
        fmt.eprintln("Error creating arena allocator")
        os.exit(1)
    }
    source := load_file(filepath, &l.arena)
    
    l.scanner = scanner_init(source)
    l.interp = interpreter_init()
    
    return
}

lox_run :: proc(l: ^Lox) {
    // Step 1: Scan tokens
    scan_tokens(&l.scanner)

    // for token in l.scanner.tokens {
    //     fmt.println(token)
    // }
    // fmt.println()
    
    // Step 2: Parse the tokens into an ast tree
    l.parser = parser_init(l.scanner.tokens)
    stmts := parse(&l.parser)
    defer delete(stmts)
    
    // Step 3: Interpret
    interpret(&l.interp, stmts)
}

lox_delete :: proc(l: ^Lox) {
    vmem.arena_destroy(&l.arena)
    scanner_delete(&l.scanner)
    parser_delete(&l.parser)
    interpreter_delete(&l.interp)
}

lox_error :: proc(lox: ^Lox, line: i32, message: string) {
    fmt.eprintln(line, message)
    lox.had_error = true
}

lox_report :: proc(lox: ^Lox, line: i32, where_err, message: string) {
    fmt.eprintfln("[line %d] Error %s: %s", line, where_err, message)
    lox.had_error = true
}

// Helpers
@(private="file")
load_file :: proc(filepath: string, arena: ^vmem.Arena) -> string {
    arena_alloc := vmem.arena_allocator(arena)
    file, err := os.read_entire_file(filepath, arena_alloc)
    if err != os.ERROR_NONE {
        fmt.eprintln("Could not open the file", filepath)
        os.exit(1)
    }
    
    return string(file)
}
