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
maps_of_specific_key_value_cached :: proc(t: ^testing.T) {
    specific_map_value := proc(test: ^pbt.Test_Case) -> bool {
        value := pbt.draw(
            test, pbt.maps(pbt.strings_alpha_numeric(1, 2), pbt.integers(0, 255), 1, 5))

        log.debugf("property called with: %v", value)

        pbt.make_test_report(test, "Failing example: %v", value)

        return !(value["a"] == 10)
    }

    ctx := pbt.check_property(specific_map_value, 1_000_000, 11041760626551297113, true)
    defer pbt.delete_context(ctx)

    testing.expect_value(t, ctx.report, "Failing example: map[a=10]")
    testing.expect_value(t, ctx.failed, true)
    expect_equal_slices(t, ctx.result[:], []u64{1, 1, 36, 0, 10, 0})

    // Make sure we don't make shrinking worse
    testing.expect_value(t, ctx.shrinking_iterations, 2)
    testing.expect_value(t, ctx.considered_attempts, 103)
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

import "core:strings"
import "core:fmt"

@(test)
stateful_map_db :: proc(t: ^testing.T) {
    Person :: struct {
        name: string,
        age: u8,
    }

    Person_DB :: distinct map[string]Person

    add_person :: proc(db: ^Person_DB, person: Person) {
        if person.age > 64 {
            //fmt.println("Adding person: ", person)
            db[person.name] = person
        }
    }

    delete_person :: proc(db: ^Person_DB, name: string) {
        delete_key(db, name)
    }

    reset_db :: proc(db: ^Person_DB) {
        clear(db)
    }

    Operation :: enum {
        Add,
        Delete,
    }

    person_db := make(Person_DB)
    defer delete(person_db)
    context.user_ptr = &person_db

    stateful_db := proc(test: ^pbt.Test_Case) -> bool {
        db := cast(^Person_DB)context.user_ptr
        // Shrinking will suffer if the state is not reset. Thus, if you can,
        //  always implement a state reset mechanism
        reset_db(db)

        operations := pbt.draw(test, pbt.lists(pbt.integers(0, len(Operation) - 1), 2, 10))

        report := strings.builder_make(context.temp_allocator)
        executed_ops:= make([dynamic]Operation, context.temp_allocator)

        for operation, idx in operations {
            op := Operation(operation)
            append(&executed_ops, op)

            person_name := pbt.draw(test, pbt.strings_alpha_numeric(1, 50))
            person_age  := u8(pbt.draw(test, pbt.integers(0, 120)))

            person := Person { name = person_name, age = person_age}

            // Call the function we want to test
            switch op {
            case .Add: {
                fmt.sbprintf(&report, "Add: %v", person)
                add_person(db, person)
            }
            case .Delete: {
                fmt.sbprintf(&report, "Delete: %v", person_name)
                delete_person(db, person_name)
            }
            case: {
                fmt.println("Faulty draw: ", operation)
                panic("Faulty draw")
            }
            }
            if idx < len(operations) - 1 {
                fmt.sbprint(&report, " | ")
            }
        }

        // Make a report for better understanding
        pbt.make_test_report(test, "Operations: [%v]", strings.to_string(report))

        // Check that the sorted lists are equal
        return !(len(db) == 2)
    }

    ctx := pbt.check_property(stateful_db, DEFAULT_TEST_N, 8359183825713645891)
    //ctx := pbt.check_property(stateful_db, DEFAULT_TEST_N, 12180852453246938387)
    defer pbt.delete_context(ctx)

    testing.expect_value(
        t, ctx.report, "Operations: [Add: Person{name = \"1\", age = 65} | Add: Person{name = \"0\", age = 65}]")
    testing.expect_value(t, ctx.failed, true)

    expect_equal_slices(
        t,
        ctx.result[:],
        []u64{1, 0, 1, 0, 0, 1, 1, 0, 65, 1, 0, 0, 65})

    // Make sure we don't make shrinking worse
    // testing.expect_value(t, ctx.shrinking_iterations, 3)
    // testing.expect_value(t, ctx.considered_attempts, 827)
}

// @(test)
// stateful_map_db_bind :: proc(t: ^testing.T) {
//     Person :: struct {
//         name: string,
//         age: u8,
//     }

//     Person_DB :: distinct map[string]Person

//     add_person :: proc(db: ^Person_DB, person: Person) {
//         if person.age > 64 {
//             //fmt.println("Adding person: ", person)
//             db[person.name] = person
//         }
//     }

//     delete_person :: proc(db: ^Person_DB, name: string) {
//         delete_key(db, name)
//     }

//     reset_db :: proc(db: ^Person_DB) {
//         clear(db)
//     }

//     Operation :: enum {
//         Add,
//         Delete,
//     }

//     person_db := make(Person_DB)
//     defer delete(person_db)
//     context.user_ptr = &person_db

//     stateful_db := proc(test: ^pbt.Test_Case) -> bool {
//         db := cast(^Person_DB)context.user_ptr
//         // Shrinking will suffer if the state is not reset. Thus, if you can,
//         //  always implement a state reset mechanism
//         reset_db(db)

//         operations := pbt.draw(
//             test,
//             pbt.lists(
//                 pbt.bind(
//                     pbt.integers(0, len(Operation) - 1),
//                     proc(op: u64) -> Possibility(Operation, string) {
//                         op := Operation(op)
//                         switch op {
//                         case .Add: {
//                             return pbt.strings_alpha_numeric(1, 50)
//                         }
//                         case .Delete: {
//                             return pbt.strings_alpha_numeric(10, 50)
//                         }
//                         }
//                     }
//                 ),
//                 2,
//                 10))

//         report := strings.builder_make(context.temp_allocator)
//         executed_ops:= make([dynamic]Operation, context.temp_allocator)

// //        fmt.println("Ops: ", operations)
//         for operation, idx in operations {
//             op := Operation(operation)
//             append(&executed_ops, op)

//             person_name := pbt.draw(test, pbt.strings_alpha_numeric(1, 50))
//             person_age  := u8(pbt.draw(test, pbt.integers(0, 120)))

//             person := Person { name = person_name, age = person_age}

//             // Call the function we want to test
//             switch op {
//             case .Add: {
//                 fmt.sbprintf(&report, "Add: %v", person)
//                 add_person(db, person)
//             }
//             case .Delete: {
//                 fmt.sbprintf(&report, "Delete: %v", person_name)
//                 delete_person(db, person_name)
//             }
//             case: {
//                 fmt.println("Faulty draw: ", operation)
//                 panic("Faulty draw")
//             }
//             }
//             if idx < len(operations) - 1 {
//                 fmt.sbprint(&report, " | ")
//             }
//         }

//         // Make a report for better understanding
//         pbt.make_test_report(test, "Operations: [%v]", strings.to_string(report))

//         // Check that the sorted lists are equal
//         return !(len(db) == 2)
//     }

//     //ctx := pbt.check_property(stateful_db, DEFAULT_TEST_N, 8359183825713645891)
//     ctx := pbt.check_property(stateful_db, DEFAULT_TEST_N, 12180852453246938387)
//     defer pbt.delete_context(ctx)

//     testing.expect_value(
//         t, ctx.report, "Operations: [Add: Person{name = \"1\", age = 65} | Add: Person{name = \"0\", age = 65}]")
//     testing.expect_value(t, ctx.failed, true)

//     expect_equal_slices(
//         t,
//         ctx.result[:],
//         []u64{1, 0, 1, 0, 0, 1, 1, 0, 65, 1, 0, 0, 65})

//     // Make sure we don't make shrinking worse
//     // testing.expect_value(t, ctx.shrinking_iterations, 3)
//     // testing.expect_value(t, ctx.considered_attempts, 827)
// }
