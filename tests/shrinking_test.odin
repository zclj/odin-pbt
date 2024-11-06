package tests

import "core:testing"
import "core:slice"

import "../pbt"

@(test)
shrinking_do_not_break :: proc(t: ^testing.T) {
    property := proc(test: ^pbt.Test_Case) -> bool {
        fake_result := pbt.draw(test, pbt.lists(pbt.integers(0, 1_000_000), 0, 100))

        property_ctx := pbt.make_context(proc(test: ^pbt.Test_Case) -> bool { return true })
        defer pbt.delete_context(property_ctx)

        property_ctx.result = slice.clone_to_dynamic(fake_result[:])

        pbt.shrink(&property_ctx)

        // Always pass
        return true
    }

    ctx := pbt.check_property(property, 10_000)
    defer pbt.delete_context(ctx)

    testing.expect_value(t, ctx.failed, false)
    expect_equal_slices(t, ctx.result[:], []u64{})
}

@(test)
shrink_remove_blocks :: proc(t: ^testing.T) {
    property := proc(tc: ^pbt.Test_Case) -> bool {
        attempt := tc.prefix.buffer
        return !(len(attempt) >= 4 && (attempt[2] + attempt[3]) > 106 && attempt[2] > 18 && attempt[3] > 28)
    }

    tc := pbt.make_context(property)

    tc.result   = {123, 25, 393, 58, 67, 90, 5, 3}

    pbt.shrink_remove_blocks(&tc)
    defer delete(tc.result)

    expect_equal_slices(t, tc.result[:], []u64{123, 25, 393, 58})
}

@(test)
shrink_remove_blocks_container_example :: proc(t: ^testing.T) {
    property := proc(tc: ^pbt.Test_Case) -> bool {
        attempt := tc.prefix.buffer
        return !(len(attempt) == 6 &&
                 attempt[0] == 1 &&   // <- Map forced to 1
                 attempt[1] == 1 &&   // <- String forced to 1
                 attempt[2] == 36 &&  // <- String element choice
                 attempt[3] == 0 &&   // <- String forced to 0
                 attempt[4] == 10 &&  // <- Key choice
                 attempt[5] == 0)     // <- Weighted stop for map keys
    }

    tc := pbt.make_context(property)

    tc.result   = {1, 1, 0, 0, 0, 1, 1, 36, 0, 10, 0}

    pbt.shrink_remove_blocks(&tc)
    defer delete(tc.result)

    expect_equal_slices(t, tc.result[:], []u64{1, 1, 36, 0, 10, 0})
}


@(test)
shrink_zero_blocks :: proc(t: ^testing.T) {
    fail_first_zero := proc(tc: ^pbt.Test_Case) -> bool {
        attempt := tc.prefix.buffer
        return !(attempt[1] == 0 && attempt[3] > 0)
    }

    tc := pbt.make_context(fail_first_zero)

    tc.result   = {34, 67, 89, 129}

    pbt.shrink_zero_blocks(&tc)
    defer delete(tc.result)

    expect_equal_slices(t, tc.result[:], []u64{34, 0, 0, 129})
}

@(test)
shrink_zero_blocks_different_sizes :: proc(t: ^testing.T) {
    fail_first_zero := proc(tc: ^pbt.Test_Case) -> bool {
        attempt := tc.prefix.buffer
        return !(attempt[0] == 0 && attempt[1] == 0 && attempt[2] > 0)
    }

    tc := pbt.make_context(fail_first_zero)

    tc.result   = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}

    pbt.shrink_zero_blocks(&tc)
    defer delete(tc.result)

    expect_equal_slices(t, tc.result[:], []u64{0, 0, 3, 4, 5, 6, 7, 8, 9, 10})
}

@(test)
shrink_reduce :: proc(t: ^testing.T) {
    property := proc(tc: ^pbt.Test_Case) -> bool {
        attempt := tc.prefix.buffer
        return !(attempt[2] > 50)
    }

    tc := pbt.make_context(property)

    tc.result   = {123, 25, 393, 4,}

    pbt.shrink_reduce(&tc)
    defer delete(tc.result)

    expect_equal_slices(t, tc.result[:], []u64{0, 0, 51, 0,})
}

@(test)
shrink_reduce_dependant_values :: proc(t: ^testing.T) {
    property := proc(tc: ^pbt.Test_Case) -> bool {
        attempt := tc.prefix.buffer
        return !(attempt[2] > 50 && attempt[3] > 50 && attempt[0] > attempt [3])
    }

    tc := pbt.make_context(property)

    tc.result   = {123, 25, 393, 58, 67, 90, 5, 3}

    pbt.shrink_reduce(&tc)
    defer delete(tc.result)

    expect_equal_slices(t, tc.result[:], []u64{52, 0, 51, 51, 0, 0, 0, 0})
}

@(test)
shrink_reduce_should_not_pass_boundary :: proc(t: ^testing.T) {
    property := proc(tc: ^pbt.Test_Case) -> bool {
        attempt := tc.prefix.buffer
        return !((attempt[2] + attempt[3]) > 106)
    }

    tc := pbt.make_context(property)

    tc.result   = {123, 25, 393, 58, 0, 0, 0, 0}

    pbt.shrink_reduce(&tc)
    defer delete(tc.result)

    expect_equal_slices(t, tc.result[:], []u64{0, 0, 107, 0, 0, 0, 0, 0})
}

