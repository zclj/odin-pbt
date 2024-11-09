package pbt

import "core:math"

////////////////////////////////////////
// Possibilities

Possibility :: struct($Input, $Value: typeid) {
    input: Input,
    produce: proc(^Test_Case, Input) -> Value,
}

// See https://odin-lang.org/docs/overview/#basic-types for Odins basic types

////
// Integer ranges

Integers :: struct {
    minimum: i64,
    range: u64,
}

integers :: proc(minimum: i64, maximum: i64) -> Possibility(Integers, u64) {
    assert(minimum < maximum)
    
    ints:= Integers {
        minimum = minimum,
        range   = u64(maximum - minimum),
    }
    
    pos := Possibility(Integers, u64) {
        input = ints,
        produce = proc(test_case: ^Test_Case, ints: Integers) -> u64 {
            group_id := begin_choice_group(test_case, .Integer)
            defer end_choice_group(test_case, group_id)

            offset := choice(test_case, ints.range)
            return u64(ints.minimum) + offset
        },
    }
    
    return pos
}

////
// Bools

Bools :: struct {
    weight: f32,
}

bools :: proc(weight: f32 = 0.5) -> Possibility(Bools, bool) {
    assert(weight >= 0.0 && weight <= 1.0)
    
    bools := Bools {
        weight = weight,
    }
    
    return Possibility(Bools, bool) {
        input   = bools,
        produce = proc(test_case: ^Test_Case, bools: Bools) -> bool {
            return weighted(test_case, bools.weight)
            //return choice(test_case, 1) == 1
        },
    }
}

////
// f32

// https://pkg.odin-lang.org/core/math/

// f32 layout:
// (1b)  31    -> sign
// (8b)  30-23 -> exponent
// (23b) 22-0  -> fraction/mantissa

// Value = sign * mantissa * base^exponent (base 2)

// The exponent is stored using a bias of 127. So, the actual exponent (Exp) is calculated as: exp - 127

Floats32 :: struct {
    minimum : f32,
    range   : f32,
    steps   : f32,
}

f32s :: proc(minimum: f32 = math.F32_MIN, maximum: f32 = math.F32_MAX, steps: f32 = 1000) -> Possibility(Floats32, f32) {

    float_range := Floats32 {
        minimum = minimum,
        range   = maximum - minimum,
        steps   = steps,
    }
    
    return Possibility(Floats32, f32) {
        input   = float_range,
        produce = proc(test_case: ^Test_Case, floats: Floats32) -> f32 {
            offset_choice := choice(test_case, u64(floats.steps))
            
            percentage_of_range := f32(offset_choice) / floats.steps
            
            offset := percentage_of_range * floats.range
                        
            result := floats.minimum + offset
            
            // Due to floats, make sure we clamp at maxium.
            // NOTE: This is not a problem for min as we add an offset to min.
            return min(result, (floats.minimum + floats.range))
        },
    }
}

////
// f64

Floats64 :: struct {
    minimum : f64,
    range   : f64,
    steps   : f64,
}

f64s :: proc(minimum: f64 = math.F64_MIN, maximum: f64 = math.F64_MAX, steps: f64 = 1000) -> Possibility(Floats64, f64) {

    float_range := Floats64 {
        minimum = minimum,
        range   = maximum - minimum,
        steps   = steps,
    }
    
    return Possibility(Floats64, f64) {
        input   = float_range,
        produce = proc(test_case: ^Test_Case, floats: Floats64) -> f64 {
            offset_choice := choice(test_case, u64(floats.steps))
            
            percentage_of_range := f64(offset_choice) / floats.steps
            
            offset := percentage_of_range * floats.range
                        
            result := floats.minimum + offset
            
            // Due to floats, make sure we clamp at maxium.
            // NOTE: This is not a problem for min as we add an offset to min.
            return min(result, (floats.minimum + floats.range))
        },
    }
}

////
// Strings

