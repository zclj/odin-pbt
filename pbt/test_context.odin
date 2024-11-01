package pbt

import "core:slice"
import "core:strings"
import "core:fmt"
import "core:math/rand"
import "core:log"

////////////////////////////////////////
// Test Context

Property :: distinct proc(tc: ^Test_Case) -> bool

Test_Context :: struct {
    draws_count    : int,
    property       : Property,
    result         : [dynamic]u64,
    report         : string,
    failed         : bool,
    test_n         : u64,
    tests_passed   : u64,
    tests_rejected : u64,
    seed           : u64,
    failed_with    : [dynamic]u64,
}

make_context :: proc(number_of_tests: u64 = 100, seed: u64 = 0, allocator := context.allocator) -> Test_Context {
    assert(number_of_tests > 0)

    new_seed: u64
    if seed == 0 {
        new_seed = rand.uint64()
    } else {
        new_seed = seed
    }
    
    rand.reset(new_seed)
        
    return Test_Context {
        test_n = number_of_tests,
        result = make([dynamic]u64, allocator),
        seed   = new_seed,
    }
}

consider :: proc(tc: ^Test_Context, attempt: []u64) -> bool {
    log.debugf("Consider attempt: %v", attempt)

    test := for_choices(attempt, context.temp_allocator)
        
    prop_res := tc.property(&test)

    log.debugf("Status of considered test case: %v", test.status)

    log.debugf(make_groups_report(&test))
    
    // Property failed, so possible interesting
    if !prop_res && test.status != .Invalid && test.status != .Overrun {
        log.debugf("Interesting test case found")
        test.status = .Interesting
        // Store the latest interesting data in the context
        delete(tc.result)
        tc.result = slice.clone_to_dynamic(attempt[:])
        delete(tc.report)
        tc.report = strings.clone(strings.to_string(test.report_builder))
    } else {
        log.debugf("Test case passed")
        test.status = .Valid
    }
    
    return test.status == .Interesting
}

build_report :: proc(tc: Test_Context, allocator := context.allocator) -> string {
    builder := strings.builder_make(allocator)

    fmt.sbprintfln(&builder, "%v passing examples, %v rejected examples", tc.tests_passed, tc.tests_rejected)

    if tc.failed {
        strings.write_string(&builder, "Test failed\n")
        fmt.sbprintfln(&builder, "Seed: %v", tc.seed)
        if len(tc.report) > 0 {
            fmt.sbprintfln(&builder, "Report: %v", tc.report)
        }
    }

    return strings.to_string(builder)
}
