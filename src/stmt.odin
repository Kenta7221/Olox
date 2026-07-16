#+ feature dynamic-literals
package olox

import "core:fmt"

Stmt :: union {
    Stmt_Expr,
    Stmt_Print,
    Stmt_Var,
    Stmt_Function,
    Stmt_Return,
    Stmt_Block,
    Stmt_If,
    Stmt_While,
}

Stmt_Expr :: struct {
    expr: ^Expr
}

Stmt_Function :: struct {
    name: Token,
    params: [dynamic]Token,
    body: [dynamic]^Stmt
}

Stmt_Return :: struct {
    keyword: Token,
    value: ^Expr
}

Stmt_Print :: struct {
    expr: ^Expr
}

Stmt_Var :: struct {
    name: Token,
    initializer: ^Expr
}

Stmt_Block :: struct {
    stmts: [dynamic]^Stmt
}

Stmt_If :: struct {
    cond: ^Expr,
    then_branch: ^Stmt,
    else_branch: ^Stmt,
}

Stmt_While :: struct {
    cond: ^Expr,
    body: ^Stmt
}

// Seperated from others because it's used for blocks and functions
make_block_stmt :: proc(p: ^Parser) -> [dynamic]^Stmt {
    stmts := make([dynamic]^Stmt)
    
    for !check(p, .RIGHT_BRACE) && !is_at_end(p) {
        append_elem(&stmts, declaration(p))
    }

    consume(p, .RIGHT_BRACE, "Expect '}' after block.")
    return stmts
}

declaration :: proc(p: ^Parser) -> ^Stmt {
    stmt: ^Stmt
    if match(p, .VAR) {
        stmt = var_declaration(p)
    } else if match(p, .FUN) {
        stmt = func_declaration(p, "function")
    } else {
        stmt = statement(p)
    }

    if p.had_error {
        sychronize(p)
        return nil
    }

    return stmt
}

statement :: proc(p: ^Parser) -> ^Stmt {
    if match(p, .WHILE) do return while_stmt(p)
    if match(p, .FOR) do return for_stmt(p)
    if match(p, .IF) do return if_stmt(p)
    if match(p, .LEFT_BRACE) do return block_stmt(p)
    if match(p, .PRINT) do return print_stmt(p)
    if match(p, .RETURN) do return return_stmt(p)
    return expr_stmt(p)
}

var_declaration :: proc(p: ^Parser) -> ^Stmt {
    name := consume(p, .IDENTIFIER, "Expectet variable name.")

    initializer: ^Expr
    if match(p, .EQUAL) do initializer = expression(p)

    consume(p, .SEMICOLON, "Expect ';' after variable declaration.")
    
    stmt := new(Stmt)
    stmt^ = Stmt_Var{name, initializer}
    return stmt
}

func_declaration :: proc(p: ^Parser, kind: string) -> ^Stmt {
    name := consume(p, .IDENTIFIER, fmt.tprintln("Expect", kind, "name."))
    consume(p, .LEFT_PAREN, fmt.tprintln("Expect '(' after", kind, "name."))

    params := make([dynamic]Token)
    has_comma := true
    for has_comma {
        if len(params) >= 255 {
            error(p, peek(p), "Can't have more than 255 arguments.")
        }

        append_elem(&params, consume(p, .IDENTIFIER, "Expect parameter name."))
        has_comma = match(p, .COMMA)
    }

    consume(p, .RIGHT_PAREN, "Expect ')' after parameters.")
    consume(p, .LEFT_BRACE, fmt.tprintln("Expect '{' after", kind, "body."))
    body := make_block_stmt(p)

    stmt := new(Stmt)
    stmt^ = Stmt_Function{name, params, body}
    return stmt
}

expr_stmt :: proc(p: ^Parser) -> ^Stmt {
    exp := expression(p)
    append_elem(&p.all_expr, exp)

    consume(p, .SEMICOLON, "Expect ';' after value.")

    stmt := new(Stmt)
    stmt^ = Stmt_Expr{exp}
    return stmt
}

print_stmt :: proc(p: ^Parser) -> ^Stmt {
    exp := expression(p)
    consume(p, .SEMICOLON, "Expect ';' after value.")
    stmt := new(Stmt)
    stmt^ = Stmt_Print{exp}
    return stmt
}

return_stmt :: proc(p: ^Parser) -> ^Stmt {
    keyword := previous(p)
    value := expression(p) if !check(p, .SEMICOLON) else nil

    consume(p, .SEMICOLON, "Expect ';' after return value.")

    stmt := new(Stmt)
    stmt^ = Stmt_Return{keyword, value}
    return stmt
}

block_stmt :: proc(p: ^Parser) -> ^Stmt {   
    block := new(Stmt)
    block^ = Stmt_Block{make_block_stmt(p)}
    return block
}

if_stmt :: proc(p: ^Parser) -> ^Stmt {
    consume(p, .LEFT_PAREN, "Expect '(' after 'if'.")
    cond := expression(p)
    consume(p, .RIGHT_PAREN, "Expect ')' after 'if' condition.")

    then_branch := statement(p)
    else_branch := statement(p) if match(p, .ELSE) else nil

    stmt := new(Stmt)
    stmt^ = Stmt_If{cond, then_branch, else_branch}
    
    return stmt
}

while_stmt :: proc(p: ^Parser) -> ^Stmt {
    consume(p, .LEFT_PAREN, "Expect '(' after 'if'.")
    cond := expression(p)
    consume(p, .RIGHT_PAREN, "Expect ')' after 'if' condition.")

    body := statement(p)

    stmt := new(Stmt)
    stmt^ = Stmt_While{cond, body}
    return stmt
}

for_stmt :: proc(p: ^Parser) -> ^Stmt {
    consume(p, .LEFT_PAREN, "Expect '(' after 'if'.")
    
    initializer: ^Stmt = nil
    if match(p, .SEMICOLON) {
        initializer = nil
    } else if match(p, .VAR) {
        initializer = var_declaration(p)
    } else {
        initializer = expr_stmt(p)
    }

    cond: ^Expr = nil
    if !check(p, .SEMICOLON) {
        cond = expression(p)
    }
    consume(p, .SEMICOLON, "Expect ';' after loop condition.")
    
    increment: ^Expr = nil
    if !check(p, .RIGHT_PAREN) {
        increment = expression(p)
    }
    consume(p, .RIGHT_PAREN, "Expect ';' after for clauses.")

    body := statement(p)
    if increment != nil {
        expr_stmt := new(Stmt)
        expr_stmt^ = Stmt_Expr{increment}
         
        new_body := new(Stmt)
        new_body^ = Stmt_Block{[dynamic]^Stmt{body, expr_stmt}}
        body = new_body
    }
    
    if cond == nil {
        cond = make_literal(true)
    }
    new_body := new(Stmt)
    new_body^ = Stmt_While{cond, body}
    body = new_body

    if initializer != nil {
        new_body := new(Stmt)
        new_body^ = Stmt_Block{[dynamic]^Stmt{initializer, body}}
        body = new_body
    }

    return body
}

