package tests

import "core:testing"

import "../pbt"

@(test)
create_test :: proc(t: ^testing.T) {
    default_test := pbt.create_test()

    specified_test := pbt.create_test(42)

    testing.expect_value(t, default_test.max_size, pbt.BUFFER_SIZE)
    testing.expect_value(t, specified_test.max_size, 42)
}

@(test)
choice :: proc(t: ^testing.T) {
    test := pbt.create_test()

    choosen: [1000]u64
    for i in 0..<1000 {
        choosen[i] = pbt.choice(&test, 10)
    }

    above_n: int
    for c in choosen {
        if c > 10 {
            above_n += 1
        }
    }

    // The boundary should hold
    testing.expect_value(t, above_n, 0)
    testing.expect_value(t, test.status, pbt.Test_Status.None)
    //expect_equal_slices(t, choosen[:], []u64{})
    
}

@(test)
for_choices :: proc(t: ^testing.T) {
    prefix := [3]u64{1, 2, 3}
    
    test := pbt.for_choices(prefix[:], context.temp_allocator)

    testing.expect_value(t, len(test.prefix.buffer), 3)
}

@(test)
choice_with_prefix :: proc(t: ^testing.T) {
    test := pbt.for_choices({1, 2})
                
    result_1 := pbt.choice(&test, 255)
    result_2 := pbt.choice(&test, 255)

    testing.expect_value(t, result_1, u64(1))
    testing.expect_value(t, result_2, u64(2))

    testing.expect_value(t, len(test.prefix.buffer), 0)
    testing.expect_value(t, len(test.choices.recorded.data), 2)
}
