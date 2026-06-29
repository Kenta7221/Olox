package olox

import "core:fmt"

Lox :: struct {
    had_error: bool
}

lox_error :: proc(lox: ^Lox, line: i32, message: string) {
    fmt.eprintln(line, message)
    lox.had_error = true
}

lox_report :: proc(lox: ^Lox, line: i32, where_err, message: string) {
    fmt.eprintfln("[line %d] Error %s: %s", line, where_err, message)
    lox.had_error = true
}
