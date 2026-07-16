package olox

import "core:fmt"

Env :: struct {
    values: map[string]Value,
    enclosing: ^Env
}

env_init :: proc(all_env: ^[dynamic]^Env, enclosing: ^Env = nil) -> ^Env {
    env := new(Env)
    env.values = make(map[string]Value)
    env.enclosing = enclosing
    append_elem(all_env, env)
    return env
}

env_delete :: proc(env: ^Env) {
    
}

env_define :: proc(env: ^Env, name: string, value: Value) {
    env.values[name] = value
}

env_get :: proc(i: ^Interpreter, env: ^Env, name: Token) -> Value {
    if v, ok := env.values[name.lexeme]; ok {
        return v
    }

    if (env.enclosing != nil) do return env_get(i, env.enclosing, name)
    
    runtime_error(i, name, fmt.tprintf("Undefined variable '%s'.", name.lexeme))
    return nil
}

env_set :: proc(i: ^Interpreter, env: ^Env, name: Token, value: Value) {
    if v, ok := env.values[name.lexeme]; ok {
        env.values[name.lexeme] = value
        return
    }

    if (env.enclosing != nil) {
        env_set(i, env.enclosing, name, value)
        return
    }
    
    runtime_error(i, name, fmt.tprintf("Undefined variable '%s'.", name.lexeme))
    return
}
