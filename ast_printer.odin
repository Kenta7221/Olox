package olox

import "core:fmt"
import "core:strings"

// 1. Root wrapper function
ast_print :: proc(expr: ^Expr) -> string {
    if expr == nil do return "nil"
    
    sb: strings.Builder
    strings.builder_init(&sb)
    
    ast_print_node(&sb, expr)
    return strings.to_string(sb) // Caller must delete() this string later
}

// 2. Recursive internal worker
ast_print_node :: proc(sb: ^strings.Builder, expr: ^Expr) {
    if expr == nil {
        strings.write_string(sb, "nil")
        return
    }

    // CRITICAL: We dereference 'expr^' here to switch on the actual Union value
    switch e in expr^ {
    case Binary:
        strings.write_string(sb, fmt.tprintf("( %s ", e.op.lexeme))
        ast_print_node(sb, e.left) // e.left is already a ^Expr, perfect match!
        strings.write_string(sb, " ")
        ast_print_node(sb, e.right)
        strings.write_string(sb, " )")

    case Grouping:
        strings.write_string(sb, "( group ")
        ast_print_node(sb, e.expr) // e.expression is a ^Expr
        strings.write_string(sb, " )")

    case Unary:
        strings.write_string(sb, fmt.tprintf("( %s ", e.op.lexeme))
        ast_print_node(sb, e.right)
        strings.write_string(sb, " )")

    case Literal:
        if e.val == nil {
            strings.write_string(sb, "nil")
        } else {
            strings.write_string(sb, fmt.tprintf("%v", e.val))
        }
    }
}
