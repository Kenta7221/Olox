package olox

import "core:fmt"

Environment :: struct {
    values: map[string]Value,
    enclosing: ^Environment
}

environment_init :: proc(enclosing: ^Environment = nil) -> ^Environment {
    env := new(Environment)
    env.values = make(map[string]Value)
    env.enclosing = enclosing
    return env
}

environment_define :: proc(env: ^Environment, name: string, value: Value) {
    env.values[name] = value
}

environment_get :: proc(i: ^Interpreter, env: ^Environment, name: Token) -> Value {
    if v, ok := env.values[name.lexeme]; ok {
        return v
    }

    if (env.enclosing != nil) do return environment_get(i, env.enclosing, name)
    
    runtime_error(i, name, fmt.tprintf("Undefined variable '%s'.", name.lexeme))
    return nil
}

environment_set :: proc(i: ^Interpreter, env: ^Environment, name: Token, value: Value) {
    if v, ok := env.values[name.lexeme]; ok {
        env.values[name.lexeme] = value
        return
    }

    if (env.enclosing != nil) {
        environment_set(i, env.enclosing, name, value)
        return
    }
    
    runtime_error(i, name, fmt.tprintf("Undefined variable '%s'.", name.lexeme))
    return
}
