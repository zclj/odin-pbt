package tests

import "core:testing"

import "../pbt"

//import "core:fmt"

////
// Satisfies

@(test)
satisfies_draw :: proc(t: ^testing.T) {
    odd_draws := proc(test: ^pbt.Test_Case) -> bool {
        
        value := pbt.draw(
            test, pbt.satisfy(pbt.integers(0, 100), proc(x: u64) -> bool { return x % 2 == 1 }))
        
        pbt.make_test_report(test, "Value: %v is not even", value)
        
        return value % 2 == 1
    }
    
    tc := pbt.check_property(odd_draws, DEFAULT_TEST_N)

    pbt.expect_property_passed(t, tc)
}

////
// Map

@(test)
mapping_draw :: proc(t: ^testing.T) {
    multiplied := proc(test: ^pbt.Test_Case) -> bool {
        value := pbt.draw(
            test, pbt.mapping(pbt.integers(1, 10), proc(x: u64) -> u64 { return x * 100 }))

        pbt.make_test_report(test, "%v is not in range", value)

        return value >= 100 && value <= 1000
    }

    tc := pbt.check_property(multiplied, DEFAULT_TEST_N)

    pbt.expect_property_passed(t, tc)
}

////
// Bind

@(test)
bind_draw :: proc(t: ^testing.T) {
    multiplied := proc(test: ^pbt.Test_Case) -> bool {
        value := pbt.draw(
            test, pbt.bind(
                pbt.integers(10, 20),
                proc(x: u64) -> pbt.Possibility(pbt.Integers, u64) {
                    return pbt.integers(i64(x), 100) }))

        pbt.make_test_report(test, "%v is not in range", value)

        return value >= 10 && value <= 100
    }

    tc := pbt.check_property(multiplied, DEFAULT_TEST_N)

    pbt.expect_property_passed(t, tc)
}

////
// One of

@(test)
one_of_draw_input :: proc(t: ^testing.T) {
    draw_is_in_range := proc(test: ^pbt.Test_Case) -> bool {
        elements := []pbt.Possibility(pbt.Integers, u64){
            pbt.integers(0, 10), pbt.integers(190, 200),
        }
        value := pbt.draw(test, pbt.one_of(elements),)
                
        return value >= 0 && value <= 10 || value >= 190 && value <= 200
    }
    
    tc := pbt.check_property(draw_is_in_range, DEFAULT_TEST_N)

    pbt.expect_property_passed(t, tc)
}

////
// Frequency

@(test)
frequency_draw :: proc(t: ^testing.T) {
    draw_is_in_range := proc(test: ^pbt.Test_Case) -> bool {
        elements := []pbt.Frequency(pbt.Integers, u64){
            pbt.Frequency(pbt.Integers, u64){
                frequency = 1, possibility = pbt.integers(0, 10), },
            pbt.Frequency(pbt.Integers, u64){
                frequency = 1, possibility = pbt.integers(180, 190), },
            pbt.Frequency(pbt.Integers, u64){
                frequency = 10, possibility = pbt.integers(240, 250), },
        }
        pos := pbt.frequency(elements)
        value := pbt.draw(test, pos,)
                                        
        return value >= 0 && value <= 255
    }
    
    tc := pbt.check_property(draw_is_in_range, DEFAULT_TEST_N)

    pbt.expect_property_passed(t, tc)
}
