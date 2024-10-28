package collections_example

import "core:fmt"
import "core:slice"

import "../../pbt"

bad_sort :: proc(xs: []u64) {
    if len(xs) > 5 {
        mid := len(xs) / 2
        slice.sort(xs[:mid])
    } else {
        slice.sort(xs)
    }
}

main :: proc() {
    list_is_sorted := proc(test: ^pbt.Test_Case) -> bool {
        min_size := pbt.draw(test, pbt.integers(0, 100))
        range    := pbt.draw(test, pbt.integers(1, 100))
        max_size := min_size + range
        
        list_value := pbt.draw(
            test,
            // The list generator requires an element generator to draw values from
            pbt.lists(pbt.integers(0, 100), min_size, max_size))

        // Store the original value and sort it as an Oracle
        original := slice.clone_to_dynamic(list_value, context.temp_allocator)
        slice.sort(original[:])

        // Call the function we want to test
        bad_sort(list_value[:])

        // Make a report for better understanding
        pbt.make_test_report(
            test, "List is not sorted: %v, expected: %v", list_value, original)

        // Check that the sorted lists are equal
        return slice.equal(list_value[:], original[:])
    }

    // Check the property for a max of 10 000 examples
    test_context := pbt.check_property(list_is_sorted, 10000)

    // Print the report.
    fmt.println(pbt.build_report(test_context))

    // Running this check should result in:
    // "List is not sorted: [0, 0, 1, 0, 0, 0], expected: [0, 0, 0, 0, 0, 1]"
    // The result contains 6 elements and only the bottom half is sorted.
    // Note, the '1' cannot be shrunken since then the list would be same as the sorted one.
}
