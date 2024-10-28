# Odin Property-based Testing

Property-based Testing (PBT) is a test generation technique which given a Property:

- Generate values
- Checks if the property holds
- Shrinks any failing counterexamples

A property can be thought of as: "For all these values, this property of the system under test should hold"

The goal of this package is to provide the necessary tools to perform PBT on Odin programs. This includes basic generators, generator combinators, and good shrinking.

## Status

The status of this package is **Pre-alpha**.

The package can already provide value but is not yet battle-tested. In addition, the APIs and names are all **open to change** given usage feedback.

I'm very open to usage feedback to better understand problems and limitations of the package.

There are many features that could be added; however, my willingness to do so is dependent on if the package provide value to users in the first place.

## What can PBT do for me?

To understand how PBT can help you test your programs you can, for example, check this talk by one of the inventors, John Hughes: [Testing the Hard Stuff and Staying Sane](https://www.youtube.com/watch?v=zi0rHwfiX1Q).

## How do I use the package?

The `examples` folder contain some basic examples, such as the one below. In addition, the package is tested with itself. Thus, the test folder can provide some usage examples.

```odin
package basics_example

import "core:fmt"

import "../../pbt"

// The proc we want to test. For some reason, it hates 13.
bad_add :: proc(x, y: u8) -> u8 {
    result := x + y

    if x == 13 {
        result -= 1
    }

    return result
}

main :: proc() {
    // Define the property: a proc taking a test case and returning a bool indicating if the
    //  property holds or not
    addition_works := proc(test: ^pbt.Test_Case) -> bool {
        // Draw two integers in the u8 domain
        x := pbt.draw(test, pbt.integers(0, 255))
        y := pbt.draw(test, pbt.integers(0, 255))

        // Call the proc we want to test
        result := bad_add(u8(x), u8(y))

        // In case the property fail, we can provide more specific reports
        pbt.make_test_report(test, "Addition of %v and %v failed", x, y)

        // Check if our invariant holds. We use '+' as our Oracle
        return result == u8(x + y)
    }

    // Check the property for a max of 10 000 examples
    test_context := pbt.check_property(addition_works, 10000)

    // Print the report.
    fmt.println(pbt.build_report(test_context))

    // Running this property we should see a failure that is shrunken to the minimal case of
    //  x = 13, y = 0
}
```

## Available generators

### Basic

- `integers` - Generate u64 values in a given range.
- `bool` - Generate bools given a weight.
- `f32/f64` - Generate floats in a given range.
- `strings_utf8` - Generate strings in the given UTF-8 range.
- `strings_alpha_numeric` - Generate alpha numeric strings.
- `strings_alphabet` - Generate strings with values drawn from the given alphabet string.

### Collections

- `lists` - Generate lists where values are drawn from the provided element generator.
- `maps` - Generate maps where the keys and values are drawn from the provided generators.

### Combinators

- `satisfy` - Draws from the provided generator and removes values not satisfying a predicate.
- `mapping` - Map a given procedure before returning the generated value.
- `bind` - Similar to `mapping` but returns a new generator, not a value.
- `one-of` - Given a list of possible generators, draw a value from one of them.
- `frequency` - Draws from one of the provided generators with a probability of the given frequency.
