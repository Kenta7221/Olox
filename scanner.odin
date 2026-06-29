#+feature dynamic-literals
package olox

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

import vmem "core:mem/virtual"

Scanner :: struct {
    tokens: [dynamic]Token,
    keywords: map[string]TokenType,
    source: string,
    arena: vmem.Arena,
    start: int,
    curr: int,
    line: int
}

scanner_init :: proc(source: string) -> (scanner: Scanner) {
    scanner.source, scanner.arena = load_file(source)
    scanner.tokens = make([dynamic]Token, 0, 16)

    scanner.keywords = make(map[string]TokenType, len(TokenType))
    scanner.keywords["and"] = TokenType.AND
    scanner.keywords["class"] = TokenType.CLASS
    scanner.keywords["else"] = TokenType.ELSE
    scanner.keywords["false"] = TokenType.FALSE
    scanner.keywords["for"] = TokenType.FOR
    scanner.keywords["fun"] = TokenType.FUN
    scanner.keywords["if"] = TokenType.IF
    scanner.keywords["nil"] = TokenType.NIL
    scanner.keywords["or"] = TokenType.OR
    scanner.keywords["print"] = TokenType.PRINT
    scanner.keywords["return"] = TokenType.RETURN
    scanner.keywords["super"] = TokenType.SUPER
    scanner.keywords["this"] = TokenType.THIS
    scanner.keywords["true"] = TokenType.TRUE
    scanner.keywords["var"] = TokenType.VAR
    scanner.keywords["while"] = TokenType.WHILE
    
    scan_tokens(&scanner)
    
    return
}

scanner_delete :: proc(scanner: ^Scanner) {
    delete(scanner.tokens)
    vmem.arena_destroy(&scanner.arena)
}

scan_tokens :: proc(scanner: ^Scanner) {
    for scanner.curr < len(scanner.source) {
        b := scanner.source[scanner.curr]
        scanner.curr += 1
        
        switch b {
        // One character lexemes
        case '(': add_token(scanner, TokenType.LEFT_PAREN)
        case ')': add_token(scanner, TokenType.RIGHT_PAREN)
        case '{': add_token(scanner, TokenType.LEFT_BRACE)
        case '}': add_token(scanner, TokenType.RIGHT_BRACE)
        case ',': add_token(scanner, TokenType.COMMA)
        case '.': add_token(scanner, TokenType.DOT)
        case '-': add_token(scanner, TokenType.MINUS)
        case '+': add_token(scanner, TokenType.PLUS)
        case ';': add_token(scanner, TokenType.SEMICOLON)
        case '*': add_token(scanner, TokenType.STAR)
        // Potentialy two character lexemes
        case '!':
            token := TokenType.BANG_EQUAL if match(&scanner.source, &scanner.curr, '=') else TokenType.BANG
            add_token(scanner, token)
        case '=':
            token := TokenType.EQUAL_EQUAL if match(&scanner.source, &scanner.curr, '=') else TokenType.EQUAL
            add_token(scanner, token)
        case '<':
            token := TokenType.LESS_EQUAL if match(&scanner.source, &scanner.curr, '=') else TokenType.LESS
            add_token(scanner, token)
        case '>':
            token := TokenType.GREATER_EQUAL if match(&scanner.source, &scanner.curr, '=') else TokenType.GREATER
            add_token(scanner, token)
        case '/':
            if !match(&scanner.source, &scanner.curr, '/') {
                add_token(scanner, TokenType.SLASH)
                break
            }
            for peek(&scanner.source, scanner.curr) != '\n' do scanner.curr += 1
        case '"':
            parse_string(scanner)
        case ' ':
        case '\r':
        case '\t':
            break
        case '\n':
            scanner.line += 1
        case:
            if is_digit(b) {
                parse_digit(scanner)
                break
            }
            // TODO: Change to lox error
            fmt.eprintln("Unexpected character", scanner.line)
        }
        scanner.start = scanner.curr
    }
}

