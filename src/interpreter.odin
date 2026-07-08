package olox

import "core:fmt"
import "core:strings"

Interpreter :: struct {
    environment: ^Environment,
    had_runtime_error: bool
}

interpreter_init :: proc() -> (i: Interpreter) {
    i.environment = environment_init()
    return
}

interpreter_delete :: proc(i: ^Interpreter) {
    delete(i.environment.values)
}

interpret :: proc(i: ^Interpreter, stmts: [dynamic]^Stmt) {
    for stmt in stmts do execute(i, stmt)
}

execute :: proc(i: ^Interpreter, stmt: ^Stmt) {
    switch s in stmt^ {
    case Stmt_Expr:
        evaluate(i, s.expr)
    case Stmt_Print:
        val := evaluate(i, s.expr)
        fmt.println(stringify(val))
    case Stmt_Var:
        val: Value = nil
        if s.initializer != nil do val = evaluate(i, s.initializer)
        environment_define(i.environment, s.name.lexeme, val)
    case Stmt_Block:
        execute_block(i, s.stmts, environment_init(i.environment))
    }
}

execute_block :: proc(i: ^Interpreter, statements: [dynamic]^Stmt, environment: ^Environment) {
    previous := i.environment
    defer i.environment = previous

    i.environment = environment
    for stmt in statements {
        execute(i, stmt)
    }
}

evaluate :: proc(i: ^Interpreter, expr: ^Expr) -> Value {
    switch e in expr^ {
    case Expr_Binary:
        return evaluate_binary(i, e)
    case Expr_Grouping:
        return evaluate(i, e.expr)
    case Expr_Unary:
        return evaluate_unary(i, e)
    case Expr_Literal:
        return e.val
    case Expr_Var:
        return environment_get(i, i.environment, e.name)
    case Expr_Ass:
        value := evaluate(i, e.expr)
        environment_set(i, i.environment, e.name, value)
        return value
    }

    return nil
}

evaluate_unary :: proc(i: ^Interpreter, expr: Expr_Unary) -> Value {
    right := evaluate(i, expr.right)

    #partial switch expr.op.type {
        case .MINUS:
        return -check_number_operand(i, expr.op ,right)
        case .BANG:
        return !is_truthy(right)
    }
    
    return nil
}

evaluate_binary :: proc(i: ^Interpreter, expr: Expr_Binary) -> Value {
    left := evaluate(i, expr.left)
    right := evaluate(i, expr.right)
    
    #partial switch expr.op.type {
        case .GREATER:
        l := check_number_operand(i, expr.op, left)
        r := check_number_operand(i, expr.op, right)
        return l > r
        case .GREATER_EQUAL:
        l := check_number_operand(i, expr.op, left)
        r := check_number_operand(i, expr.op, right)
        return l >= r
        case .LESS:
        l := check_number_operand(i, expr.op, left)
        r := check_number_operand(i, expr.op, right)
        return l < r
        case .LESS_EQUAL:
        l := check_number_operand(i, expr.op, left)
        r := check_number_operand(i, expr.op, right)
        return l <= r
        case .EQUAL_EQUAL:
        return is_equal(left, right)
        case .BANG_EQUAL:
        return !is_equal(left, right)
        case .MINUS:
        l := check_number_operand(i, expr.op, left)
        r := check_number_operand(i, expr.op, right)
        return l - r
        case .SLASH:
        l := check_number_operand(i, expr.op, left)
        r := check_number_operand(i, expr.op, right)
        return l / r
        case .STAR:
        l := check_number_operand(i, expr.op, left)
        r := check_number_operand(i, expr.op, right)
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

    runtime_error(i, expr.op, "Operands must be two numbers or two strings")

    return nil
}

runtime_error :: proc(i: ^Interpreter, token: Token, msg: string) {
    fmt.eprintln(msg, "\n[line", token.line, "]")
    i.had_runtime_error = true
}

// Helpers
check_number_operand :: proc(i: ^Interpreter, op: Token, v: Value) -> f64 {
    if n, ok := v.(f64); ok { return n }
    runtime_error(i, op, "Operands must be numbers")
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
