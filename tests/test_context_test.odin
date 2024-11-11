package tests

import "core:testing"
import "core:math/rand"

import "../pbt"

@(test)
make_default_context :: proc(t: ^testing.T) {
    ctx := pbt.make_context(proc(tc: ^pbt.Test_Case) -> bool { return true})

    testing.expect_value(t, ctx.test_n, 100)
}

@(test)
make_context :: proc(t: ^testing.T) {
    ctx := pbt.make_context(proc(tc: ^pbt.Test_Case) -> bool { return true}, 34, 123)

    testing.expect_value(t, ctx.test_n, 34)
    testing.expect_value(t, ctx.seed, 123)
}

@(test)
lists :: proc(t: ^testing.T) {
    rand.reset(123)
    
    test := pbt.create_test()
        
    list_of_u8s := pbt.lists(u8s(), 2, 10)
    values := pbt.draw(&test, list_of_u8s)
            
    expected := []u8{50, 234, 93, 19, 160}
    pbt.expect_equal_slices(t, values, expected)
}
