package tests

import "core:testing"
import "core:slice"

import "../pbt"

//import "core:fmt"

////
// Lists
@(test)
lists_draw :: proc(t: ^testing.T) {
    values_and_length_are_in_range := proc(test: ^pbt.Test_Case) -> bool {
        min_size := pbt.draw(test, pbt.integers(0, 100))
        range    := pbt.draw(test, pbt.integers(1, 100))
        max_size := min_size + range
        
        value := pbt.draw(test, pbt.lists(pbt.integers(0, 255), min_size, max_size))
                
        pbt.make_test_report(
            test, "Value: %v is not in range, length [%v, %v]", value, min_size, max_size)

        list_length := u64(len(value))

        lower, _  := slice.filter(
            value[:], proc(v: u64) -> bool { return v < 0 }, context.temp_allocator)
        any_lower := len(lower) > 0

        higher, _  := slice.filter(
            value[:], proc(v: u64) -> bool { return v > 255 }, context.temp_allocator)
        any_higher := len(higher) > 0
                
        return list_length >= min_size && list_length <= max_size &&
            !any_lower && !any_higher
    }
    
    tc := pbt.check_property(values_and_length_are_in_range, DEFAULT_TEST_N)

    expect_property_passed(t, tc)
}

////
// Maps

@(test)
maps_draw :: proc(t: ^testing.T) {
    maps_are_in_range := proc(test: ^pbt.Test_Case) -> bool {
        min_size := pbt.draw(test, pbt.integers(0, 100))
        range    := pbt.draw(test, pbt.integers(1, 100))
        max_size := min_size + range
        
        value := pbt.draw(
            test, pbt.maps(pbt.strings_alphabet(pbt.ALPHA_NUMERIC, 1, 50), pbt.integers(0, 255), min_size, max_size))
        
        pbt.make_test_report(
            test, "Value: %v is not in range, length [%v, %v]", value, min_size, max_size)

        list_length := u64(len(value))

        m_values,_ := slice.map_values(value, context.temp_allocator)
        lower := slice.filter(m_values, proc(v: u64) -> bool { return v < 0 }, context.temp_allocator)
        any_lower := len(lower) > 0

        higher, _  := slice.filter(
            m_values, proc(v: u64) -> bool { return v > 255 }, context.temp_allocator)
        any_higher := len(higher) > 0
                
        return list_length >= min_size && list_length <= max_size &&
            !any_lower && !any_higher        
    }
    
    tc := pbt.check_property(maps_are_in_range, DEFAULT_TEST_N)

    expect_property_passed(t, tc)
}
