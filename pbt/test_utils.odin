package pbt

import "core:testing"
import "base:intrinsics"
import "core:slice"

////////////////////////////////////////
// Utils relevant when using PBT in your tests

expect_equal_slices :: proc(t: ^testing.T, actual, expected: $T/[]$E) where intrinsics.type_is_comparable(E){
    testing.expectf(t, slice.equal(actual, expected), "Expected %v, got %v", expected, actual)
}

expect_property_passed :: proc(t: ^testing.T, ctx: Test_Context) {
    expected_passed   := ctx.test_n - ctx.tests_rejected
    expected_rejected := ctx.test_n - ctx.tests_passed
    
    testing.expect_value(t, ctx.report, "")
    testing.expect_value(t, ctx.failed, false)
    testing.expect_value(t, ctx.tests_passed, expected_passed)
    testing.expect_value(t, ctx.tests_rejected, expected_rejected)
    expect_equal_slices(t, ctx.result[:], []u64{})
}
