//! Implements the optimized candidate solution for the sample problem.

use std::io::{self, Read};

/// Sums unsigned decimal integers in an ASCII input buffer.
fn sum_ascii(input: &[u8]) -> u64 {
    let mut sum = 0u64;
    let mut value = 0u64;

    for &byte in input {
        if byte.is_ascii_digit() {
            value = value * 10 + u64::from(byte - b'0');
        } else {
            sum += value;
            value = 0;
        }
    }

    sum + value
}

/// Reads and solves the sample problem.
///
/// # Panics
///
/// Panics when standard input cannot be read.
fn main() {
    let mut input = Vec::new();
    io::stdin()
        .lock()
        .read_to_end(&mut input)
        .expect("failed to read standard input");

    println!("{}", sum_ascii(&input));
}

#[cfg(test)]
mod tests {
    use super::sum_ascii;

    /// Verifies whitespace-separated and unterminated inputs.
    #[test]
    fn sums_ascii_integers() {
        assert_eq!(sum_ascii(b"10 20\n30"), 60);
    }
}
