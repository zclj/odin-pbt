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

@(test)
stateful_map_db_with_more_loop :: proc(t: ^testing.T) {
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

        report := strings.builder_make(context.temp_allocator)
        executed_ops:= make([dynamic]Operation, context.temp_allocator)

        min_size := 2
        max_size := 10
        
        for {
            if len(executed_ops) < int(min_size) {
                //log.debugf("Force draw map entry, min size")
                pbt.forced_choice(test, 1)
            } else if len(executed_ops) + 1 >= int(max_size) {
                //log.debugf("Force stop draw map entry, max size")
                pbt.forced_choice(test, 0)
                break
            } else if !pbt.weighted(test, 0.9) {
                //log.debugf("Weighted stop draw map entry")
                break
            }

            // If we got here we should do another op
            operation_enum := pbt.draw(test, pbt.integers(0, len(Operation) - 1))
            operation := Operation(operation_enum)
            append(&executed_ops, operation)
            
            // Call the function we want to test
            switch operation {
            case .Add: {
                person_name := pbt.draw(test, pbt.strings_alpha_numeric(1, 50))
                person_age  := u8(pbt.draw(test, pbt.integers(0, 120)))
                person := Person { name = person_name, age = person_age}

                fmt.sbprintf(&report, "Add: %v", person)
                
                add_person(db, person)
            }
            case .Delete: {
                person_name := pbt.draw(test, pbt.strings_alpha_numeric(1, 50))

                fmt.sbprintf(&report, "Delete: %v", person_name)
                
                delete_person(db, person_name)
            }
            case: {
                fmt.println("Faulty draw: ", operation)
                panic("Faulty draw")
            }
            }

            fmt.sbprint(&report, " | ")
        }
        
        // Make a report for better understanding
        pbt.make_test_report(test, "Operations: [%v]", strings.to_string(report))

        // Check that the sorted lists are equal
        return !(len(db) == 2)
    }

    //ctx := pbt.check_property(stateful_db, DEFAULT_TEST_N, 8359183825713645891)
    ctx := pbt.check_property(stateful_db, DEFAULT_TEST_N, 12180852453246938387)
    //ctx := pbt.check_property(stateful_db, DEFAULT_TEST_N, 995229352037140792)
    //ctx := pbt.check_property(stateful_db, DEFAULT_TEST_N)
    defer pbt.delete_context(ctx)

    testing.expect_value(
        t, ctx.report, "Operations: [Add: Person{name = \"1\", age = 65} | Add: Person{name = \"0\", age = 65} | ]")
    testing.expect_value(t, ctx.failed, true)

    expect_equal_slices(
        t,
        ctx.result[:],
        []u64{1, 0, 1, 1, 0, 65, 1, 0, 1, 0, 0, 65, 0})

    // Make sure we don't make shrinking worse
    // testing.expect_value(t, ctx.shrinking_iterations, 3)
    // testing.expect_value(t, ctx.considered_attempts, 827)
}

@(test)
stateful_map_db_with_bind :: proc(t: ^testing.T) {
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

    AddOp :: struct {
        person: Person,
    }

    DeleteOp :: struct {
        name: string,
    }
    
    Operation_Data :: union {
        AddOp,
        DeleteOp,
    }

    person_db := make(Person_DB)
    defer delete(person_db)
    context.user_ptr = &person_db

    stateful_db := proc(test: ^pbt.Test_Case) -> bool {
        db := cast(^Person_DB)context.user_ptr
        // Shrinking will suffer if the state is not reset. Thus, if you can,
        //  always implement a state reset mechanism
        reset_db(db)

        report := strings.builder_make(context.temp_allocator)
        executed_ops:= make([dynamic]Operation_Data, context.temp_allocator)
        
        operations := pbt.draw(
            test,
            pbt.lists(
                pbt.bind(
                    pbt.integers(0, len(Operation) - 1),
                    proc(op_e: u64) -> pbt.Possibility(Operation, Operation_Data) {
                        operation := Operation(op_e)

                        pos := pbt.Possibility(Operation, Operation_Data) {
                            input = operation,
                            produce = proc(
                                test: ^pbt.Test_Case,
                                operation: Operation) -> Operation_Data {
                                switch operation {
                                case .Add: {
                                    person_name := pbt.draw(test, pbt.strings_alpha_numeric(1, 50))
                                    person_age  := u8(pbt.draw(test, pbt.integers(0, 120)))
                                    person := Person { name = person_name, age = person_age}

                                    return AddOp { person = person}
                                    
                                }
                                case .Delete: {
                                    person_name := pbt.draw(test, pbt.strings_alpha_numeric(1, 50))

                                    //fmt.sbprintf(&report, "Delete: %v", person_name)
                                    
                                    return DeleteOp { name = person_name }
                                }
                                case: {
                                    fmt.println("Faulty draw: ", operation)
                                    panic("Faulty draw")
                                }
                                }
                                },
                        }
                        
                            return pos
                    },
                ),
                2, 10),
        )

        //log.infof("Operation mapping: %v", the_thing)

        for operation_data, idx in operations {
            append(&executed_ops, operation_data)
            
            // Call the function we want to test
            switch op in operation_data {
            case AddOp: {
                fmt.sbprintf(&report, "Add: %v", op.person)
                add_person(db, op.person)
            }
            case DeleteOp: {
                fmt.sbprintf(&report, "Delete: %v", op.name)
                delete_person(db, op.name)
            }
                
            }
            if idx < len(operations) - 1 {
                fmt.sbprint(&report, " | ")
            }
        }            
            // Call the function we want to test
            

            fmt.sbprint(&report, " | ")
    
        
        // Make a report for better understanding
        pbt.make_test_report(test, "Operations: [%v]", strings.to_string(report))

        // Check that the sorted lists are equal
        return !(len(db) == 2)
    }
    
    ctx := pbt.check_property(stateful_db, DEFAULT_TEST_N, 12503090707380450584)
    defer pbt.delete_context(ctx)

    testing.expect_value(
        t, ctx.report, "Operations: [Add: Person{name = \"1\", age = 65} | Add: Person{name = \"0\", age = 65} | ]")
    testing.expect_value(t, ctx.failed, true)

    expect_equal_slices(
        t,
        ctx.result[:],
        []u64{1, 0, 1, 1, 0, 65, 1, 0, 1, 0, 0, 65, 0})

    // Make sure we don't make shrinking worse
    // testing.expect_value(t, ctx.shrinking_iterations, 3)
    // testing.expect_value(t, ctx.considered_attempts, 827)
}

