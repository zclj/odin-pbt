package pbt

import "core:slice"
import "core:log"

shrink :: proc(tc: ^Test_Context) {
    improved := true

    prev: [dynamic]u64
    
    for improved {
        improved = false
        prev = slice.clone_to_dynamic(tc.result[:])
        
        // Remove blocks
        log.debugf("Start Remove with: %v", tc.result)
        shrink_remove_blocks(tc)
              
        // Zero blocks
        log.debugf("Start Zero blocks with: %v", tc.result)
        shrink_zero_blocks(tc)
        
        // Reduce values
        log.debugf("Start Reduce with: %v", tc.result)
        shrink_reduce(tc)
        
        // Sort
        log.debugf("Start Sort with: %v", tc.result)
        shrink_sort(tc)
        
        // Swap
        log.debugf("Start Swap with: %v", tc.result)
        shrink_swap(tc)
        
        // Redistribute values
        log.debugf("Start Redistribute with: %v", tc.result)
        shrink_redistribute(tc, tc.result[:])
        
        log.debugf("Shrinking started with: %v", prev)
        log.debugf("Shrinking ended   with: %v", tc.result)

        // TODO: break?
        if slice.equal(prev[:], tc.result[:]) {
            log.debug("Shrinking could not improve")
            improved = false
        } else {
            log.debug("Shrinking improved")
            improved = true
        }
        
        delete(prev)
    }    
}

shrink_remove_blocks :: proc(tc: ^Test_Context) {
    sizes :[4]int = {8, 4, 2, 1}

    for size in sizes {
        combos := index_combinations(0, len(tc.result) + 1, size)
        defer delete(combos)
        
        #reverse for combo in combos {
            new_attempt := slice.clone_to_dynamic(tc.result[:])
            defer delete(new_attempt)

            if combo.x < len(new_attempt) && combo.y <= len(new_attempt) {
                remove_range(&new_attempt, combo.x, combo.y)
            } else {
                continue
            }
            
            if consider(tc, new_attempt[:]) {
                // Move to next size if we failed
                break
            } else if combo.x > 0 && new_attempt[combo.x - 1] > 0 {
                // With dependant values (e.g. first choice is a number of items that
                //  is used as how many choices should be made), it's problematic to
                //  remove the downstream values without adjusting the first choice.
                // This can potentially get us unstuck from such situation.
                new_attempt[combo.x - 1] -= 1
                consider(tc, new_attempt[:])
            }
        }
    }
}

// Shrink by setting 'n' elements to zero
// TODO: Should we do sliding windows or and/or a tree of blocks?
// TODO: When a large block fails, smaller blocks should not 'rezero' an already
//  empty block and NOT re-tre zero blocks
// TODO: can probably be more efficient of we do 'size' block combos, now we stop early
shrink_zero_blocks :: proc(tc: ^Test_Context) {
    // Test different sizes of zero blocks
    sizes :[3]int = {8, 4, 2}
    
    for size in sizes {
        combos := make([dynamic][dynamic]u64)
        defer {
            for c in combos {
                delete(c)
            }

            delete(combos)
        }
                
        zero_combinations(tc.result[:], size, &combos)
                
        for new_attempt in combos {
            failed := consider(tc, new_attempt[:])
            // TODO: Is this correct?
            if failed {
                break
            }
        }
    }
}

// Shrink by making the attempt elements smaller
// TODO: This can be cleaned up wrt 'new_attempt' and tc.result
shrink_reduce :: proc(tc: ^Test_Context) {
    new_attempt := slice.clone_to_dynamic(tc.result[:])
    defer delete(new_attempt)

    if !consider(tc, tc.result[:]) {
        // If we do not fail with the sequence, it's 'broken'
        //  - Is this a valid scenario, or an assert?
        // TODO: Investigate the appropriate action
        log.warn("Input to reduce do not fail!")
        return
    }
    
    for i := len(new_attempt) - 1; i >= 0; i -= 1 {
        low :u64 = 0
        // If we already are at low, we are done with this value
        if new_attempt[i] == low do continue
        
        high := u64(new_attempt[i])

        trial_low := slice.clone_to_dynamic(new_attempt[:])
        defer delete(trial_low)
        trial_low[i] = low
        
        if consider(tc, trial_low[:]) {
            // If we fail with the low value, we are done
            //return true, low
            new_attempt[i] = low
            continue
        }

        // Keep moving towards a smaller failing value
        mid: u64
        current_best := new_attempt[i]
        for low + 1 < high {
            mid = low + (high - low) / 2
            new_attempt[i] = mid
            if consider(tc, new_attempt[:]) {
                current_best = mid
                high = mid
            } else {
                low = mid
            }
        }

        // As we update new_attempt in place, we need to set the
        //  current best value as we might have ended with a sequence
        //  of values not improving
        new_attempt[i] = current_best
    }

    delete(tc.result)
    tc.result = slice.clone_to_dynamic(new_attempt[:], context.temp_allocator)
}

