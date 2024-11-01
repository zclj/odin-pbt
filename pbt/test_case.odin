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
    recorded_choices := Recorded_Bits {
        data   = make([dynamic]u64, allocator),
        groups = make([dynamic]Group_Info, allocator)}
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

////
// Groups

Group_Label :: enum u8 {
    None,
    Choice,
    Weighted,
    Forced,
    Integer,
    String,
    Map,
}

begin_choice_group :: proc(test: ^Test_Case, label_id: Group_Label = .None) -> Group_Id {
    return begin_group(&test.choices.recorded, Label_Id(label_id))
}

end_choice_group :: proc(test: ^Test_Case, group_id: Group_Id) {
    end_group(&test.choices.recorded, group_id)
}

group_label_to_string :: proc(label: Group_Label) -> string {
    label_str: string

    // TODO: if this keeps beeing 1-1, use reflection instead
    switch label {
    case .None: label_str = "None"
    case .Choice: label_str = "Choice"
    case .Integer: label_str = "Integer"
    case .String: label_str = "String"
    case .Weighted: label_str = "Weighted"
    case .Forced: label_str = "Forced"
    case .Map: label_str = "Map"
    }

    return label_str
}

make_groups_report :: proc(test: ^Test_Case, data_limit: int = 20, allocator := context.temp_allocator) -> string {
    builder := strings.builder_make(allocator = allocator)

    strings.write_string(&builder, "Test case groups:\n")
    for group, idx in test.choices.recorded.groups {
        label_str := group_label_to_string(Group_Label(group.label_id))
        group_data := get_group_bits(test.choices.recorded, Group_Id(idx))

        data: []u64
        truncated: bool
        if len(group_data) > int(data_limit) {
            data = group_data[:data_limit]
            truncated = true
        } else {
            data = group_data
        }

        group_str := fmt.tprintf("Group %v: %v, [%v:%v] = %v", idx, label_str, group.begin, group.end, data)
        strings.write_string(&builder, group_str)
        if truncated {
            strings.write_string(&builder, "...")
        }
        strings.write_string(&builder, "\n")
    }

    return strings.to_string(builder)
}

////
// Reporting

make_test_report :: proc(test: ^Test_Case, format: string, args: ..any, allocator := context.temp_allocator) {
    str := fmt.aprintf(format, ..args, allocator = allocator)
    strings.write_string(&test.report_builder, str)
}

////
// Choices

for_choices :: proc(prefix: []u64, allocator := context.temp_allocator) -> Test_Case {
    test := create_test(len(prefix), allocator)

    append(&test.prefix.buffer, ..prefix)

    return test
}

// Number between [0, n]
// TODO: consolidate with 'weighted'
choice :: proc(test: ^Test_Case, n: u64) -> u64 {
    group_id := begin_choice_group(test, .Choice)
    defer end_choice_group(test, group_id)

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
    group_id := begin_choice_group(test, .Weighted)
    defer end_choice_group(test, group_id)

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
    group_id := begin_choice_group(test, .Forced)
    defer end_choice_group(test, group_id)

    if bits.len_u64(n) > 64 || n < 0 {
        panic("Forcing choice of invalid argument")
    }

    if len(test.choices.recorded.data) >= test.max_size  {
        test.status = .Overrun
        return 0
    }

    if len(test.prefix.buffer) > 0 {
        // Pop the prefix, and fail if the value is not the forced choice
        prefix := draw_bits_buffered(&test.prefix, bits.len_u64(n))
        if prefix != n {
            test.status = .Invalid
            return n
        }
    }

    append(&test.choices.recorded.data, n)
    return n
}