import "core:strings"

Strings_UTF8 :: struct {
    min_size: u64,
    max_size: u64,
    min_utf8: u32,
    max_utf8: u32,
}

strings_utf8 :: proc(min_size: u64, max_size: u64, min_utf8: u32 = 0, max_utf8: u32 = 0x10FFFF) -> Possibility(Strings_UTF8, string) {
    assert(max_utf8 <= 0x10FFFF, "Outside UTF-8 range")
        
    str := Strings_UTF8 {
        min_size = min_size,
        max_size = max_size,
        min_utf8 = min_utf8,
        max_utf8 = max_utf8,
    }

    pos := Possibility(Strings_UTF8, string) {
        input = str,
        produce = proc(test_case: ^Test_Case, str: Strings_UTF8) -> string {
            builder := strings.builder_make(context.temp_allocator)
            rune_count: int
            
            for more(test_case, rune_count, str.min_size, str.max_size){
                val := draw(test_case, integers(i64(str.min_utf8), i64(str.max_utf8)))
                rune_count += 1

                strings.write_rune(&builder, rune(val))
            }

            return strings.to_string(builder)
        },
    }

    return pos
}

Strings_AN :: struct {
    min_size: u64,
    max_size: u64,
}

strings_alpha_numeric :: proc(min_size: u64, max_size: u64) -> Possibility(Strings_AN, string) {

    str := Strings_AN {
        min_size = min_size,
        max_size = max_size,
    }

    pos := Possibility(Strings_AN, string) {
        input = str,
        produce = proc(test_case: ^Test_Case, str: Strings_AN) -> string {
            builder := strings.builder_make(context.temp_allocator)
            rune_count: u64

            group_id := begin_choice_group(test_case, .String)
            defer end_choice_group(test_case, group_id)
            
            for {
                if rune_count < str.min_size {
                    forced_choice(test_case, 1)
                } else if rune_count + 1 >= str.max_size {
                    forced_choice(test_case, 0)
                    break
                } else if !weighted(test_case, 0.9) {
                    break
                }

                // 62 different options
                char_choice := choice(test_case, 61)
                
                if char_choice <= 9 {
                    // 0-9, 48-57  = 0-9
                    char_choice += 48
                } else if char_choice > 9 && char_choice <= 35 {
                    // A-Z, 65-90  = 10-35
                    char_choice += 55
                } else if char_choice > 35 && char_choice <= 61 {
                    // a-z, 97-122 = 36-61
                    char_choice += 61
                } else {
                    panic("Alpha numberic choice is out of range")
                }
                                
                rune_count += 1

                strings.write_rune(&builder, rune(char_choice))
            }

            return strings.to_string(builder)
        },
    }

    return pos
}

Strings_Alphabet :: struct {
    alphabet: string,
    min_size: u64,
    max_size: u64,
}

strings_alphabet :: proc(alphabet: string, min_size: u64, max_size: u64) -> Possibility(Strings_Alphabet, string) {

    str := Strings_Alphabet {
        alphabet = alphabet,
        min_size = min_size,
        max_size = max_size,
    }
    
    pos := Possibility(Strings_Alphabet, string) {
        input = str,
        produce = proc(test_case: ^Test_Case, str: Strings_Alphabet) -> string {
            builder := strings.builder_make(context.temp_allocator)
            rune_count: u64
            
            for {
                if rune_count < str.min_size {
                    forced_choice(test_case, 1)
                } else if rune_count + 1 >= str.max_size {
                    forced_choice(test_case, 0)
                    break
                } else if !weighted(test_case, 0.9) {
                    break
                }

                // Choice an index in the alphabet
                char_choice := choice(test_case, u64(len(str.alphabet) - 1))

                char := str.alphabet[char_choice]
                                
                rune_count += 1

                strings.write_rune(&builder, rune(char))
            }

            return strings.to_string(builder)
        },
    }

    return pos
}
