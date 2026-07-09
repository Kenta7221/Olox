package tests

import "core:testing"
import "core:log"
import "core:strings"
import "core:os"
import lox "../src"

@(test)
assgignment :: proc(t: ^testing.T) {
    w := os.walker_create("./tests/assignment")
	defer os.walker_destroy(&w)

	for info in os.walker_walk(&w) {
		if path, err := os.walker_error(&w); err != nil {
            log.errorf("failed walking %s: %s", path, err)
			continue
		}

        l := lox.lox_init(info.fullpath)
        defer lox.lox_delete(&l)

        lox.lox_run(&l)
	}

	if path, err := os.walker_error(&w); err != nil {
		log.errorf("failed walking %s: %v", path, err)
	}
}
