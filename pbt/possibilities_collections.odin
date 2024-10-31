package pbt

//import "core:log"

////
// Lists

Lists :: struct($I, $T: typeid) {
    elements: Possibility(I, T),
    min_size: u64,
    max_size: u64,
}

lists :: proc(elements: Possibility($I, $T), min_size: u64, max_size: u64) -> Possibility(Lists(I, T), []T) {

    list := Lists(I, T) {
        elements = elements,
        min_size = min_size,
        max_size = max_size,
    }
    
    pos := Possibility(Lists(I, T), []T) {
        input = list,
        produce = proc(test_case: ^Test_Case, list: Lists(I, T)) -> []T {
            result := make([dynamic]T, 0, int(list.max_size), context.temp_allocator)
            for {
                if len(result) < int(list.min_size) {
                    forced_choice(test_case, 1)
                } else if len(result) + 1 >= int(list.max_size) {
                    forced_choice(test_case, 0)
                    break
                } else if !weighted(test_case, 0.9) {
                    break
                }

                val := draw(test_case, list.elements)
                append(&result, val)
            }

            return result[:]
        },
    }
    
    return pos
}

Maps :: struct($I, $T, $U, $V: typeid) {
    keys    : Possibility(I, T),
    vals    : Possibility(U, V),
    min_size: u64,
    max_size: u64,
}

maps :: proc(keys: Possibility($I, $T), vals: Possibility($U, $V), min_size: u64, max_size: u64) -> Possibility(Maps(I, T, U, V), map[T]V) {

    map_input := Maps(I, T, U, V) {
        keys     = keys,
        vals     = vals,
        min_size = min_size,
        max_size = max_size,
    }

    pos := Possibility(Maps(I, T, U, V), map[T]V) {
        input   = map_input,
        produce = proc(test_case: ^Test_Case, map_input: Maps(I, T, U, V)) -> map[T]V {
            result := make(map[T]V, context.temp_allocator)

            map_group_id := begin_choice_group(test_case, .Map)
            defer end_choice_group(test_case, map_group_id)
            for {
                if len(result) < int(map_input.min_size) {
                    //log.debugf("Force draw map entry, min size")
                    forced_choice(test_case, 1)
                } else if len(result) + 1 >= int(map_input.max_size) {
                    //log.debugf("Force stop draw map entry, max size")
                    forced_choice(test_case, 0)
                    break
                } else if !weighted(test_case, 0.9) {
                    //log.debugf("Weighted stop draw map entry")
                    break
                }

                // A duplicate key will not add to the length of the map and run the risk
                //  of making us stuck. Therefor, if we cannot draw a non-existing key
                //  the test is invalid.
                key: T
                new_key_found: bool
                for _ in 0..<4 {
                    key_candidate := draw(test_case, map_input.keys)
                    //log.debugf("Draw map key: %v", key_candidate)

                    exists := key_candidate in result
                    if !exists {
                        key = key_candidate
                        new_key_found = true
                        break
                    }
                }

                if !new_key_found {
                    //log.debug("Cannot draw key not already in map")
                    test_case.status = .Invalid
                    break
                }
                
                val := draw(test_case, map_input.vals)
                //log.debugf("Draw map value: %v", val)

                result[key] = val
            }

            return result
        },
    }
    
    return pos
}
