package tests

import "core:testing"
import "core:math"
import "core:math/rand"

import "../pbt"

DEFAULT_TEST_N :: 10_000

////
// u8
@(test)
u8_draw :: proc(t: ^testing.T) {
    values_are_in_u8_range := proc(test: ^pbt.Test_Case) -> bool {
        value := pbt.draw(test, pbt.integers(0, 255))
                
        pbt.make_test_report(test, "Value: %v is not in u8 range", value)
        
        return value >= 0 && value <= 255
    }
    
    tc := pbt.check_property(values_are_in_u8_range, DEFAULT_TEST_N)

    expect_property_passed(t, tc)
}

////
// f32

@(test)
f32_draw_default_range :: proc(t: ^testing.T) {
    values_are_in_f32_range := proc(test: ^pbt.Test_Case) -> bool {
        value := pbt.draw(test, pbt.f32s())
                
        pbt.make_test_report(test, "Value: %v is not in f32 range", value)
        
        return value >= math.F32_MIN && value <= math.F32_MAX
    }
    
    tc := pbt.check_property(values_are_in_f32_range, DEFAULT_TEST_N)

    expect_property_passed(t, tc)
}

@(test)
f32_draw_range :: proc(t: ^testing.T) {
    values_are_in_f32_range := proc(test: ^pbt.Test_Case) -> bool {
        minimum := f32((i8(pbt.draw(test, u8s()))) / 10)
        maximum := minimum + 0.1 + f32(pbt.draw(test, u8s()) / 10)
        
        value := pbt.draw(test, pbt.f32s(minimum, maximum, 100))
                
        pbt.make_test_report(test, "Value: %v is not in f32 range [%v,%v]", value, minimum, maximum)
        
        //return value >= minimum && value <= maximum
        return value >= minimum && value <= (minimum + (maximum - minimum))
    }
    
    tc := pbt.check_property(values_are_in_f32_range, DEFAULT_TEST_N)

    expect_property_passed(t, tc)
}

@(test)
f32_draw_range_example :: proc(t: ^testing.T) {
    rand.reset(91982484577345)
    gen := pbt.f32s(-8.0, 0.099999905, 100)
    
    test := pbt.create_test()
    result := gen.produce(&test, gen.input)

    testing.expect_value(t, gen.input.range, 8.1)
    testing.expect_value(t, gen.input.minimum, -8.0)
    testing.expect_value(t, result, -2.0869994)
}

////
// f64

@(test)
f64_draw_range :: proc(t: ^testing.T) {
    values_are_in_range := proc(test: ^pbt.Test_Case) -> bool {
        minimum := f64((i8(pbt.draw(test, u8s()))) / 10)
        maximum := minimum + 0.1 + f64(pbt.draw(test, u8s()) / 10)
        
        value := pbt.draw(test, pbt.f64s(minimum, maximum, 100))
                
        pbt.make_test_report(test, "Value: %v is not in f64 range [%v,%v]", value, minimum, maximum)
        
        return value >= minimum && value <= (minimum + (maximum - minimum))
    }
    
    tc := pbt.check_property(values_are_in_range, DEFAULT_TEST_N)

    expect_property_passed(t, tc)
}

////
// Integers

@(test)
integers_creation :: proc(t: ^testing.T) {
    ints_pos := pbt.integers(10, 100)
    ints := ints_pos.input

    testing.expect_value(t, ints.minimum, 10)
    testing.expect_value(t, ints.range, 90)
}

@(test)
integers_between_min_max :: proc(t: ^testing.T) {
    values_are_between_min_max := proc(test: ^pbt.Test_Case) -> bool {
        minimum := i64(pbt.draw(test, u8s()))
        maximum := minimum + 1 + i64(pbt.draw(test, u8s()))
        
        value := pbt.draw(test, pbt.integers(i64(minimum), i64(maximum)))
        
        pbt.make_test_report(
            test, "Min: %v, Max: %v, Value: %v", minimum, maximum, value)
        
        return value >= u64(minimum) && value <= u64(maximum)
    }
    
    tc := pbt.check_property(values_are_between_min_max, DEFAULT_TEST_N)

    expect_property_passed(t, tc)
}

@(test)
integers_negative_min_max :: proc(t: ^testing.T) {
    values_are_between_min_max := proc(test: ^pbt.Test_Case) -> bool {
        minimum := -56
        maximum := -2
        
        value := pbt.draw(test, pbt.integers(i64(minimum), i64(maximum)))
        
        pbt.make_test_report(
            test, "Min: %v, Max: %v, Value: %v", minimum, maximum, value)
        
        return i8(value) <= -2 && i8(value) >= -56
    }
    
    tc := pbt.check_property(values_are_between_min_max, DEFAULT_TEST_N)

    expect_property_passed(t, tc)
}

////
// Bools

