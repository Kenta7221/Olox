package olox

import "core:fmt"
import "core:mem"
import "core:strings"

// Things to change:
// Better error handling. I have no idea when error occurs in which part
// Change parser structure so it doesn't copy lexers tokens
// Adding more operations (modulo, bit manipulation)
// Change enviroment setting and finding from recursive to iterative

main :: proc() {    
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
    
    // if len(os.args) > 1 {
    //     fmt.eprintln("Unsufficient amount of args")
    //     fmt.eprintln("Usage: jlox [file]")
    //     fmt.eprintln("TODO todo todo todo do do")
    //     os.exit(1)
    // }

    lox := lox_init("temp")
    defer lox_delete(&lox)
    
    lox_run(&lox)
}
