package strconv_symmetry

import "core:fmt"
import "core:strconv"

import "../../pbt"

// Reproduce: https://github.com/odin-lang/Odin/issues/4397
// "strconv.parse_f64_prefix() returns incorrect values for negative numbers"
main :: proc() {
    // Create our property
    prefix_do_not_truncate := proc(test: ^pbt.Test_Case) -> bool {
        value := i64(pbt.draw(test, pbt.integers(-1000, 1000)))

        buf: [8]byte
        value_str := strconv.itoa(buf[:], int(value))

        // Call the proc we want to test
        result, _, _ := strconv.parse_f64_prefix(value_str)

        // In case the property fail, we can provide more specific reports
        pbt.make_test_report(test, "parse prefix of %v failed: %v", value, result)

        // Value returned should be symetrical with making an f64 of 'value'
        return result == f64(value)
    }

    // Check the property for a max of 100 000 examples
    test_context := pbt.check_property(prefix_do_not_truncate, 1_000_000)

    // Print the report.
    fmt.println(pbt.build_report(test_context))
}
