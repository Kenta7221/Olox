package olox

TokenType :: enum {
    // Single-character token
    LEFT_PAREN, RIGHT_PAREN, LEFT_BRACE, RIGHT_BRACE,
    COMMA, DOT, MINUS, PLUS, SEMICOLON, SLASH, STAR,

    // One or two character token
    BANG, BANG_EQUAL,
    EQUAL, EQUAL_EQUAL,
    GREATER, GREATER_EQUAL,
    LESS, LESS_EQUAL,

    // Literals
    IDENTIFIER, STRING, NUMBER,

    // Keywords
    AND, CLASS, ELSE, FALSE, FUN, FOR, IF, NIL, OR,
    PRINT, RETURN, SUPER, THIS, TRUE, VAR, WHILE,

    EOF
}

Token :: struct {
    type:   TokenType,
    lexeme: string,
    literal: Value,
    line :  int
}

Lox_Function :: struct {
    declaration: ^Stmt_Function, // TEMP,
    closure: ^Env
}

Native_Function :: struct {
    arity: int,
    fn: proc(args: [dynamic]Value) -> Value
}

check_arinity :: proc(calle: Value) -> int {
    #partial switch c in calle {
        case ^Lox_Function:
        return len(c.declaration.params)
        case ^Native_Function:
        return c.arity
    }

    return 0
}

Value :: union {
    string,
    f64,
    bool,
    ^Lox_Function,
    ^Native_Function
}
