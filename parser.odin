package olox

import "core:fmt"
import "core:slice"

Expr :: union {
    Binary,
    Grouping,
    Literal,
    Unary
}

Binary :: struct {
    left: ^Expr,
    op: Token,
    right: ^Expr
}

Grouping :: struct {
    expr: ^Expr
}

Literal :: struct {
    val: TokenLiteral
}

Unary :: struct {
    op: Token,
    right: ^Expr
}

make_binary :: proc(left: ^Expr, operator: Token, right: ^Expr) -> ^Expr {
    expr := new(Expr)
    expr^ = Binary{left, operator, right}
    return expr
}

make_unary :: proc(operator: Token, right: ^Expr) -> ^Expr { 
    expr := new(Expr)
    expr^ = Unary{operator, right}
    return expr
}

make_literal :: proc(val: TokenLiteral) -> ^Expr {
    expr := new(Expr)
    expr^ = Literal{val}
    return expr
}

make_grouping :: proc(left: ^Expr) -> ^Expr {
    expr := new(Expr)
    expr^ = Grouping{left}
    return expr
}

Parser :: struct {
    tokens: [dynamic]Token,
    curr: int,
    had_error: bool
}

parser: Parser

parser_init :: proc(parser: ^Parser, tokens: [dynamic]Token) {
    parser.tokens = slice.clone_to_dynamic(tokens[:])
    
    //
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
    for match(.MINUS, .PLUS) {
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

    if match(.LEFT_PAREN) {
        expr := expression()
        
        return make_grouping(expr)
    }

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
