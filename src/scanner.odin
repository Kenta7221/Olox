#+feature dynamic-literals
package olox

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

import vmem "core:mem/virtual"

Scanner :: struct {
    tokens   : [dynamic]Token,
    keywords : map[string]TokenType,
    source   : string,
    start    : int,
    curr     : int,
    line     : int
}

scanner_init :: proc(source: string) -> (s: Scanner) {
    s.source = source
    s.tokens = make([dynamic]Token, 0, 16)
    s.line = 1
    
    s.keywords = make(map[string]TokenType, len(TokenType))
    s.keywords["and"]    = .AND
    s.keywords["class"]  = .CLASS
    s.keywords["else"]   = .ELSE
    s.keywords["false"]  = .FALSE
    s.keywords["for"]    = .FOR
    s.keywords["fun"]    = .FUN
    s.keywords["if"]     = .IF
    s.keywords["nil"]    = .NIL
    s.keywords["or"]     = .OR
    s.keywords["print"]  = .PRINT
    s.keywords["return"] = .RETURN
    s.keywords["super"]  = .SUPER
    s.keywords["this"]   = .THIS
    s.keywords["true"]   = .TRUE
    s.keywords["var"]    = .VAR
    s.keywords["while"]  = .WHILE
    
    return
}

scanner_delete :: proc(s: ^Scanner) {
    delete(s.tokens)
    delete(s.keywords)
}

scan_tokens :: proc(s: ^Scanner) {
    for !is_at_end(s) {
        s.start = s.curr
        scan_token(s)
    }

    append_elem(&s.tokens, Token{ type = .EOF })
}

@(private="file")
scan_token :: proc(s: ^Scanner) {
    b := advance(s)

    switch b {
    // One character lexemes
    case '(': add_token(s, .LEFT_PAREN)
    case ')': add_token(s, .RIGHT_PAREN)
    case '{': add_token(s, .LEFT_BRACE)
    case '}': add_token(s, .RIGHT_BRACE)
    case ',': add_token(s, .COMMA)
    case '.': add_token(s, .DOT)
    case '-': add_token(s, .MINUS)
    case '+': add_token(s, .PLUS)
    case ';': add_token(s, .SEMICOLON)
    case '*': add_token(s, .STAR)
    // Potentialy two character lexemes
    case '!':
        token := TokenType.BANG_EQUAL    if match(s, '=') else TokenType.BANG
        add_token(s, token)
    case '=':
        token := TokenType.EQUAL_EQUAL   if match(s, '=') else TokenType.EQUAL
        add_token(s, token)
    case '<':
        token := TokenType.LESS_EQUAL    if match(s, '=') else TokenType.LESS
        add_token(s, token)
    case '>':
        token := TokenType.GREATER_EQUAL if match(s, '=') else TokenType.GREATER
        add_token(s, token)
    case '/':
        if match(s, '/') {
            for peek(s) != '\n' do advance(s)
            break
        }

        if match(s, '*') {
            for peek(s) != '*' && peek_next(s) != '/' {
                advance(s)

                if peek(s) == '\n' do s.line += 1

                if s.curr >= len(s.source) {
                    fmt.eprintln("Missing closing brackets for multi line comments")
                    return
                }
            }
            break;
        }
        
        add_token(s, TokenType.SLASH)
    case '"':
        parse_string(s)
    case ' ':
    case '\r':
    case '\t':
        break
    case '\n':
        s.line += 1
        case:
        if is_digit(b) {
            parse_digit(s)
            break
        } else if is_alpha(b) {
            parse_identifier(s)
            break
        }
        
        fmt.eprintln("Unexpected character", s.line)
    }
}

// Methods
@(private="file")
is_at_end :: proc(s: ^Scanner) -> bool { return s.curr >= len(s.source) }

@(private="file")
advance :: proc(s: ^Scanner) -> u8 {
    s.curr += 1
    return s.source[s.curr - 1]
}