@(test)
bools_with_zero_weight_are_false :: proc(t: ^testing.T) {
    bools_zero := proc(test: ^pbt.Test_Case) -> bool {
        value := pbt.draw(test, pbt.bools(0))
        
        pbt.make_test_report(
            test, "Value: %v", value)
        
        return value == false
    }
    
    tc := pbt.check_property(bools_zero, DEFAULT_TEST_N)

    expect_property_passed(t, tc)
}

@(test)
bools_with_one_weight_are_true :: proc(t: ^testing.T) {
    bools_zero := proc(test: ^pbt.Test_Case) -> bool {
        value := pbt.draw(test, pbt.bools(1.0))
        
        pbt.make_test_report(
            test, "Value: %v", value)
        
        return value == true
    }
    
    tc := pbt.check_property(bools_zero, DEFAULT_TEST_N)

    expect_property_passed(t, tc)
}

bool_distribution : [DEFAULT_TEST_N]bool
bool_count := 0

@(test)
bools_are_distributed :: proc(t: ^testing.T) {
    bools_zero := proc(test: ^pbt.Test_Case) -> bool {
        value := pbt.draw(test, pbt.bools(0.5))
        
        pbt.make_test_report(
            test, "Value: %v", value)

        bool_distribution[bool_count] = value
        bool_count += 1
        
        return true
    }
    
    tc := pbt.check_property(bools_zero, DEFAULT_TEST_N)

    true_count, false_count: int
    for b in bool_distribution {
        if b {
            true_count += 1
        } else {
            false_count += 1
        }
    }

    // Sanity check
    testing.expect_value(t, bool_count, DEFAULT_TEST_N)

    // Arbitrary range is +/- 150
    testing.expect(t, false_count < 5150 && false_count > 4850, "False distribution outside range")
    testing.expect(t, true_count < 5150 && true_count > 4850, "True distribution outside range")
    
    expect_property_passed(t, tc)
}

////
// Strings
//
import "core:strings"

@(test)
strings_utf8_draw :: proc(t: ^testing.T) {
    string_length_between_min_max := proc(test: ^pbt.Test_Case) -> bool {
        min_size := u64(pbt.draw(test, u8s()))
        max_size := min_size + 1 + u64(pbt.draw(test, u8s()))
        value := pbt.draw(test, pbt.strings_utf8(min_size, max_size))
        //value := pbt.draw(test, pbt.strings(min_size, max_size, 0x30A0, 0x30FF))
        
        length := u64(strings.rune_count(value))

        //fmt.println("Value: ", value)
        pbt.make_test_report(
            test, "Min: %v, Max: %v, Value: %s, Length: %v", min_size, max_size, value, length)
        
        return length >= min_size && length <= max_size
        //return !strings.contains(value, "💃")
    }
    
    tc := pbt.check_property(string_length_between_min_max, DEFAULT_TEST_N)

    expect_property_passed(t, tc)
}

@(test)
strings_alpha_numeric_draw :: proc(t: ^testing.T) {
    string_length_between_min_max := proc(test: ^pbt.Test_Case) -> bool {
        min_size := u64(pbt.draw(test, u8s()))
        max_size := min_size + 1 + u64(pbt.draw(test, u8s()))
        value := pbt.draw(test, pbt.strings_alphabet(pbt.ALPHA_NUMERIC, min_size, max_size))

        length := u64(strings.rune_count(value))

        pbt.make_test_report(
            test, "Min: %v, Max: %v, Value: %s, Length: %v", min_size, max_size, value, length)

        is_an := true
        for c in value {
            is_an = strings.contains_rune(
                "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWQXYZ", c)
            if is_an == false {
                break
            }
        }
        
        return is_an || length == 0
    }
    
    tc := pbt.check_property(string_length_between_min_max, DEFAULT_TEST_N)

    expect_property_passed(t, tc)
}

//import "core:fmt"
@(test)
strings_alphabet_draw :: proc(t: ^testing.T) {
    string_length_between_min_max := proc(test: ^pbt.Test_Case) -> bool {
        alphabet := "0123456789!#$%&'*+-/=^_`{|}~"
        
        min_size := u64(pbt.draw(test, u8s()))
        max_size := min_size + 1 + u64(pbt.draw(test, u8s()))
        
        value := pbt.draw(test, pbt.strings_alphabet(alphabet, min_size, max_size))

        length := u64(strings.rune_count(value))

        pbt.make_test_report(
            test, "Min: %v, Max: %v, Value: %s, Length: %v", min_size, max_size, value, length)

        //fmt.println("Value: ", value)
        is_an := true
        for c in value {
            is_an = strings.contains_rune(alphabet, c)
            if is_an == false {
                break
            }
        }
        
        return is_an || length == 0
    }
    
    tc := pbt.check_property(string_length_between_min_max, DEFAULT_TEST_N)

    expect_property_passed(t, tc)
}
