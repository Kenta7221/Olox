#+ feature dynamic-literals
package olox

import "core:fmt"
import "core:slice"

Parser :: struct {
    tokens: [dynamic]Token,
    curr: int,
    had_error: bool,
    all_expr: [dynamic]^Expr,
    all_stmts: [dynamic]^Stmt,
}

parser_init :: proc(tokens: [dynamic]Token) -> (p: Parser) {
    p.tokens = slice.clone_to_dynamic(tokens[:])
    return
}

parser_delete :: proc(p: ^Parser) {
    for s in p.all_stmts {
         free_stmt(s)
    }
    delete(p.all_stmts)
    delete(p.all_expr)
    delete(p.tokens)
}

free_expr :: proc(expr: ^Expr) {
    if expr == nil { return }
    switch e in expr^ {
    case Expr_Logical:
    case Expr_Binary:
        free_expr(e.left)
        free_expr(e.right)
    case Expr_Call:
        for arg in e.args do free_expr(arg)
        delete(e.args)
    case Expr_Grouping:
        free_expr(e.expr)
    case Expr_Unary:
        free_expr(e.right)
    case Expr_Literal:
    case Expr_Var:
    case Expr_Ass:
        free_expr(e.expr)
    }
    free(expr)
}

free_stmt :: proc(stmt: ^Stmt) {
    if stmt == nil { return }
    switch s in stmt^ {
    case Stmt_Expr:
        free_expr(s.expr)
    case Stmt_Print:
        free_expr(s.expr)
    case Stmt_Var:
        if s.initializer != nil {
            free_expr(s.initializer)
        }
    case Stmt_Block:
        for st in s.stmts {
            free_stmt(st)
        }
        delete(s.stmts)
    case Stmt_If:
        free_expr(s.cond)
        free_stmt(s.then_branch)
        if s.else_branch != nil {
            free_stmt(s.else_branch)
        }
    case Stmt_While:
        free_expr(s.cond)
        free_stmt(s.body)
    case Stmt_Function:
        for st in s.body {
            free_stmt(st)
        }
        delete(s.body)
        delete(s.params)
    case Stmt_Return:
        free_expr(s.value)
    }
    free(stmt)
}

parse :: proc(p: ^Parser) {
    for !is_at_end(p) do append_elem(&p.all_stmts, declaration(p))
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

// Helpers
is_at_end :: proc(p: ^Parser) -> bool {
    return p.tokens[p.curr].type == .EOF
}

check :: proc(p: ^Parser, type: TokenType) -> bool {
    if is_at_end(p) do return false
    return peek(p).type == type
}

advance :: proc(p: ^Parser) -> Token {
    if !is_at_end(p) do p.curr += 1
    return previous(p)
}

peek :: proc(p: ^Parser) -> Token{
    return p.tokens[p.curr]
}

previous :: proc(p: ^Parser) -> Token{
    return p.tokens[p.curr - 1]
}

match :: proc(p: ^Parser, types: ..TokenType) -> bool {
    for type in types {
        if !check(p, type) do continue
        
        advance(p)
        return true
    }

    return false
}

consume :: proc(p: ^Parser, type: TokenType, msg: string) -> Token {
    if check(p, type) do return advance(p)
    
    error(p, peek(p), msg)
    return peek(p)
}
