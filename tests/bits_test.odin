package tests

import "core:testing"
import "core:math/rand"
import "core:math/bits"
import "core:slice"

import "../pbt"

////
// Draw random bits

@(test)
draw_bits_random :: proc(t: ^testing.T) {
    rand.reset(1)

    recorded := pbt.Recorded_Bits { data = make([dynamic]u64, context.temp_allocator) }
    stream := pbt.Random_Bit_Stream {
        recorded = recorded,
    }

    result := pbt.draw_bits_random(&stream, 8)

    // We get a drawn value
    testing.expect_value(t, u64(193), result)
    // The value is recorded
    testing.expect_value(t, 1, len(stream.recorded.data))
    testing.expect_value(t, u64(193), stream.recorded.data[0])
}

@(test)
draw_bits_random_are_in_bit_range :: proc(t: ^testing.T) {
    property_fn := proc(test: ^pbt.Test_Case) -> bool {
        recorded := pbt.Recorded_Bits { data = make([dynamic]u64, context.temp_allocator) }
        stream := pbt.Random_Bit_Stream {
            recorded = recorded,
        }
        
        nrof_bits  := int(pbt.draw(test, pbt.integers(0, 64)))
                
        value := pbt.draw_bits_random(&stream, nrof_bits)
        bit_length := bits.len_u64(value)

        pbt.make_test_report(
            test, "Out of bit range, expected %v, got %v (value drawn: %v)",
            nrof_bits, bit_length, value)
        
        // The bit length of the value drawn cannot be larger than the drawn number of bits
        return bit_length <= nrof_bits
    }

    tc := pbt.check_property(property_fn, DEFAULT_TEST_N)

    expect_property_passed(t, tc)
}

@(test)
draw_bits_random_are_recorded :: proc(t: ^testing.T) {
    property_fn := proc(test: ^pbt.Test_Case) -> bool {
        recorded := pbt.Recorded_Bits { data = make([dynamic]u64, context.temp_allocator) }
        stream := pbt.Random_Bit_Stream {
            recorded = recorded,
        }

        // Draw the number of bits and the number of draws
        nrof_bits  := int(pbt.draw(test, pbt.integers(0, 64)))
        nrof_draws := pbt.draw(test, pbt.integers(1, 1000))

        values_drawn := make([dynamic]u64, context.temp_allocator)
        for _ in 0..<nrof_draws {
            value := pbt.draw_bits_random(&stream, nrof_bits)
            append(&values_drawn, value)
        }
        
        pbt.make_test_report(
            test,
            "Values drawn are not the same as recorded. Expected: %v, got %v",
            values_drawn[:], stream.recorded.data[:])
        
        return slice.equal(stream.recorded.data[:], values_drawn[:])
    }
    
    tc := pbt.check_property(property_fn, DEFAULT_TEST_N)

    expect_property_passed(t, tc)
}
