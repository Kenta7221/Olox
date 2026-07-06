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
    arena    : vmem.Arena,
    start    : int,
    curr     : int,
    line     : int
}

scanner: Scanner

scanner_init :: proc(source: string) {
    scanner.source, scanner.arena = load_file(source)
    scanner.tokens = make([dynamic]Token, 0, 16)
    scanner.line = 1
    
    scanner.keywords = make(map[string]TokenType, len(TokenType))
    scanner.keywords["and"]    = .AND
    scanner.keywords["class"]  = .CLASS
    scanner.keywords["else"]   = .ELSE
    scanner.keywords["false"]  = .FALSE
    scanner.keywords["for"]    = .FOR
    scanner.keywords["fun"]    = .FUN
    scanner.keywords["if"]     = .IF
    scanner.keywords["nil"]    = .NIL
    scanner.keywords["or"]     = .OR
    scanner.keywords["print"]  = .PRINT
    scanner.keywords["return"] = .RETURN
    scanner.keywords["super"]  = .SUPER
    scanner.keywords["this"]   = .THIS
    scanner.keywords["true"]   = .TRUE
    scanner.keywords["var"]    = .VAR
    scanner.keywords["while"]  = .WHILE
    
    scan_tokens()
    
    return
}

scanner_delete :: proc() {
    delete(scanner.tokens)
    delete(scanner.keywords)
    vmem.arena_destroy(&scanner.arena)
}

@(private="file")
scan_tokens :: proc() {
    for !is_at_end() {
        scanner.start = scanner.curr
        scan_token()
    }

    append_elem(&scanner.tokens, Token{ type = .EOF })
}

@(private="file")
scan_token :: proc() {
    b := advance()

    switch b {
    // One character lexemes
    case '(': add_token(.LEFT_PAREN)
    case ')': add_token(.RIGHT_PAREN)
    case '{': add_token(.LEFT_BRACE)
    case '}': add_token(.RIGHT_BRACE)
    case ',': add_token(.COMMA)
    case '.': add_token(.DOT)
    case '-': add_token(.MINUS)
    case '+': add_token(.PLUS)
    case ';': add_token(.SEMICOLON)
    case '*': add_token(.STAR)
    // Potentialy two character lexemes
    case '!':
        token := TokenType.BANG_EQUAL    if match('=') else TokenType.BANG
        add_token(token)
    case '=':
        token := TokenType.EQUAL_EQUAL   if match('=') else TokenType.EQUAL
        add_token(token)
    case '<':
        token := TokenType.LESS_EQUAL    if match('=') else TokenType.LESS
        add_token(token)
    case '>':
        token := TokenType.GREATER_EQUAL if match('=') else TokenType.GREATER
        add_token(token)
    case '/':
        if match('/') {
            for peek() != '\n' do advance()
            break
        }

        if match('*') {
            for peek() != '*' && peek_next() != '/' {
                advance()

                if peek() == '\n' do scanner.line += 1

                if scanner.curr >= len(scanner.source) {
                    fmt.eprintln("Missing closing brackets for multi line comments")
                    return
                }
            }
            break;
        }
        
        add_token(.SLASH)
    case '"':
        parse_string()
    case ' ':
    case '\r':
    case '\t':
        break
    case '\n':
        scanner.line += 1
        case:
        if is_digit(b) {
            parse_digit()
            break
        } else if is_alpha(b) {
            parse_identifier()
            break
        }
        
        fmt.eprintln("Unexpected character", scanner.line)
    }
}

// Methods
@(private="file")
is_at_end :: proc() -> bool { return scanner.curr >= len(scanner.source) }

@(private="file")
advance :: proc() -> u8 {
    scanner.curr += 1
    return scanner.source[scanner.curr - 1]
}

@(private="file")
match :: proc(expected: u8) -> bool {
    if scanner.curr >= len(scanner.source) do return false
    if scanner.source[scanner.curr] != expected do return false
    
    scanner.curr += 1
    return true
}

@(private="file")
peek :: proc() -> u8 {
    if is_at_end() do return '\n'
    return scanner.source[scanner.curr]
}

@(private="file")
peek_next :: proc() -> u8 {
    if scanner.curr + 1 >= len(scanner.source) do return '\n'
    return scanner.source[scanner.curr + 1]
}

// Helpers
@(private="file")
parse_digit :: proc() {
    for is_digit(peek()) do advance()

    if peek() == '.' && is_digit(peek_next()) {
        advance()
        for is_digit(peek()) do advance()
    }

    str, str_err := strings.substring(scanner.source, scanner.start, scanner.curr)
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

    add_token(.NUMBER, literal)
}

@(private="file")
parse_string :: proc() {
    for peek() != '"' && !is_at_end() {
        if peek() == '\n' do scanner.line += 1
        advance()
    }

    if scanner.curr >= len(scanner.source) {
        fmt.eprintln("Unterminated string")
        return
    }

    // Skip the firt "
    scanner.start += 1
    
    literal: Value
    literal, _ = strings.substring(scanner.source, scanner.start, scanner.curr)
    add_token(.STRING, literal)
    
    // The closing "
    advance()
}

@(private="file")
parse_identifier :: proc() {
    b := scanner.source[scanner.curr]
    for is_alpha_numeric(peek()) do b = advance()

    str, err := strings.substring(scanner.source, scanner.start, scanner.curr)
    if !err {
        fmt.eprintln("Could not parse the lexeme")
        return
    }

    type, ok := scanner.keywords[str]
    if !ok do type = .IDENTIFIER

    add_token(type)
}

add_token :: proc {
    add_token_noval,
    add_token_val,
}

@(private="file")
add_token_noval :: proc(type: TokenType) {
    lexeme, err := strings.substring(scanner.source, scanner.start, scanner.curr)
    if !err {
        fmt.eprintln("Could not parse the lexeme")
        return
    }

    token := Token{
        type = type,
        lexeme = lexeme,
        line = scanner.line
    }

    append_elem(&scanner.tokens, token)
}

@(private="file")
add_token_val :: proc(type: TokenType, literal: Value) {
    lexeme, err := strings.substring(scanner.source, scanner.start, scanner.curr)
    if !err {
        fmt.eprintln("Could not parse the lexeme")
        return
    }
    
    token := Token{
        type = type,
        lexeme = lexeme,
        literal = literal,
        line = scanner.line
    }

    append_elem(&scanner.tokens, token)
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
