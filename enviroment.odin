package olox

import "core:fmt"

Environment :: struct {
    values: map[string]Value
}

environment_define :: proc(env: ^Environment, name: string, value: Value) {
    env.values[name] = value

    fmt.println(env.values)
}

environment_get :: proc(env: ^Environment, name: Token) -> Value {
    if value, ok := env.values[name.lexeme]; ok {
        return value
    }
    runtime_error(name, fmt.tprintf("Undefined variable '%s'.", name.lexeme))
    return nil
}
