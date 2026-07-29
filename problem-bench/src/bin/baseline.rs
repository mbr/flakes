//! Implements the straightforward reference solution for the sample problem.

use std::io::{self, Read};

/// Sums whitespace-delimited unsigned integers from standard input.
///
/// # Panics
///
/// Panics when standard input cannot be read or contains an invalid integer.
fn main() {
    let mut input = String::new();
    io::stdin()
        .lock()
        .read_to_string(&mut input)
        .expect("failed to read standard input");

    let sum: u64 = input
        .split_whitespace()
        .map(|value| {
            value
                .parse::<u64>()
                .expect("input contains an invalid integer")
        })
        .sum();

    println!("{sum}");
}
