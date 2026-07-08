package tests

import "core:testing"
import "core:log"
import "core:fmt"
import "core:strings"
import "core:os"
//import lox "../src"

@(test)
assgignment :: proc(t: ^testing.T) {
    w := os.walker_create("./tests/assignment")
	defer os.walker_destroy(&w)

	for info in os.walker_walk(&w) {
		if path, err := os.walker_error(&w); err != nil {
            log.errorf("failed walking %s: %s", path, err)
			continue
		}

		//log.info("%#v\n", info.fullpath)
	}

	if path, err := os.walker_error(&w); err != nil {
		log.errorf("failed walking %s: %v", path, err)
	}
}
