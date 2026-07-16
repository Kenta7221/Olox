package olox

Expr :: union {
    Expr_Binary,
    Expr_Call,
    Expr_Logical,
    Expr_Grouping,
    Expr_Literal,
    Expr_Unary,
    Expr_Var,
    Expr_Ass,
}

Expr_Binary :: struct {
    left: ^Expr,
    op: Token,
    right: ^Expr
}

Expr_Call :: struct {
    calle: ^Expr,
    paren: Token,
    args: [dynamic]^Expr
}

Expr_Logical :: struct {
    left: ^Expr,
    op: Token,
    right: ^Expr
}

Expr_Grouping :: struct {
    expr: ^Expr
}

Expr_Literal :: struct {
    val: Value
}

Expr_Unary :: struct {
    op: Token,
    right: ^Expr
}

Expr_Var :: struct {
    name: Token
}

Expr_Ass :: struct {
    name: Token,
    expr: ^Expr
}

make_binary :: proc(left: ^Expr, operator: Token, right: ^Expr) -> ^Expr {
    expr := new(Expr)
    expr^ = Expr_Binary{left, operator, right}
    return expr
}

make_call :: proc(calle: ^Expr, paren: Token, args: [dynamic]^Expr) -> ^Expr {
    expr := new(Expr)
    expr^ = Expr_Call{calle, paren, args}
    return expr
}

make_logical :: proc(left: ^Expr, operator: Token, right: ^Expr) -> ^Expr {
    expr := new(Expr)
    expr^ = Expr_Logical{left, operator, right}
    return expr
}

make_grouping :: proc(left: ^Expr) -> ^Expr {
    expr := new(Expr)
    expr^ = Expr_Grouping{left}
    return expr
}

make_literal :: proc(val: Value) -> ^Expr {
    expr := new(Expr)
    expr^ = Expr_Literal{val}
    return expr
}

make_unary :: proc(operator: Token, right: ^Expr) -> ^Expr { 
    expr := new(Expr)
    expr^ = Expr_Unary{operator, right}
    return expr
}

make_ass :: proc(name: Token, right: ^Expr) -> ^Expr {
    expr := new(Expr)
    expr^ = Expr_Ass{name, right}
    return expr
}

make_var :: proc(name: Token) -> ^Expr {
    expr := new(Expr)
    expr^ = Expr_Var{name}
    return expr
}

expression :: proc(p: ^Parser) -> ^Expr {
    return assignment(p)
}

@(private="file")
assignment :: proc(p: ^Parser)  -> ^Expr {
    expr := equality(p)

    if match(p, .EQUAL) {
        equals := previous(p)
        value := assignment(p)

        if e, ok := expr.(Expr_Var); ok {
            name := e.name
            return make_ass(name, value)
        }

        error(p, equals, "Ivalid assignment.")
    }
    
    return expr
}

@(private="file")
or :: proc(p: ^Parser) -> ^Expr {
    expr := and(p)

    for match(p, .OR) {
        op := previous(p)
        right := and(p)
        expr = make_logical(expr, op, right)
    }
    
    return expr
}

@(private="file")
and :: proc(p: ^Parser) -> ^Expr {
    expr := equality(p)

    for match(p, .OR) {
        op := previous(p)
        right := equality(p)
        expr = make_logical(expr, op, right)
    }
    
    return expr
}

@(private="file")
equality :: proc(p: ^Parser) -> ^Expr {
    expr := comparison(p)
    for match(p, .BANG_EQUAL, .EQUAL_EQUAL) {
        op := previous(p)
        right := comparison(p)
        expr = make_binary(expr, op, right)
    }

    return expr
}

@(private="file")
comparison :: proc(p: ^Parser) -> ^Expr {
    expr := term(p)
    for match(p, .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL) {
        op := previous(p)
        right := term(p)
        expr = make_binary(expr, op, right)
    }

    return expr
}

@(private="file")
term :: proc(p: ^Parser) -> ^Expr {
    expr := factor(p)
    for match(p, .MINUS, .PLUS) {
        op := previous(p)
        right := factor(p)
        expr = make_binary(expr, op, right)
    }

    return expr
}

@(private="file")
factor :: proc(p: ^Parser) -> ^Expr {
    expr := unary(p)
    for match(p, .STAR, .SLASH) {
        op := previous(p)
        right := unary(p)
        expr = make_binary(expr, op, right)
    }

    return expr
}

@(private="file")
unary :: proc(p: ^Parser) -> ^Expr {
    if match(p, .BANG, .MINUS) {
        op := previous(p)
        right := unary(p)
        return make_unary(op, right)
    }

    return call(p)
}

@(private="file")
call :: proc(p: ^Parser) -> ^Expr {
    expr := primary(p)
    
    for true {
        if !match(p, .LEFT_PAREN) do break
        expr = finish_call(p, expr)
    }

    return expr
}

@(private="file")
finish_call :: proc(p: ^Parser, calle: ^Expr) -> ^Expr {
    args := make([dynamic]^Expr)
    if !check(p, .RIGHT_PAREN) {
        another_arg := true
        for another_arg {
            if len(args) >= 255 {
                error(p, peek(p), "Can't have more than 255 arguments.")
            }
            
            append_elem(&args, expression(p))
            another_arg = match(p, .COMMA)
        }
    }

    paren := consume(p, .RIGHT_PAREN, "Expect ')' after arguments.")
    return make_call(calle, paren, args)
}

@(private="file")
primary :: proc(p: ^Parser) -> ^Expr {
    if match(p, .FALSE)           do return make_literal(false)
    if match(p, .TRUE)            do return make_literal(true)
    if match(p, .NIL)             do return make_literal(nil)
    if match(p, .NUMBER, .STRING) do return make_literal(previous(p).literal)
    if match(p, .IDENTIFIER)      do return make_var(previous(p))

    if match(p, .LEFT_PAREN) {
        expr := expression(p)
        consume(p, .RIGHT_PAREN, "Expect '(' after expression.")
        return make_grouping(expr)
    }
    
    error(p, peek(p), "Expected expression.")
    p.had_error = true
    return nil
}