@(test)
shrink_reduce_should_not_shrink_minimal_value :: proc(t: ^testing.T) {
    property := proc(tc: ^pbt.Test_Case) -> bool {
        attempt := tc.prefix.buffer
        return !(attempt[2] > 50 && attempt[3] > 50 && attempt[0] > attempt [3])
    }

    tc := pbt.make_context(property)

    tc.result   = {52, 0, 51, 51, 0, 0, 0, 0}

    pbt.shrink_reduce(&tc)
    defer delete(tc.result)

    expect_equal_slices(t, tc.result[:], []u64{52, 0, 51, 51, 0, 0, 0, 0})
}

@(test)
shrink_sort :: proc(t: ^testing.T) {
    property := proc(tc: ^pbt.Test_Case) -> bool {
        attempt := tc.prefix.buffer
        return !(attempt[2] > 50 && attempt[3] > 50 && attempt[0] > attempt [3])
    }

    tc := pbt.make_context(property)

    tc.result   = {123, 25, 393, 58, 67, 90, 5, 3}

    pbt.shrink_sort(&tc)
    defer delete(tc.result)

    expect_equal_slices(t, tc.result[:], []u64{123, 25, 58, 67, 90, 393, 5, 3})
}

@(test)
shrink_redistribute :: proc(t: ^testing.T) {
    property := proc(tc: ^pbt.Test_Case) -> bool {
        attempt := tc.prefix.buffer
        return !((attempt[2] + attempt[3]) > 106 && attempt[2] > 18 && attempt[3] > 28)
    }

    tc := pbt.make_context(property)

    tc.result   = {0, 0, 78, 29, 0, 0, 0, 0}

    pbt.shrink_redistribute(&tc, tc.result[:])
    defer delete(tc.result)

    expect_equal_slices(t, tc.result[:], []u64{0, 0, 19, 88, 0, 0, 0, 0})
}

@(test)
shrink_swap_larger :: proc(t: ^testing.T) {
    property := proc(tc: ^pbt.Test_Case) -> bool {
        attempt := tc.prefix.buffer
        return !((attempt[2] + attempt[3]) > 106 && attempt[2] > 18 && attempt[3] > 28)
    }

    tc := pbt.make_context(property)

    tc.result   = {1, 2, 78, 29, 0, 0, 0, 0}

    defer delete(tc.result)

    pbt.shrink_swap(&tc)

    expect_equal_slices(t, tc.result[:], []u64{1, 2, 29, 78, 0, 0, 0, 0})
}

@(test)
shrink_swap_don_not_swap_ordered :: proc(t: ^testing.T) {
    property := proc(tc: ^pbt.Test_Case) -> bool {
        attempt := tc.prefix.buffer
        return !((attempt[2] + attempt[3]) > 106 && attempt[2] > 18 && attempt[3] > 28)
    }

    tc := pbt.make_context(property)

    tc.result   = {1, 2, 29, 78, 0, 0, 0, 0}

    defer delete(tc.result)

    pbt.shrink_swap(&tc)

    expect_equal_slices(t, tc.result[:], []u64{1, 2, 29, 78, 0, 0, 0, 0})
}

@(test)
swap_combinations :: proc(t: ^testing.T) {
    choices :[4]u64 = {1, 2, 4, 3}
    new_attempts := make([dynamic][dynamic]u64)
    defer {
        for a in new_attempts {
            delete(a)
        }

        delete(new_attempts)
    }

    pbt.swap_combinations(choices[:], 1, &new_attempts)

    testing.expect_value(t, 1, len(new_attempts))
    expect_equal_slices(t, new_attempts[0][:], []u64{1, 2, 3, 4})
}

@(test)
swap_combinations_zeros :: proc(t: ^testing.T) {
    choices :[6]u64 = {0, 0, 10, 0, 0, 0}
    new_attempts := make([dynamic][dynamic]u64)
    defer {
        for a in new_attempts {
            delete(a)
        }

        delete(new_attempts)
    }

    pbt.swap_combinations(choices[:], 1, &new_attempts)

    testing.expect_value(t, 1, len(new_attempts))
    testing.expect_value(t, true, slice.equal(new_attempts[0][:], []u64{0, 0, 0, 10, 0, 0}))
}

@(test)
zero_combinations :: proc(t: ^testing.T) {
    choices :[4]u64 = {1, 2, 3, 4}
    new_attempts := make([dynamic][dynamic]u64)
    defer {
        for a in new_attempts {
            delete(a)
        }

        delete(new_attempts)
    }

    pbt.zero_combinations(choices[:], 2, &new_attempts)

    testing.expect_value(t, 3, len(new_attempts))

    testing.expect_value(t, true, slice.equal(new_attempts[0][:], []u64{1, 2, 0, 0}))
    testing.expect_value(t, true, slice.equal(new_attempts[1][:], []u64{1, 0, 0, 4}))
    testing.expect_value(t, true, slice.equal(new_attempts[2][:], []u64{0, 0, 3, 4}))
}

@(test)
index_combinations :: proc(t: ^testing.T) {
    result := pbt.index_combinations(0, 6, 2)
    defer delete(result)

    testing.expect_value(t, len(result), 4)
    testing.expect_value(t, true,
                         slice.equal(result[:], [][2]int{{0, 2}, {1, 3}, {2, 4}, {3, 5}}))
}
