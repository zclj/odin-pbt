package pbt

import "core:slice"
import "core:strings"
import "core:fmt"
import "core:math/rand"
import "core:log"
import "core:time"

////////////////////////////////////////
// Test Context

Property :: distinct proc(tc: ^Test_Case) -> bool

Test_Context :: struct {
    draws_count          : int,
    property             : Property,
    result               : [dynamic]u64,
    report               : string,
    failed               : bool,
    test_n               : u64,
    tests_passed         : u64,
    tests_rejected       : u64,
    seed                 : u64,
    failed_report        : string,
    generation_duration  : time.Duration,
    shrinking_duration   : time.Duration,
    shrinking_iterations : u64,
    considered_attempts  : u64,
    property_cache       : Simple_Cache,
    use_cache            : bool,
    cache_hits           : u64,
}

// A simple cache for linear search.
// In some cases, calling the property function can be expensive. Thus, even a basic search
//  will save time.
Simple_Cache :: struct {
    attempts: [dynamic][dynamic]u64,
    results:  [dynamic]bool,
}

make_context :: proc(property: Property, number_of_tests: u64 = 100, seed: u64 = 0, use_cache: bool = false, allocator := context.allocator) -> Test_Context {
    assert(number_of_tests > 0)

    new_seed: u64
    if seed == 0 {
        new_seed = rand.uint64()
    } else {
        new_seed = seed
    }
    
    rand.reset(new_seed)
        
    return Test_Context {
        property  = property,
        test_n    = number_of_tests,
        result    = make([dynamic]u64, allocator),
        seed      = new_seed,
        use_cache = use_cache,
    }
}

delete_context :: proc(tc: Test_Context) {
    delete(tc.result)
    delete(tc.report)
    delete(tc.failed_report)

    for attempt in tc.property_cache.attempts {
        delete(attempt)
    }
    delete(tc.property_cache.attempts)
    delete(tc.property_cache.results)
}

consider :: proc(tc: ^Test_Context, attempt: []u64) -> bool {
    log.debugf("Consider attempt: %v", attempt)

    // Check cache if enabled
    cached_attempt_found: bool
    cache_idx: int
    if tc.use_cache {
        for cached_attempt, idx in tc.property_cache.attempts {
            if slice.equal(cached_attempt[:], attempt) {
                cached_attempt_found = true
                cache_idx = idx
                tc.cache_hits += 1
            }
        }
    }

    if cached_attempt_found {
        log.debugf("Attempt found in cache")
        return tc.property_cache.results[cache_idx]
    }

    // Call the property
    tc.considered_attempts += 1
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

    result := test.status == .Interesting

    // Cache this attempt if enabled
    if tc.use_cache {
        append(&tc.property_cache.attempts, slice.clone_to_dynamic(attempt))
        append(&tc.property_cache.results, result)
    }
    
    return result
}

build_report :: proc(tc: Test_Context, allocator := context.allocator) -> string {
    builder := strings.builder_make(allocator)

    fmt.sbprintfln(&builder, "%v passing examples, %v rejected examples", tc.tests_passed, tc.tests_rejected)

    if tc.failed {
        strings.write_string(&builder, "Test failed\n")
        fmt.sbprintfln(&builder, "Seed: %v", tc.seed)
        if len(tc.failed_report) > 0 {
            fmt.sbprintfln(&builder, "Failed Report : %v", tc.failed_report)
        }
        if len(tc.report) > 0 {
            fmt.sbprintfln(&builder, "Minimal Report: %v", tc.report)
        }
    }

    // Statistics
    fmt.sbprintln(&builder, "Statistics:")
    fmt.sbprintfln(&builder, "Generation duration : %v", tc.generation_duration)
    fmt.sbprintfln(&builder, "Shrinking duration  : %v", tc.shrinking_duration)
    fmt.sbprintfln(&builder, "Shrinking iterations: %v", tc.shrinking_iterations)
    fmt.sbprintfln(&builder, "Considered attempts : %v", tc.considered_attempts)
    if tc.use_cache {
        fmt.sbprintfln(&builder, "Cache hits          : %v", tc.cache_hits)
    }

    return strings.to_string(builder)
}

run_result :: proc(tc: Test_Context) -> bool {
    // Create a test loaded with the current result
    test := for_choices(tc.result[:], context.temp_allocator)

    return tc.property(&test)
}
