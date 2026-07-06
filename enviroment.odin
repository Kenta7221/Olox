package olox

import "core:fmt"

Environment :: struct {
    values: map[string]Value
}

environment_define :: proc(env: ^Environment, name: string, value: Value) {
    env.values[name] = value
}

environment_get :: proc(env: ^Environment, name: Token) -> Value {
    if v, ok := env.values[name.lexeme]; ok {
        return v
    }
    runtime_error(name, fmt.tprintf("Undefined variable '%s'.", name.lexeme))
    return nil
}

environment_set :: proc(env: ^Environment, name: Token, value: Value) {
    if v, ok := env.values[name.lexeme]; ok {
        env.values[name.lexeme] = value
        return
    }
    runtime_error(name, fmt.tprintf("Undefined variable '%s'.", name.lexeme))
    return
}