@(private="file")
parse_digit :: proc(scanner: ^Scanner) {
    for is_digit(peek(&scanner.source, scanner.curr)) do scanner.curr += 1

    if peek(&scanner.source, scanner.curr) == '.' && is_digit(peek_next(&scanner.source, scanner.curr)) {
        scanner.curr += 1
        for is_digit(peek(&scanner.source, scanner.curr)) do scanner.curr += 1
    }

    str, str_err := strings.substring(scanner.source, scanner.start, scanner.curr)
    if !str_err {
        fmt.eprintln("Could not parse the subtring of source to number")
        return
    }
    
    literal: TokenLiteral
    lit_err: bool
    literal, lit_err = strconv.parse_f64(str)
    if !lit_err {
        fmt.eprintln("Could not parse the string into number literal")
    }

    add_token(scanner, TokenType.NUMBER, literal)
}

@(private="file")
parse_string :: proc(scanner: ^Scanner) {
    for peek(&scanner.source, scanner.curr) != '"' && scanner.curr < len(scanner.source) {
        if peek(&scanner.source, scanner.curr) == '\n' do scanner.line += 1
        scanner.curr += 1
    }

    if scanner.curr >= len(scanner.source) {
        fmt.eprintln("Unterminated string")
        return
    }

    scanner.start += 1
    
    literal: TokenLiteral
    literal, _ = strings.substring(scanner.source, scanner.start, scanner.curr)
    add_token(scanner, TokenType.STRING, literal)
    
    // The closing "
    scanner.curr += 1
}

parse_identifier :: proc(scanner: ^Scanner) {
    b := scanner.source[scanner.curr]
    for is_alpha_numeric(b) {
        scanner.curr += 1
        b = scanner.source[scanner.curr]
    }

    str, err := strings.substring(scanner.source, scanner.start, scanner.curr)
    if !err {
        fmt.eprintln("Could not parse the lexeme")
        return
    }

    type, ok := scanner.keywords[str]
    if !ok do type = TokenType.IDENTIFIER

    add_token(scanner, type)
}

@(private="file")
match :: proc(source: ^string, curr: ^int, expected: u8) -> bool {
    if curr^ >= len(source) do return false
    if source[curr^] != expected do return false
    
    curr^ += 1
    return true
}

@(private="file")
peek :: proc(source: ^string, curr: int) -> u8 {
    if curr >= len(source) do return '\n'
    return source[curr]
}

@(private="file")
peek_next :: proc(source: ^string, curr: int) -> u8 {
    if curr + 1 >= len(source) do return '\n'
    return source[curr + 1]
}

add_token :: proc {
    add_token_noval,
    add_token_val,
}

@(private="file")
add_token_noval :: proc(scanner: ^Scanner, type: TokenType) {
    // TODO: Check if it is successfull
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
add_token_val :: proc(scanner: ^Scanner, type: TokenType, literal: TokenLiteral) {
    // TODO: Check if it is successfull
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

@(private="file")
load_file :: proc(filepath: string) -> (string, vmem.Arena) {
    arena: vmem.Arena
    arena_err := vmem.arena_init_growing(&arena)
    
    if arena_err != nil {
        fmt.eprintln("Error creating arena allocator")
        os.exit(1)
    }
    arena_alloc := vmem.arena_allocator(&arena)

    file, err := os.read_entire_file(filepath, context.allocator)
    if err != os.ERROR_NONE {
        fmt.eprintln("Could not open the file", filepath)
        os.exit(1)
    }

    
    buf := string(file)

    return buf, arena
}

@(private="file")
is_digit :: proc(b: u8) -> bool { return b >= '0' && b <= '9' }

is_alpha :: proc(b: u8) -> bool {
    return (b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z') || (b == '_')
}

is_alpha_numeric :: proc(b: u8) -> bool { return is_digit(b) || is_alpha(b) }
