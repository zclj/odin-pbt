package tests

import "core:testing"
import "base:intrinsics"
import "core:slice"

import "../pbt"

expect_equal_slices :: proc(t: ^testing.T, actual, expected: $T/[]$E) where intrinsics.type_is_comparable(E){
    testing.expectf(t, slice.equal(actual, expected), "Expected %v, got %v", expected, actual)
}

expect_property_passed :: proc(t: ^testing.T, ctx: pbt.Test_Context) {
    expected_passed   := ctx.test_n - ctx.tests_rejected
    expected_rejected := ctx.test_n - ctx.tests_passed
    
    testing.expect_value(t, ctx.report, "")
    testing.expect_value(t, ctx.failed, false)
    testing.expect_value(t, ctx.tests_passed, expected_passed)
    testing.expect_value(t, ctx.tests_rejected, expected_rejected)
    expect_equal_slices(t, ctx.result[:], []u64{})
}

////////////////////////////////////////
// Test possibility - used to draw input values for testing other draws

u8s :: proc() -> pbt.Possibility(u8, u8) {
    return pbt.Possibility(u8, u8) {
        input   = 0,
        produce = proc(test_case: ^pbt.Test_Case, input: u8) -> u8 {
            return u8(pbt.choice(test_case, 255))
        },
    }
}
