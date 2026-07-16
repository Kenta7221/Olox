package olox

import "core:fmt"
import "core:strings"

Interpreter :: struct {
    env: ^Env,
    globals: ^Env,
    all_env: [dynamic]^Env,
    had_runtime_error: bool,
}

Exec_Result :: struct {
    returning: bool,
    value: Value
}

interpreter_init :: proc() -> (i: Interpreter) {
    i.all_env = make([dynamic]^Env)
    i.env = env_init(&i.all_env)
    i.globals = env_init(&i.all_env)
    return
}

interpreter_delete :: proc(i: ^Interpreter) {
    for env in i.all_env {
        delete(env.values)
        free(env)
    }
    delete(i.all_env)
}

interpret :: proc(i: ^Interpreter, stmts: [dynamic]^Stmt) {
    for stmt in stmts do execute(i, stmt)
}

execute :: proc(i: ^Interpreter, stmt: ^Stmt) -> Exec_Result {
    switch &s in stmt^ {
    case Stmt_Expr:
        evaluate(i, s.expr)
    case Stmt_Print:
        val := evaluate(i, s.expr)
        fmt.println(stringify(val))
    case Stmt_Var:
        val: Value = nil
        if s.initializer != nil do val = evaluate(i, s.initializer)
        env_define(i.env, s.name.lexeme, val)
    case Stmt_Block:
        execute_block(i, s.stmts, env_init(&i.all_env, i.env))
    case Stmt_If:
        if is_truthy(evaluate(i, s.cond)) {
            return execute(i, s.then_branch)
        } else if s.else_branch != nil {
            return execute(i, s.else_branch)
        }
    case Stmt_While:
        for is_truthy(evaluate(i, s.cond)) {
            result := execute(i, s.body)
            if result.returning do return result
        }
    case Stmt_Function:
        fn := new(Lox_Function)
        fn^ = Lox_Function{
            declaration = &s,
            closure     = i.env,
        }
        env_define(i.env, s.name.lexeme, fn)
    case Stmt_Return:
        value := evaluate(i, s.value) if s.value != nil else nil
        return Exec_Result{true, value}
    }

    return Exec_Result{}
}

execute_block :: proc(i: ^Interpreter, statements: [dynamic]^Stmt, env: ^Env) -> Exec_Result {
    previous := i.env
    defer i.env = previous

    i.env = env
    for stmt in statements {
        result := execute(i, stmt)
        if result.returning do return result
    }

    return Exec_Result{}
}

evaluate :: proc(i: ^Interpreter, expr: ^Expr) -> Value {
    switch e in expr^ {
    case Expr_Binary:
        return evaluate_binary(i, e)
    case Expr_Grouping:
        return evaluate(i, e.expr)
    case Expr_Unary:
        return evaluate_unary(i, e)
    case Expr_Call:
        return evaluate_call(i, e)
    case Expr_Literal:
        return e.val
    case Expr_Var:
        return env_get(i, i.env, e.name)
    case Expr_Ass:
        value := evaluate(i, e.expr)
        env_set(i, i.env, e.name, value)
        return value
    case Expr_Logical:
        return evaluate_logical(i, e)
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

evaluate_call :: proc(i: ^Interpreter, expr: Expr_Call) -> Value {
    callee := evaluate(i, expr.calle)

    args := make([dynamic]Value)
    for arg in expr.args do append_elem(&args, evaluate(i, arg))

    fn, ok := callee.(^Lox_Function)
    if !ok {
        runtime_error(i, expr.paren, "Can only call functions and classes.")
        return nil
    }

    if len(args) != check_arinity(callee) {
        runtime_error(i, expr.paren, fmt.tprintf(
            "Expected %d arguments but got %d.", check_arinity(callee), len(args)))
        return nil
    }

    return call(i, fn, args)
}

call :: proc(i: ^Interpreter, callee: Value, args: [dynamic]Value) -> Value {
    #partial switch c in callee {
    case ^Lox_Function:
        return call_function(i, c, args)
    case ^Native_Function:
        return c.fn(args)
    }
    return nil
}

call_function :: proc(i: ^Interpreter, fn: ^Lox_Function, args: [dynamic]Value) -> Value {
    env := env_init(&i.all_env, fn.closure)
    for param, i in fn.declaration.params {
        env_define(env, param.lexeme, args[i])
    }

    result := execute_block(i, fn.declaration.body, env)
    if result.returning do return result.value
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

evaluate_logical :: proc(i: ^Interpreter, expr: Expr_Logical) -> Value {
    left := evaluate(i, expr.left)

    if expr.op.type == .OR {
        if is_truthy(left) do return left
    } else {
        if !is_truthy(left) do return left
    }

    return evaluate(i, expr.right)
}

runtime_error :: proc(i: ^Interpreter, token: Token, msg: string) {
    fmt.eprintln("Interpreter error: [line", token.line, "]", msg)
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
    case ^Native_Function:
    case ^Lox_Function:
        return fmt.tprintf("<fn %v>", val.declaration.name.lexeme)
    }

    return ""
}
