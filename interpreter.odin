package olox

import "core:fmt"
import "core:strings"

Interpreter :: struct {
    environment: Environment,
    had_runtime_error: bool
}

interp: Interpreter

interpret :: proc(stmts: [dynamic]^Stmt) {
    interp.environment.values = make(map[string]Value)
    
    for stmt in stmts do excecute(stmt)
}

excecute :: proc(stmt: ^Stmt) {
    switch s in stmt^ {
        case Stmt_Expr:
        evaluate(s.expr)
        case Stmt_Print:
        val := evaluate(s.expr)
        fmt.println(stringify(val))
        case Stmt_Var:
        val: Value = nil
        if s.initializer != nil do val = evaluate(s.initializer)
        environment_define(&interp.environment, s.name.lexeme, val)
    }
}

evaluate :: proc(expr: ^Expr) -> Value {
    switch e in expr^ {
    case Expr_Binary:
        return evaluate_binary(e)
    case Expr_Grouping:
        return evaluate(e.expr)
    case Expr_Unary:
        return evaluate_unary(e)
    case Expr_Literal:
        return e.val
    case Expr_Var:
        return environment_get(&interp.environment, e.name)
    }

    return nil
}

evaluate_unary :: proc(expr: Expr_Unary) -> Value {
    right := evaluate(expr.right)

    #partial switch expr.op.type {
        case .MINUS:
        return -check_number_operand(expr.op ,right)
        case .BANG:
        return !is_truthy(right)
    }
    
    return nil
}

evaluate_binary :: proc(expr: Expr_Binary) -> Value {
    left := evaluate(expr.left)
    right := evaluate(expr.right)
    
    #partial switch expr.op.type {
        case .GREATER:
        l := check_number_operand(expr.op, left)
        r := check_number_operand(expr.op, right)
        return l > r
        case .GREATER_EQUAL:
        l := check_number_operand(expr.op, left)
        r := check_number_operand(expr.op, right)
        return l >= r
        case .LESS:
        l := check_number_operand(expr.op, left)
        r := check_number_operand(expr.op, right)
        return l < r
        case .LESS_EQUAL:
        l := check_number_operand(expr.op, left)
        r := check_number_operand(expr.op, right)
        return l <= r
        case .EQUAL_EQUAL:
        return is_equal(left, right)
        case .BANG_EQUAL:
        return !is_equal(left, right)
        case .MINUS:
        l := check_number_operand(expr.op, left)
        r := check_number_operand(expr.op, right)
        return l - r
        case .SLASH:
        l := check_number_operand(expr.op, left)
        r := check_number_operand(expr.op, right)
        return l / r
        case .STAR:
        l := check_number_operand(expr.op, left)
        r := check_number_operand(expr.op, right)
        return l * r
        case .PLUS:        
        if l, lok := left.(f64); lok {
            if r, rok := right.(f64); rok {
                return l + r
            }
        }
        if l, lok := left.(string); lok {
            if r, rok := right.(string); rok {
                return strings.concatenate({l, r})
            }
        }
    }

    runtime_error(expr.op, "Operands must be two numbers or two strings")

    return nil
}

runtime_error :: proc(token: Token, msg: string) {
    fmt.eprintln(msg, "\n[line", token.line, "]")
    interp.had_runtime_error = true
}

// Helpers
check_number_operand :: proc(op: Token, v: Value) -> f64 {
    if n, ok := v.(f64); ok { return n }
    runtime_error(op, "Operands must be numbers")
    return 0
}

is_truthy :: proc(v: Value) -> bool {
    #partial switch val in v {
    case bool:   return val
    case:        return v != nil
    }
}

is_equal :: proc(a, b: Value) -> bool {
    if a == nil && b == nil { return true }
    if a == nil || b == nil { return false }
    return a == b
}

stringify :: proc(v: Value) -> string {
    switch val in v {
    case f64:
        s := fmt.tprintf("%v", val)
        if strings.has_suffix(s, ".0") {
            return s[:len(s)-2]
        }
        return s
    case string:
        return val
    case bool:
        return fmt.tprintf("%v", val)
        case:
        return "nil"
    }
}
