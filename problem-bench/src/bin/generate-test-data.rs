//! Generates deterministic workloads for the sample problem.

use std::{
    fs::{self, File},
    io::{self, BufWriter, Write},
    path::Path,
};

/// Defines the directory containing generated workloads.
const OUTPUT_DIR: &str = "bench-data";

/// Generates the sample workloads.
fn main() -> io::Result<()> {
    let output_dir = Path::new(OUTPUT_DIR);
    fs::create_dir_all(output_dir)?;

    generate_workload(output_dir, "small.txt", 1_000)?;
    generate_workload(output_dir, "large.txt", 1_000_000)?;

    Ok(())
}

/// Writes the inclusive integer range from one through `value_count`.
fn generate_workload(output_dir: &Path, name: &str, value_count: u64) -> io::Result<()> {
    let path = output_dir.join(name);
    let mut output = BufWriter::new(File::create(&path)?);

    for value in 1..=value_count {
        writeln!(output, "{value}")?;
    }

    output.flush()?;
    println!("generated {}", path.display());
    Ok(())
}
