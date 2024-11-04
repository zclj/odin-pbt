package pbt

import "core:fmt"
import "core:slice"
import "core:log"
import "core:time"
import "core:strings"

check_property :: proc(property: Property, number_of_tests: u64 = 100, seed: u64 = 0) -> Test_Context {
    tc := make_context(number_of_tests, seed)
    tc.property = property

    check(&tc)

    return tc
}

check :: proc(tc: ^Test_Context) {
    assert(tc.property != nil)
    assert(tc.test_n > 0)
    assert(tc.tests_passed == 0)

    log.infof("Start Checking property, number of tests: %v (seed: %v)", tc.test_n, tc.seed)

    passed := true

    generation_start_time := time.now()
    for n in 0..<tc.test_n {
        log.debug("Check iteration", n)

        test := create_test(allocator = context.temp_allocator)

        passed    = tc.property(&test)
        rejected := test.status == .Overrun || test.status == .Invalid

        // First, check if this test case is valid
        if rejected {
            // For some reason this is not an interesting test case, move on
            tc.tests_rejected += 1
        } else if passed && !rejected {
            // Test case was valid and all the property passed
            tc.tests_passed += 1
        } else if !passed && !rejected{
            // Test case failed, move on to shrinking.
            // Keep the original failed data
            tc.failed_report = strings.clone(strings.to_string(test.report_builder))

            // Setup the best result for shrinking
            tc.result = slice.clone_to_dynamic(test.choices.recorded.data[:])
            tc.failed = true
        }

        // Clear allocations for this test run
        free_all(context.temp_allocator)

        if tc.failed {
            log.infof("Property failed in test %v", n)
            break
        }
    }
    tc.generation_duration = time.since(generation_start_time)

    // Shrink if failed
    if !passed {
        log.info("Start shrinking")
        shrink_start_time := time.now()
        shrink(tc)
        tc.shrinking_duration = time.since(shrink_start_time)
        log.info("Shrinking done")
    }

}

main :: proc() {

    logger := log.create_console_logger(lowest = .Debug)
    context.logger = logger

    stuff := proc(test: ^Test_Case) -> bool {
        min_size := draw(test, integers(1, 10))
        range    := draw(test, integers(1, 10))
        max_size := min_size + range

        value := draw(
            test, maps(strings_alpha_numeric(4, 20), integers(0, 255), min_size, max_size))

        make_test_report(
            test, "Value: %v is not in range, length [%v, %v]", value, min_size, max_size)

        m_values,_ := slice.map_values(value, context.temp_allocator)
        lower := slice.filter(m_values, proc(v: u64) -> bool { return v < 50 }, context.temp_allocator)
        any_lower := len(lower) > 0

        log.debugf("Value drawn: %v", value)

        return any_lower
    }

    tc := check_property(stuff, 10000)

    fmt.println("Result:", tc.report)

    fmt.println(build_report(tc))
}
