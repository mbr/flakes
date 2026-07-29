//! Reads complete challenge input into process-lifetime storage.

use std::{
    ffi::{c_int, c_long, c_void},
    io::{self, Read},
    ptr, slice,
};

/// Identifies the standard input file descriptor.
const STDIN_FILENO: c_int = 0;

/// Selects the current file position for [`lseek`].
const SEEK_CUR: c_int = 1;

/// Selects the end of a file for [`lseek`].
const SEEK_END: c_int = 2;

/// Permits reading from a memory mapping.
const PROT_READ: c_int = 1;

/// Prevents mapping writes from changing the underlying file.
const MAP_PRIVATE: c_int = 2;

/// Represents the failure sentinel returned by [`mmap`].
const MAP_FAILED: *mut c_void = usize::MAX as *mut c_void;

/// Defines the initial buffered input allocation.
const INPUT_CAPACITY: usize = 16 * 1024 * 1024;

unsafe extern "C" {
    /// Changes and reports an open file description's offset.
    fn lseek(file_descriptor: c_int, offset: c_long, whence: c_int) -> c_long;

    /// Maps bytes from an open file description into memory.
    fn mmap(
        address: *mut c_void,
        length: usize,
        protection: c_int,
        flags: c_int,
        file_descriptor: c_int,
        offset: c_long,
    ) -> *mut c_void;
}

/// Returns one standard-input file offset.
///
/// # Panics
///
/// Panics if standard input is not seekable.
#[inline(always)]
fn input_offset(whence: c_int) -> c_long {
    // SAFETY: The standard input descriptor is valid while the process runs.
    let offset = unsafe { lseek(STDIN_FILENO, 0, whence) };
    assert!(
        offset >= 0,
        "standard input must be seekable: {}",
        io::Error::last_os_error()
    );
    offset
}

/// Memory maps standard input into a process-lifetime byte slice.
///
/// # Panics
///
/// Panics unless standard input is a nonempty, seekable file positioned at its
/// start, or if the file cannot be mapped.
#[inline(always)]
pub fn read_input() -> &'static [u8] {
    let current_offset = input_offset(SEEK_CUR);
    assert_eq!(
        current_offset, 0,
        "standard input must start at offset zero"
    );
    let end_offset = input_offset(SEEK_END);
    let length = usize::try_from(end_offset).expect("standard input exceeds address space");
    assert!(length != 0, "standard input must not be empty");
    // SAFETY: The descriptor is seekable, the range is nonempty and within the
    // file, and the mapping requests read-only private access.
    let mapping = unsafe {
        mmap(
            ptr::null_mut(),
            length,
            PROT_READ,
            MAP_PRIVATE,
            STDIN_FILENO,
            0,
        )
    };
    assert_ne!(
        mapping,
        MAP_FAILED,
        "failed to map standard input: {}",
        io::Error::last_os_error()
    );

    // SAFETY: mmap returned a readable range of `length` bytes. The mapping is
    // intentionally retained until process exit.
    unsafe { slice::from_raw_parts(mapping.cast(), length) }
}

/// Reads standard input into a leaked buffered byte slice.
///
/// # Panics
///
/// Panics if standard input cannot be read.
#[inline(always)]
pub fn read_input_file() -> &'static [u8] {
    let mut input = Vec::with_capacity(INPUT_CAPACITY);
    io::stdin()
        .lock()
        .read_to_end(&mut input)
        .expect("failed to read stdin");
    input.leak()
}
