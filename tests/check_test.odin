package tests

import "core:testing"
import "core:math/rand"
import "core:slice"

import "../pbt"

@(test)
check_passing_property :: proc(t: ^testing.T) {
    rand.reset(123456789)

    property_fn := proc(test: ^pbt.Test_Case) -> bool {
        value := pbt.draw(test, u8s())

        return value >= 0
    }

    tc := pbt.make_context()
    tc.property = property_fn
        
    pbt.check(&tc)

    expected := []u64{}
    actual   := tc.result[:]

    expect_equal_slices(t, actual, expected)

    delete(tc.result)
}

@(test)
check_respects_number_of_tests :: proc(t: ^testing.T) {
    rand.reset(123456789)

    property_fn := proc(test: ^pbt.Test_Case) -> bool {
        value := pbt.draw(test, u8s())

        return value >= 0
    }

    tc := pbt.make_context()
    tc.property = property_fn
            
    pbt.check(&tc)

    expected := []u64{}
    actual   := tc.result[:]

    testing.expect_value(t, u64(100), tc.tests_passed)
    expect_equal_slices(t, actual, expected)

    delete(tc.result)
}

@(test)
with_report :: proc(t: ^testing.T) {
    rand.reset(123456789)
    
    property_fn := proc(test: ^pbt.Test_Case) -> bool {
        value := pbt.draw(test, u8s())
                
        pbt.make_test_report(test, "Reported %v", value)
        return !(value > 0)
    }

    tc := pbt.make_context()
    tc.property = property_fn
    defer {
        delete(tc.report)
        delete(tc.result)
    }
    
    pbt.check(&tc)

    testing.expect_value(t, tc.report, "Reported 1")
}

@(test)
check :: proc(t: ^testing.T) {
    //seed := rand.uint64()
    rand.reset(123456789)

    property_fn := proc(test: ^pbt.Test_Case) -> bool {
        bad_add := proc(x: int, y: int) -> int {
            res := x + y

            if x > 10 && y > 56 {
                res -= 1
            }

            return res
        }
        
        even_typed := pbt.satisfy(
            pbt.integers(0, 100),
            proc(arg: u64) -> bool {
                return arg % 2 == 0
            })
        even_value,_ := pbt.draw(test, even_typed)
        
        scaled_typed := pbt.mapping(
            u8s(),
            proc(arg: u8) -> int {
                res := arg * 2
                return int(res)
            },
        )
        scaled_value := pbt.draw(test, scaled_typed)

        result := bad_add(int(even_value), scaled_value)

        oracle := int(even_value) + int(scaled_value)
        
        return result == oracle
        
    }

    tc := pbt.make_context()
    tc.property = property_fn
            
    pbt.check(&tc)

    expected := []u64{12, 29}
    actual   := tc.result[:]

    expect_equal_slices(t, actual, expected)
    testing.expect_value(t, tc.failed, true)
    
    delete(tc.result)
}

@(test)
lists_property :: proc(t: ^testing.T) {
    rand.reset(123456789)

    property_fn := proc(test: ^pbt.Test_Case) -> bool {
        bad_sort := proc(xs: []u8) -> []u8 {
            sorted := slice.clone_to_dynamic(xs[:])
            defer delete(sorted)
            
            slice.sort(sorted[:])

            result: [dynamic]u8
            defer delete(result)
            
            if len(xs) > 5 {
                for x in sorted[:] {
                    if x < 10 {
                        append(&result, x)
                    }
                }
            } else {
                return sorted[:]
            }

            return result[:]
        }

        list := pbt.draw(
            test, pbt.lists(u8s(), 0, 100))
                
        //test.report = fmt.aprintf("Sorting with: %v", list)
        result := bad_sort(list[:])

        slice.sort(list[:])

        return slice.equal(result, list)
    }

    tc := pbt.make_context()
    tc.property = property_fn
        
    pbt.check(&tc)

    expected := []u64{1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 10, 0}
    actual   := tc.result[:]

    expect_equal_slices(t, actual, expected)
    
    delete(tc.result)
}
