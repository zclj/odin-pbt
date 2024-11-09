package pbt

import "core:slice"

////////////////////////////////////////
// Combinators

////
// Satisfy

Satisfy :: struct($Input, $Pos: typeid) {
    pos: Possibility(Input, Pos),
    f: proc(Pos) -> bool,
}

satisfy:: proc(possibility: Possibility($I, $T), f: proc(T) -> bool) -> Possibility(Satisfy(I, T), T) {
    satisfy_input := Satisfy(I, T) {
        pos = possibility,
        f = f,
    }

    pos := Possibility(Satisfy(I, T), T) {
        input   = satisfy_input,
        produce = proc(test_case: ^Test_Case, satisfy: Satisfy(I, T)) -> T {
            for _ in 0..<4 {
                candidate := draw(test_case, satisfy.pos)
                if satisfy.f(candidate) {
                    return candidate
                }
            }

            test_case.status = .Invalid
            return T {}
        },
    }

    return pos
}

////
// Map

Map :: struct($Input, $Pos, $Ret: typeid) {
    pos: Possibility(Input, Pos),
    f: proc(Pos) -> Ret,
}

mapping :: proc(possibility: Possibility($I, $T), f: proc(T) -> $U) -> Possibility(Map(I, T, U), U) {
    mapping_input := Map(I, T, U) {
        pos = possibility,
        f = f,
    }

    pos := Possibility(Map(I, T, U), U) {
        input = mapping_input,
        produce = proc(test_case: ^Test_Case, mapping_input: Map(I, T, U)) -> U {
            value: T = draw(test_case, mapping_input.pos)
            mapped := mapping_input.f(value)

            return mapped
        },
    }

    return pos
}

////
// Bind

Bind :: struct($BInput, $Input, $Pos, $Val: typeid) {
    pos: Possibility(BInput, Pos),
    f: proc(Pos) -> Possibility(Input, Val),
}

bind :: proc(possibility: Possibility($B, $T), f: proc(T) -> Possibility($I, $U)) -> Possibility(Bind(B, I, T, U), U) {

    binding := Bind(B, I, T, U) {
        pos = possibility,
        f = f,
    }

    pos := Possibility(Bind(B, I, T, U), U) {
        input = binding,
        produce = proc(test_case: ^Test_Case, binding: Bind(B, I, T, U)) -> U {
            inner := draw(test_case, binding.pos)
            bound_pos := binding.f(inner)
            bound_value := draw(test_case, bound_pos)

            return bound_value
        },
    }

    return pos
}

////////////////////////////////////////
// Selection

////
// One_Of

One_Of :: struct($I, $T: typeid) {
    elements: [dynamic]Possibility(I, T),
}

one_of :: proc(one_of: []Possibility($I, $T)) -> Possibility(One_Of(I, T), T) {
    assert(len(one_of) >= 2)

    elements := slice.clone_to_dynamic(one_of, context.temp_allocator)
    one_ofs := One_Of(I, T) {
        elements = elements,
    }

    pos := Possibility(One_Of(I, T), T) {
        input = one_ofs,
        produce = proc(test_case: ^Test_Case, one_of: One_Of(I, T)) -> T {
            elem_idx := choice(test_case, u64(len(one_of.elements) - 1))

            selected := one_of.elements[elem_idx]

            return draw(test_case, selected)
        },
    }

    return pos
}

////
// Frequency

Frequency :: struct($I, $V: typeid) {
    frequency  : u8,
    possibility: Possibility(I, V),
}

Frequency_Element :: struct($I, $V: typeid) {
    frequency   : Frequency(I, V),
    range_start : u64,
    range_end   : u64,
}

Frequencies :: struct($I, $V: typeid) {
    freqs: [dynamic]Frequency_Element(I, V),
    total: u64,
}

frequency :: proc(fs: []Frequency($I, $V)) -> Possibility(Frequencies(I, V), V) {
    assert(len(fs) >= 2)

    elements := make([dynamic]Frequency_Element(I, V), context.temp_allocator)
    total: u64
    for f in fs {
        element := Frequency_Element(I, V) {
            frequency   = f,
            range_start = total,
            range_end   = total + u64(f.frequency),
        }

        append(&elements, element)
        total += u64(f.frequency)
    }

    fq := Frequencies(I, V) {
        freqs = elements,
        total = total,
    }

    pos := Possibility(Frequencies(I, V), V) {
        input = fq,
        produce = proc(test_case: ^Test_Case, fs: Frequencies(I, V)) -> V {
            selected_range := choice(test_case, fs.total)

            selected: Frequency(I, V)
            for f in fs.freqs {
                if f.range_start <= selected_range && f.range_end >= selected_range {
                    selected = f.frequency
                    break
                }
            }

            return draw(test_case, selected.possibility)
        },
    }

    return pos
}
