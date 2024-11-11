package tests

import "../pbt"

////////////////////////////////////////
// Test possibility - used to draw input values for testing other draws

u8s :: proc() -> pbt.Possibility(u8, u8) {
    return pbt.Possibility(u8, u8) {
        input   = 0,
        produce = proc(test_case: ^pbt.Test_Case, input: u8) -> u8 {
            return u8(pbt.choice(test_case, 255))
        },
    }
}
