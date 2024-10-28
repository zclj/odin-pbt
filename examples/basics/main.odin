package basics_example

import "core:fmt"

import "../../pbt"

// The proc we want to test. For some reason, it hates 13.
bad_add :: proc(x, y: u8) -> u8 {
    result := x + y

    if x == 13 {
        result -= 1
    }

    return result
}

main :: proc() {
    // Define the property: a proc taking a test case and returning a bool indicating if the
    //  property holds or not
    addition_works := proc(test: ^pbt.Test_Case) -> bool {
        // Draw two integers in the u8 domain
        x := pbt.draw(test, pbt.integers(0, 255))
        y := pbt.draw(test, pbt.integers(0, 255))

        // Call the proc we want to test
        result := bad_add(u8(x), u8(y))

        // In case the property fail, we can provide more specific reports
        pbt.make_test_report(test, "Addition of %v and %v failed", x, y)

        // Check if our invariant holds. We use '+' as our Oracle
        return result == u8(x + y)
    }

    // Check the property for a max of 10 000 examples
    test_context := pbt.check_property(addition_works, 10000)

    // Print the report.
    fmt.println(pbt.build_report(test_context))

    // Running this property we should see a failure that is shrunken to the minimal case of
    //  x = 13, y = 0
}
