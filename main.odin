package olox

import "core:fmt"
import "core:mem"
import "core:strings"

// Cool things to add:
// Better error handling
// Adding more operations (modulo, bit manipulation)
// Change parser structure so it doesn't copy lexers tokens

// Changes:
// Add to default case switch in scanner lox error message
// Change somewhere the bool for checking an errors

main :: proc() {
    // if len(os.args) > 1 {
    //     fmt.eprintln("Unsufficient amount of args")
    //     fmt.eprintln("Usage: jlox [file]")
    //     fmt.eprintln("TODO todo todo todo do do")
    //     os.exit(1)
    // }

    when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

    // Step 1: Scan the tokens:
    scanner_init("test.txt")
    defer scanner_delete()
    
    for token in scanner.tokens {
        fmt.println(token)
    }
    fmt.println("")

    // Step 2: Parse the tokens into an ast tree
    stmts := parser_init(scanner.tokens)
    defer parser_delete()

    // Step 3: Interpret
    interpret(stmts)
    
    // Checking if it works
    // expr := parse_eval()
    // sb, str := ast_print(expr)
    // defer strings.builder_destroy(&sb)
    // fmt.println(str)
    
    // Step 3: Evaluate
    // val := evaluate(expr)
    // fmt.println(val)
}
