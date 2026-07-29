//! Provides fixed-capacity process-lifetime allocation.

use std::{
    alloc::{GlobalAlloc, Layout},
    cell::UnsafeCell,
    mem::MaybeUninit,
    ptr,
    sync::atomic::{AtomicUsize, Ordering},
};

/// Defines the alignment of every returned allocation.
const ALLOCATION_ALIGNMENT: usize = 64;

/// Stores fixed-capacity allocation bytes at a cache-line boundary.
#[repr(C, align(64))]
struct Arena<const CAPACITY: usize> {
    /// Stores all allocation bytes.
    bytes: [MaybeUninit<u8>; CAPACITY],
}

/// Allocates aligned regions sequentially from embedded storage.
///
/// The allocator never reuses or releases memory. It must remain at a stable
/// address after its first allocation.
pub struct BumpAllocator<const CAPACITY: usize> {
    /// Stores the next unreserved byte offset.
    next: AtomicUsize,
    /// Stores all allocation bytes.
    memory: UnsafeCell<Arena<CAPACITY>>,
}

impl<const CAPACITY: usize> BumpAllocator<CAPACITY> {
    /// Creates an empty allocator.
    pub const fn new() -> Self {
        assert!(
            CAPACITY.is_multiple_of(ALLOCATION_ALIGNMENT),
            "bump allocator capacity must be a multiple of its alignment"
        );
        Self {
            next: AtomicUsize::new(0),
            memory: UnsafeCell::new(Arena {
                bytes: [MaybeUninit::uninit(); CAPACITY],
            }),
        }
    }
}

impl<const CAPACITY: usize> Default for BumpAllocator<CAPACITY> {
    /// Creates an empty allocator.
    fn default() -> Self {
        Self::new()
    }
}

// SAFETY: Atomic reservations give each caller a distinct memory range.
unsafe impl<const CAPACITY: usize> Sync for BumpAllocator<CAPACITY> {}

// SAFETY: Returned regions are disjoint, aligned, and remain valid while the
// allocator stays at its required stable address.
unsafe impl<const CAPACITY: usize> GlobalAlloc for BumpAllocator<CAPACITY> {
    #[inline(always)]
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        if layout.align() > ALLOCATION_ALIGNMENT {
            return ptr::null_mut();
        }

        let base = self.memory.get().cast::<u8>();
        let mut current = self.next.load(Ordering::Relaxed);
        loop {
            if layout.size() > CAPACITY - current {
                return ptr::null_mut();
            }
            let end = current + layout.size();
            let next = (end + ALLOCATION_ALIGNMENT - 1) & !(ALLOCATION_ALIGNMENT - 1);

            match self.next.compare_exchange_weak(
                current,
                next,
                Ordering::Relaxed,
                Ordering::Relaxed,
            ) {
                // SAFETY: The cursor identifies a complete range within the arena.
                Ok(_) => return unsafe { base.add(current) },
                Err(observed) => current = observed,
            }
        }
    }

    #[inline(always)]
    unsafe fn dealloc(&self, _pointer: *mut u8, _layout: Layout) {}
}

/// Tests fixed-capacity bump allocation.
#[cfg(test)]
mod tests {
    use std::alloc::{GlobalAlloc, Layout};

    use super::{ALLOCATION_ALIGNMENT, BumpAllocator};

    /// Verifies alignment, separation, and no-op deallocation.
    #[test]
    fn allocates_distinct_aligned_regions() {
        let allocator = BumpAllocator::<256>::new();
        let first_layout = Layout::from_size_align(13, 8).expect("valid first layout");
        let second_layout = Layout::from_size_align(17, 32).expect("valid second layout");

        // SAFETY: Both layouts have nonzero size and valid alignment.
        let first = unsafe { allocator.alloc(first_layout) };
        // SAFETY: Both layouts have nonzero size and valid alignment.
        let second = unsafe { allocator.alloc(second_layout) };

        assert!(!first.is_null());
        assert!(!second.is_null());
        assert_eq!(first.addr() % ALLOCATION_ALIGNMENT, 0);
        assert_eq!(second.addr() % ALLOCATION_ALIGNMENT, 0);
        assert!(second.addr() >= first.addr() + first_layout.size());

        // SAFETY: The pointer and layout identify the first allocation.
        unsafe { allocator.dealloc(first, first_layout) };
        let third_layout = Layout::from_size_align(1, 1).expect("valid third layout");
        // SAFETY: The layout has nonzero size and valid alignment.
        let third = unsafe { allocator.alloc(third_layout) };
        assert!(third.addr() >= second.addr() + second_layout.size());
    }

    /// Verifies allocation failure for unsupported layouts and exhaustion.
    #[test]
    fn rejects_overalignment_and_exhaustion() {
        let allocator = BumpAllocator::<64>::new();
        let over_aligned_layout =
            Layout::from_size_align(1, 128).expect("valid over-aligned layout");
        let full_layout = Layout::from_size_align(32, 1).expect("valid full layout");
        let extra_layout = Layout::from_size_align(1, 1).expect("valid extra layout");

        // SAFETY: Every layout has nonzero size and valid alignment.
        let over_aligned = unsafe { allocator.alloc(over_aligned_layout) };
        // SAFETY: Every layout has nonzero size and valid alignment.
        let full = unsafe { allocator.alloc(full_layout) };
        // SAFETY: Every layout has nonzero size and valid alignment.
        let extra = unsafe { allocator.alloc(extra_layout) };

        assert!(over_aligned.is_null());
        assert!(!full.is_null());
        assert!(extra.is_null());
    }
}
