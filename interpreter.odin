package olox

import "core:fmt"
import "core:strings"

Interpreter :: struct {
    had_runtime_error: bool
}


interp: Interpreter

evaluate :: proc(expr: ^Expr) -> Value {
    switch e in expr^ {       
    case Binary:
        return evaluate_binary(e)
    case Grouping:
        return evaluate(e.expr)
    case Unary:
        return evaluate_unary(e)
    case Literal:
        return e.val
    }

    return {}
}

evaluate_unary :: proc(expr: Unary) -> Value {
    right := evaluate(expr.right)

    #partial switch expr.op.type {
        case .MINUS:
        return -check_number_operand(expr.op ,right)
        case .BANG:
        return !is_truthy(right)
    }
    
    return nil
}

evaluate_binary :: proc(expr: Binary) -> Value {
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
        case .EQUAL:
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
        if type_of(left) == f64 && type_of(right) == f64 {
            l := left.(f64)
            r := left.(f64)
            return l + r
        }

        if type_of(left) == string && type_of(right) == string {
            l := left.(string)
            r := left.(string)
            return strings.concatenate({l, r})
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
