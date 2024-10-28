package pbt

import "core:fmt"
import "core:math/bits"
import "core:math/rand"
import "core:strings"

Test_Error :: enum {
    Overrun,
    Invalid,
}

Test_Status :: enum {
    None,
    Overrun,     // Test did not have enough data to draw from
    Invalid,     // Test case contained values preventing completion
    Valid,       // Test completed but was not interesting
    Interesting, // Test completed and was interesting
}

Test_Case :: struct {
    max_size       : int,
    status         : Test_Status,
    prefix         : Buffered_Bit_Stream,
    choices        : Random_Bit_Stream,
    report_builder : strings.Builder,
}

BUFFER_SIZE :: 8 * 1024

create_test :: proc(max_size: int = BUFFER_SIZE, allocator := context.temp_allocator, loc := #caller_location) -> Test_Case {

    ////
    // Setup prefix
    recorded_prefix := Recorded_Bits { data = make([dynamic]u64, allocator) }
    prefix := Buffered_Bit_Stream {
        buffer   = make([dynamic]u64, allocator),
        recorded = recorded_prefix,
    }

    ////
    // Setup choices
    recorded_choices := Recorded_Bits { data = make([dynamic]u64, allocator) }
    choices := Random_Bit_Stream {
        recorded = recorded_choices,
    }

    ////
    // Report
    builder := strings.builder_make(allocator = allocator)
    
    return Test_Case {
        max_size       = max_size,
        prefix         = prefix,
        choices        = choices,
        report_builder = builder,
    }
}

make_test_report :: proc(test: ^Test_Case, format: string, args: ..any, allocator := context.temp_allocator) {
    str := fmt.aprintf(format, ..args, allocator = allocator)
    strings.write_string(&test.report_builder, str)
}

for_choices :: proc(prefix: []u64, allocator := context.temp_allocator) -> Test_Case {
    test := create_test(len(prefix), allocator)
    
    append(&test.prefix.buffer, ..prefix)
    
    return test
}

// Number between [0, n]
// TODO: consolidate with 'weighted'
choice :: proc(test: ^Test_Case, n: u64) -> u64 {
    // If there's a prefix draw from that, otherwise draw random

    // Fail if we try to draw more values than the test is allowed to draw.
    if len(test.choices.recorded.data) >= test.max_size {
        test.status = .Overrun
        return 0
    }

    bit_length := bits.len_u64(n)
    assert(bit_length <= 64 && bit_length >= 0)
    
    result: u64
    // Check for prefix data
    if len(test.prefix.buffer) > 0 {
        val := draw_bits_buffered(&test.prefix, bit_length)

        // Cap at n
        result = val % (n + 1)

        append(&test.choices.recorded.data, result)
    } else {
        // If there was no prefix, draw random
        choice := draw_bits_random(&test.choices, bit_length)
        // Cap at n
        result = choice % (n + 1)
    }
    
    assert(result <= n, "Choice is not in range")
    return result
}

// Return 'True' with probability 'p'
weighted :: proc(test: ^Test_Case, p: f32) -> bool {
    if len(test.choices.recorded.data) >= test.max_size {
        test.status = .Overrun
        return false
    }

    result: bool

    // Check for prefix data
    // TODO: Put some more thinking into this..
    if len(test.prefix.buffer) > 0 {
        val := draw_bits_buffered(&test.prefix, 1)
                
        append(&test.choices.recorded.data, val)
        return bool(val)
    }
    
    if p <= 0 {
        forced_choice(test, 0)
        result = false
    } else if p >= 1 {
        forced_choice(test, 1)
        result = true
    } else {
        // TODO: Prefer to make this an actual draw?
        weight := rand.float32() <= p
        forced_choice(test, u64(weight))
        result = weight
    }

    return result
}

// Add 'n' to the choice sequence, as if it was drawn.
// TODO: Consider draw bits and group recording.
forced_choice :: proc(test: ^Test_Case, n: u64) -> u64{
    if bits.len_u64(n) > 64 || n < 0 {
        panic("Forcing choice of invalid argument")
    }

    if len(test.choices.recorded.data) >= test.max_size  {
        test.status = .Overrun
        return 0
    }

    append(&test.choices.recorded.data, n)
    return n
}
