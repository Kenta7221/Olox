package olox

import "core:fmt"

// Cool things to add:
// Better error handling
// Adding more operations (modulo, bit manipulation)

// Changes:
// Add to default case switch in scanner lox error message
// Change somewhere the bool for checking an errors
// Clean the messy ass code you stinky bitch

main :: proc() {
    // if len(os.args) > 1 {
    //     fmt.eprintln("Unsufficient amount of args")
    //     fmt.eprintln("Usage: jlox [file]")
    //     fmt.eprintln("TODO todo todo todo do do")
    //     os.exit(1)
    // }

    // Step 1: Scan the tokens:
    scanner_init("test.txt")
    defer scanner_delete()
    
    for token in scanner.tokens {
        fmt.println(token)
    }

    // Step 2: Parse the tokens into an ast tree
    expr := parser_init(scanner.tokens)
    defer parser_delete()
    
    fmt.println(ast_print(expr))
}
