package pbt

draw_value :: proc(test_case: ^Test_Case, pos: Possibility($I, $V)) -> V {
    return pos.produce(test_case, pos.input)
}

draw_mapped_value :: proc(test_case: ^Test_Case, mapping: Map($I, $T, $U)) -> U {
    value: T = draw_value(test_case, mapping.pos)
    mapped := mapping.f(value)
    
    return mapped
}

draw_bound_value :: proc(test_case: ^Test_Case, binding: Bind($B, $I, $T, $U)) -> U {
    inner := draw_value(test_case, binding.pos)
    bound_pos := binding.f(inner)
    bound_value := draw_value(test_case, bound_pos)

    return bound_value
}

draw_satisfy_value :: proc(test_case: ^Test_Case, satisfy: Satisfy($I, $T)) -> (T, bool) {
    for _ in 0..<4 {
        candidate := draw_value(test_case, satisfy.pos)
        if satisfy.f(candidate) {
            return candidate, true
        }
    }
    
    test_case.status = .Invalid
    return T {}, false
}

draw :: proc{
    draw_value,
    draw_mapped_value,
    draw_bound_value,
    draw_satisfy_value}