@(private="file")
match :: proc(s: ^Scanner, expected: u8) -> bool {
    if s.curr >= len(s.source) do return false
    if s.source[s.curr] != expected do return false
    
    s.curr += 1
    return true
}

@(private="file")
peek :: proc(s: ^Scanner) -> u8 {
    if is_at_end(s) do return '\n'
    return s.source[s.curr]
}

@(private="file")
peek_next :: proc(s: ^Scanner) -> u8 {
    if s.curr + 1 >= len(s.source) do return '\n'
    return s.source[s.curr + 1]
}

// Helpers
@(private="file")
parse_digit :: proc(s: ^Scanner) {
    for is_digit(peek(s)) do advance(s)

    if peek(s) == '.' && is_digit(peek_next(s)) {
        advance(s)
        for is_digit(peek(s)) do advance(s)
    }

    str, str_err := strings.substring(s.source, s.start, s.curr)
    if !str_err {
        fmt.eprintln("Could not parse the subtring of source to number")
        return
    }
    
    literal: Value
    lit_err: bool
    literal, lit_err = strconv.parse_f64(str)
    if !lit_err {
        fmt.eprintln("Could not parse the string into number literal")
    }

    add_token(s, .NUMBER, literal)
}

@(private="file")
parse_string :: proc(s: ^Scanner) {
    for peek(s) != '"' && !is_at_end(s) {
        if peek(s) == '\n' do s.line += 1
        advance(s)
    }

    if s.curr >= len(s.source) {
        fmt.eprintln("Unterminated string")
        return
    }

    // Skip the firt "
    s.start += 1
    
    literal: Value
    literal, _ = strings.substring(s.source, s.start, s.curr)
    add_token(s, .STRING, literal)
    
    // The closing "
    advance(s)
}

@(private="file")
parse_identifier :: proc(s: ^Scanner) {
    b := s.source[s.curr]
    for is_alpha_numeric(peek(s)) do b = advance(s)

    str, err := strings.substring(s.source, s.start, s.curr)
    if !err {
        fmt.eprintln("Could not parse the lexeme")
        return
    }

    type, ok := s.keywords[str]
    if !ok do type = .IDENTIFIER

    add_token(s, type)
}

add_token :: proc {
    add_token_noval,
    add_token_val,
}

@(private="file")
add_token_noval :: proc(s: ^Scanner, type: TokenType) {
    lexeme, err := strings.substring(s.source, s.start, s.curr)
    if !err {
        fmt.eprintln("Could not parse the lexeme")
        return
    }

    token := Token{
        type = type,
        lexeme = lexeme,
        line = s.line
    }

    append_elem(&s.tokens, token)
}

@(private="file")
add_token_val :: proc(s: ^Scanner, type: TokenType, literal: Value) {
    lexeme, err := strings.substring(s.source, s.start, s.curr)
    if !err {
        fmt.eprintln("Could not parse the lexeme")
        return
    }
    
    token := Token{
        type = type,
        lexeme = lexeme,
        literal = literal,
        line = s.line
    }

    append_elem(&s.tokens, token)
}

// Helpers
@(private="file")
load_file :: proc(filepath: string) -> (string, vmem.Arena) {
    arena: vmem.Arena
    arena_err := vmem.arena_init_growing(&arena)
    
    if arena_err != nil {
        fmt.eprintln("Error creating arena allocator")
        os.exit(1)
    }
    arena_alloc := vmem.arena_allocator(&arena)

    file, err := os.read_entire_file(filepath, arena_alloc)
    if err != os.ERROR_NONE {
        fmt.eprintln("Could not open the file", filepath)
        os.exit(1)
    }
    
    return string(file), arena
}

@(private="file")
is_digit :: proc(b: u8) -> bool { return b >= '0' && b <= '9' }

@(private="file")
is_alpha :: proc(b: u8) -> bool {
    return (b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z') || (b == '_')
}

@(private="file")
is_alpha_numeric :: proc(b: u8) -> bool { return is_digit(b) || is_alpha(b) }
