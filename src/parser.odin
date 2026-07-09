#+ feature dynamic-literals
package olox

import "core:fmt"
import "core:slice"

Parser :: struct {
    tokens: [dynamic]Token,
    curr: int,
    had_error: bool
}

parser_init :: proc(tokens: [dynamic]Token) -> (p: Parser) {
    p.tokens = slice.clone_to_dynamic(tokens[:])
    return
}

parser_delete :: proc(p: ^Parser) {
    delete(p.tokens)
}

parse :: proc(p: ^Parser) ->  [dynamic]^Stmt {
    stmts := make([dynamic]^Stmt, 0, 16)
    
    for !is_at_end(p) do append_elem(&stmts, declaration(p))

    return stmts
}

sychronize :: proc(p: ^Parser) {
    advance(p)

    for !is_at_end(p) {
        if previous(p).type == .SEMICOLON do return

        #partial switch peek(p).type {
        case .CLASS:
        case .FUN:
        case .VAR:
        case .FOR:
        case .IF:
        case .WHILE:
        case .PRINT:
        case .RETURN:
            return
        }
    }
}

error :: proc(p: ^Parser, token: Token, msg: string) {
    if p.had_error do return
    fmt.eprintf("[line %d]", token.line)

    if token.type == .EOF {
        fmt.eprintf(" at end")
    } else {
        fmt.eprintf("%d at %s, %s", token.line, token.lexeme, msg)
    }

    fmt.eprintf(": %s\n", msg)
    p.had_error = true
}

Stmt :: union {
    Stmt_Expr,
    Stmt_Print,
    Stmt_Var,
    Stmt_Block,
    Stmt_If,
    Stmt_While,
}

Stmt_Expr :: struct {
    expr: ^Expr
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

init_while_stmt :: proc(cond: ^Expr, body: ^Stmt) -> ^Stmt {
    stmt := new(Stmt)
    stmt^ = Stmt_While{cond, body}
    return stmt
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
    stmt = var_declaration(p) if match(p, .VAR) else statement(p)

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

expr_stmt :: proc(p: ^Parser) -> ^Stmt {
    exp := expression(p)
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

Expr :: union {
    Expr_Binary,
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

make_binary :: proc(left: ^Expr, operator: Token, right: ^Expr) -> ^Expr {
    expr := new(Expr)
    expr^ = Expr_Binary{left, operator, right}
    return expr
}

Expr_Logical :: struct {
    left: ^Expr,
    op: Token,
    right: ^Expr
}

make_logical :: proc(left: ^Expr, operator: Token, right: ^Expr) -> ^Expr {
    expr := new(Expr)
    expr^ = Expr_Logical{left, operator, right}
    return expr
}

Expr_Grouping :: struct {
    expr: ^Expr
}

make_grouping :: proc(left: ^Expr) -> ^Expr {
    expr := new(Expr)
    expr^ = Expr_Grouping{left}
    return expr
}

Expr_Literal :: struct {
    val: Value
}

make_literal :: proc(val: Value) -> ^Expr {
    expr := new(Expr)
    expr^ = Expr_Literal{val}
    return expr
}

Expr_Unary :: struct {
    op: Token,
    right: ^Expr
}

make_unary :: proc(operator: Token, right: ^Expr) -> ^Expr { 
    expr := new(Expr)
    expr^ = Expr_Unary{operator, right}
    return expr
}

Expr_Var :: struct {
    name: Token
}

make_var :: proc(name: Token) -> ^Expr {
    expr := new(Expr)
    expr^ = Expr_Var{name}
    return expr
}

Expr_Ass :: struct {
    name: Token,
    expr: ^Expr
}

make_ass :: proc(name: Token, right: ^Expr) -> ^Expr {
    expr := new(Expr)
    expr^ = Expr_Ass{name, right}
    return expr
}

@(private="file")
expression :: proc(p: ^Parser) -> ^Expr {
    return assignment(p)
}

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

or :: proc(p: ^Parser) -> ^Expr {
    expr := and(p)

    for match(p, .OR) {
        op := previous(p)
        right := and(p)
        expr = make_logical(expr, op, right)
    }
    
    return expr
}

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

    return primary(p)
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

// Helpers
@(private="file")
is_at_end :: proc(p: ^Parser) -> bool {
    return p.tokens[p.curr].type == .EOF
}

@(private="file")
check :: proc(p: ^Parser, type: TokenType) -> bool {
    if is_at_end(p) do return false
    return peek(p).type == type
}

@(private="file")
advance :: proc(p: ^Parser) -> Token {
    if !is_at_end(p) do p.curr += 1
    return previous(p)
}

@(private="file")
peek :: proc(p: ^Parser) -> Token{
    return p.tokens[p.curr]
}

@(private="file")
previous :: proc(p: ^Parser) -> Token{
    return p.tokens[p.curr - 1]
}

@(private="file")
match :: proc(p: ^Parser, types: ..TokenType) -> bool {
    for type in types {
        if !check(p, type) do continue
        
        advance(p)
        return true
    }

    return false
}

@(private="file")
consume :: proc(p: ^Parser, type: TokenType, msg: string) -> Token {
    if check(p, type) do return advance(p)
    
    error(p, peek(p), msg)
    return peek(p)
}
