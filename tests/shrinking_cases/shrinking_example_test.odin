package shrinking_cases

import "core:testing"
import "core:log"

import "../../pbt"

////////////////////////////////////////
// Util : TODO - make it a package for use both here and in tests

DEFAULT_TEST_N :: 10_000

import "base:intrinsics"
import "core:slice"
expect_equal_slices :: proc(t: ^testing.T, actual, expected: $T/[]$E) where intrinsics.type_is_comparable(E){
    testing.expectf(t, slice.equal(actual, expected), "Expected %v, got %v", expected, actual)
}
////////////////////////////////////////
//
// Examples of value shrinking that should work well
//

@(test)
maps_of_specific_key_value :: proc(t: ^testing.T) {
    specific_map_value := proc(test: ^pbt.Test_Case) -> bool {
        value := pbt.draw(
            test, pbt.maps(pbt.strings_alpha_numeric(1, 2), pbt.integers(0, 255), 1, 5))

        log.debugf("property called with: %v", value)
        
        pbt.make_test_report(test, "Failing example: %v", value)
                        
        return !(value["a"] == 10)
    }

    ctx := pbt.check_property(specific_map_value, 1_000_000, 11041760626551297113)
    defer pbt.delete_context(ctx)

    testing.expect_value(t, ctx.report, "Failing example: map[a=10]")
    testing.expect_value(t, ctx.failed, true)
    expect_equal_slices(t, ctx.result[:], []u64{1, 1, 36, 0, 10, 0})

    // Make sure we don't make shrinking worse
    testing.expect_value(t, ctx.shrinking_iterations, 2)
    testing.expect_value(t, ctx.considered_attempts, 191)
}

@(test)
maps_of_specific_boundary_value :: proc(t: ^testing.T) {
    map_boundary_value := proc(test: ^pbt.Test_Case) -> bool {
        min_size := pbt.draw(test, pbt.integers(1, 10))
        range    := pbt.draw(test, pbt.integers(1, 10))
        max_size := min_size + range
        
        value := pbt.draw(
            test, pbt.maps(pbt.strings_alpha_numeric(4, 20), pbt.integers(0, 255), min_size, max_size))

        pbt.make_test_report(test, "Failing example: %v", value)
        
        m_values,_ := slice.map_values(value, context.temp_allocator)
        lower := slice.filter(m_values, proc(v: u64) -> bool { return v < 50 }, context.temp_allocator)
        any_lower := len(lower) > 0
        
        return any_lower
    }
    
    ctx := pbt.check_property(map_boundary_value, DEFAULT_TEST_N, 8359183825713645891)
    defer pbt.delete_context(ctx)

    testing.expect_value(t, ctx.report, "Failing example: map[0000=50]")
    testing.expect_value(t, ctx.failed, true)

    expect_equal_slices(
        t,
        ctx.result[:],
        []u64{0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 50, 0})

    // Make sure we don't make shrinking worse
    testing.expect_value(t, ctx.shrinking_iterations, 4)
    testing.expect_value(t, ctx.considered_attempts, 1114)
}

