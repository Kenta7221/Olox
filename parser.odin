package olox

import "core:fmt"
import "core:slice"

Stmt :: union {
    Stmt_Expr,
    Stmt_Print,
    Stmt_Var,
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

Expr :: union {
    Expr_Binary,
    Expr_Grouping,
    Expr_Literal,
    Expr_Unary,
    Expr_Var,
}

Expr_Binary :: struct {
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

make_binary :: proc(left: ^Expr, operator: Token, right: ^Expr) -> ^Expr {
    expr := new(Expr)
    expr^ = Expr_Binary{left, operator, right}
    return expr
}

make_unary :: proc(operator: Token, right: ^Expr) -> ^Expr { 
    expr := new(Expr)
    expr^ = Expr_Unary{operator, right}
    return expr
}

make_literal :: proc(val: Value) -> ^Expr {
    expr := new(Expr)
    expr^ = Expr_Literal{val}
    return expr
}

make_grouping :: proc(left: ^Expr) -> ^Expr {
    expr := new(Expr)
    expr^ = Expr_Grouping{left}
    return expr
}

make_var :: proc(name: Token) -> ^Expr {
    expr := new(Expr)
    expr^ = Expr_Var{name}
    return expr
}

Parser :: struct {
    tokens: [dynamic]Token,
    curr: int,
    had_error: bool
}

parser: Parser

parser_init :: proc(tokens: [dynamic]Token) -> [dynamic]^Stmt {
    parser.tokens = slice.clone_to_dynamic(tokens[:])
    return parse()
}

parser_delete :: proc() {
    delete(parser.tokens)
}

parse :: proc() ->  [dynamic]^Stmt {
    stmts := make([dynamic]^Stmt, 0, 16)
    
    for !is_at_end() do append_elem(&stmts, declaration())

    return stmts
}

declaration :: proc() -> ^Stmt {
    stmt: ^Stmt
    stmt = var_declaration() if match(.VAR) else statement()

    if parser.had_error {
        sychronize()
        return nil
    }

    return stmt
}

var_declaration :: proc() -> ^Stmt {
    name := consume(.IDENTIFIER, "Expectet variable name.")

    initializer: ^Expr
    if match(.EQUAL) do expression()

    consume(.SEMICOLON, "Expect ';' after variable declaration.")
    
    stmt := new(Stmt)
    stmt^ = Stmt_Var{name, initializer}
    return stmt
}

statement :: proc() -> ^Stmt {
    if match(.PRINT) do return print_stmt()
    return expr_stmt()
}

expr_stmt :: proc() -> ^Stmt {
    exp := expression()
    consume(.SEMICOLON, "Expect ';' after value.")
    stmt := new(Stmt)
    stmt^ = Stmt_Expr{exp}
    return stmt
}

print_stmt :: proc() -> ^Stmt {
    exp := expression()
    consume(.SEMICOLON, "Expect ';' after value.")
    stmt := new(Stmt)
    stmt^ = Stmt_Print{exp}
    return stmt
}

parse_eval :: proc() -> ^Expr {
    exp := expression()
    if parser.had_error do return nil
    return exp
}

sychronize :: proc() {
    advance()

    for !is_at_end() {
        if previous().type == .SEMICOLON do return

        #partial switch peek().type {
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

@(private="file")
expression :: proc() -> ^Expr {
    return equality()
}

@(private="file")
equality :: proc() -> ^Expr {
    expr := comparison()
    for match(.BANG_EQUAL, .EQUAL_EQUAL) {
        op := previous()
        right := comparison()
        expr = make_binary(expr, op, right)
    }

    return expr
}

@(private="file")
comparison :: proc() -> ^Expr {
    expr := term()
    for match(.GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL) {
        op := previous()
        right := term()
        expr = make_binary(expr, op, right)
    }

    return expr
}

@(private="file")
term :: proc() -> ^Expr {
    expr := factor()
    for match(.MINUS, .PLUS) {
        op := previous()
        right := factor()
        expr = make_binary(expr, op, right)
    }

    return expr
}

@(private="file")
factor :: proc() -> ^Expr {
    expr := unary()
    for match(.STAR, .SLASH) {
        op := previous()
        right := unary()
        expr = make_binary(expr, op, right)
    }

    return expr
}

@(private="file")
unary :: proc() -> ^Expr {
    if match(.BANG, .MINUS) {
        op := previous()
        right := unary()
        return make_unary(op, right)
    }

    return primary()
}

@(private="file")
primary :: proc() -> ^Expr {
    if match(.FALSE)           do return make_literal(false)
    if match(.TRUE)            do return make_literal(true)
    if match(.NIL)             do return make_literal(nil)
    if match(.NUMBER, .STRING) do return make_literal(previous().literal)
    if match(.IDENTIFIER)      do return make_var(previous())

    if match(.LEFT_PAREN) {
        expr := expression()
        consume(.RIGHT_PAREN, "Expect '(' after expression.")
        return make_grouping(expr)
    }
    
    error(peek(), "Expected expression.")
    parser.had_error = true
    return nil
}

error :: proc(token: Token, msg: string) {
    if parser.had_error do return
    fmt.eprintf("[line %d]", token.line)

    if token.type == .EOF {
        fmt.eprintf(" at end")
    } else {
        fmt.eprintf("%d at %s, %s", token.line, token.lexeme, msg)
    }

    fmt.eprintf(": %s\n", msg)
    parser.had_error = true
}

// Helpers
@(private="file")
is_at_end :: proc() -> bool {
    return parser.tokens[parser.curr].type == .EOF
}

@(private="file")
check :: proc(type: TokenType) -> bool {
    if is_at_end() do return false
    return peek().type == type
}

@(private="file")
advance :: proc() -> Token {
    if !is_at_end() do parser.curr += 1
    return previous()
}

@(private="file")
peek :: proc() -> Token{
    return parser.tokens[parser.curr]
}

@(private="file")
previous :: proc() -> Token{
    return parser.tokens[parser.curr - 1]
}

@(private="file")
match :: proc(types: ..TokenType) -> bool {
    for type in types {
        if !check(type) do continue
        
        advance()
        return true
    }

    return false
}

@(private="file")
consume :: proc(type: TokenType, msg: string) -> Token {
    if check(type) do return advance()
    
    error(peek(), msg)
    return peek()
}