shrink_sort :: proc(tc: ^Test_Context) {
    sizes :[3]int = {8, 4, 2}

    for size in sizes {
        combos := make([dynamic][dynamic]u64)
        defer {
            for c in combos {
                delete(c)
            }

            delete(combos)
        }

        sort_combinations(tc.result[:], size, &combos)
        
        for new_attempt in combos {
            consider(tc, new_attempt[:])
        }
    }
}

// Shrink by redistributing values between two elements with different distances
// TODO: Remove input param
shrink_redistribute :: proc(tc: ^Test_Context, attempt: []u64) {
    new_attempt := slice.clone_to_dynamic(attempt, context.temp_allocator)
    defer delete(new_attempt)
    
    sizes :[2]int = {2, 1}

    for size in sizes {
        combos := index_combinations(0, len(attempt), size)
        defer delete(combos)
        
        #reverse for combo in combos {
            // Consider 0 as an already minimal value
            if attempt[combo.x] == 0 {
                continue
            }
                
            low : u64 = 0
            high := u64(attempt[combo.x])

            // Keep moving towards a smaller failing value
            mid: u64
            current_best_x := new_attempt[combo.x]
            current_best_y := new_attempt[combo.y]
            
            for low + 1 < high {
                mid = low + (high - low) / 2
                
                new_attempt[combo.x] = mid
                new_attempt[combo.y] = attempt[combo.x] + attempt[combo.y] - mid
                
                if consider(tc, new_attempt[:]) {
                    current_best_x = new_attempt[combo.x]
                    current_best_y = new_attempt[combo.y]

                    high = mid
                } else {
                    low = mid
                }
            }
        
            // As we update new_attempt in place, we need to set the
            //  current best value as we might have ended with a sequence
            //  of values not improving
            new_attempt[combo.x] = current_best_x
            new_attempt[combo.y] = current_best_y
        }
    }
}

// Swap two elements
shrink_swap :: proc(tc: ^Test_Context) {
    sizes :[2]int = {2, 1}

    for size in sizes {
        combos := make([dynamic][dynamic]u64)
        defer {
            for c in combos {
                delete(c)
            }

            delete(combos)
        }

        swap_combinations(tc.result[:], size, &combos)
        
        for new_attempt in combos {
            consider(tc, new_attempt[:])
        }
    }
}

////////////////////////////////////////
// Utils

swap_combinations :: proc(attempt: []u64, size: int, new_attempts: ^[dynamic][dynamic]u64) {
    combos := index_combinations(0, len(attempt), size)
    defer delete(combos)

    #reverse for combo in combos {
        // Consider 0 as an already minimal value
        if attempt[combo.x] == 0 {
            continue
        }

        x := attempt[combo.x]
        y := attempt[combo.y]

        // Don't swap already ordered elements
        if x <= y {
            continue
        }
        
        new_attempt := slice.clone_to_dynamic(attempt)

        new_attempt[combo.x] = y
        new_attempt[combo.y] = x
        
        // Only append if the sort had any effect
        if !slice.equal(attempt[:], new_attempt[:]) {
            append(new_attempts, new_attempt)
        } else {
            delete(new_attempt)
        }
    }
}

sort_combinations :: proc(attempt: []u64, size: int, new_attempts: ^[dynamic][dynamic]u64) {
    combos := index_combinations(0, len(attempt) + 1, size)
    defer delete(combos)

    #reverse for combo in combos {
        new_attempt := slice.clone_to_dynamic(attempt)
        
        trial   := new_attempt[combo.x : combo.y]
        slice.sort(trial)

        // Only append if the sort had any effect
        if !slice.equal(attempt[:], new_attempt[:]) {
            append(new_attempts, new_attempt)
        } else {
            delete(new_attempt)
        }
    }
}

zero_combinations :: proc(attempt: []u64, size: int, new_attempts: ^[dynamic][dynamic]u64) {
    combos := index_combinations(0, len(attempt) + 1, size)
    defer delete(combos)

    #reverse for combo in combos {
        new_attempt := slice.clone_to_dynamic(attempt)
        for idx in combo.x..<combo.y {
            new_attempt[idx] = 0
        }
        append(new_attempts, new_attempt)
    }
}

index_combinations :: proc(start: int, end: int, size: int) -> [dynamic][2]int {
    combos := make([dynamic][2]int)

    for i in start..<end - size {
        idx :[2]int = {i, i + size}
        append(&combos, idx)
    }
    
    return combos
}

