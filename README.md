# TSQ (Thread-Safe Queue)
TSQ is a Mutex-centric implementation of a thread-safe FIFO queue. This queue is designed to allow multiple threads to access data from one central memory location.

## Thread-Safety
Thread safety is achieved using:
* **Mutex (`std.Thread.Mutex`):** Provides exclusive access to the queue's internal state, preventing race conditions during modifications. Locks are acquired before operations and released afterward.
* **Condition Variables (`std.Thread.Condition`):** Enable efficient waiting for specific queue states:
    * `cond_pop`: Threads pushing to a full queue wait until an element is popped.
    * `cond_push`: Threads popping/peeking from an empty queue wait until an element is pushed.

This combination of locking and condition-based waiting synchronises concurrent operations, maintaining queue integrity without data corruption or "busy-waiting".

## API Layout
```zig
// Creates a thread-safe FIFO queue type parameterized over `T`.
createTSQ(T: type) TSQ_QUEUE

// Initializes the queue with a specified capacity.
// - `alloc`: The allocator used to reserve memory.
// - `capacity`: The maximum number of elements the queue can hold.
TSQ_QUEUE.init(alloc: std.mem.Allocator, capacity: usize) TSQ

// Adds an item to the queue. Blocks if the queue is full.
// - `value`: The item to add to the queue.
TSQ_QUEUE.push(value: T) !void

// Removes and returns the front item in the queue. Blocks if the queue is empty.
TSQ_QUEUE.pop() !T

// Returns the front item in the queue without removing it. Blocks if the queue is empty.
TSQ_QUEUE.peek() !T

// Returns the maximum number of items the queue can hold.
TSQ_QUEUE.getCapacity() !usize

// Returns the number of items currently in the queue.
TSQ_QUEUE.getSize() !usize

// Empties the queue. Does not free memory of heap-allocated objects within the queue (must be handled manually).
TSQ_QUEUE.clear() !void

// Cleans up and releases all memory/resources associated with the queue.
TSQ_QUEUE.deinit() !void

//// Private/Internal Helpers

// Returns true if the queue is currently empty. Uses internal locking.
TSQ_QUEUE.isEmpty() !bool

// Returns true if the queue has reached its capacity. Uses internal locking.
TSQ_QUEUE.isFull() !bool

//// Notes
// - All queue operations are thread-safe.
// - All public functions check for initialisation state.
// - Blocking semantics are handled via condition variables.
// - Uses circular indexing to manage the buffer efficiently.
```

## Usage
NOTE: At the time of v1.0.0's release, this code works on Zig v0.14.0.

To use TSQ in your project, simply follow the process below:
1. Fetch the TSQ repo from within one of the project's folders (must have a build.zig). This will automatically add the dependency to your project's build.zig.zon file (or create one if this currently does not exist).
An example for importing TSQ v1.0.0 is shown below:
```zig
zig fetch --save "https://github.com/rullo24/TSQ/archive/refs/tags/v1.0.0.tar.gz"
```
2. Add the TSQ dependency to your build.zig file
An example is shown below:
```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimise = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const tsq = b.dependency("TSQ", .{
        .target = target,
        .optimize = optimise,
    });

    const exe = b.addExecutable(.{
        .name = "tester",
        .root_source_file = b.path("test_tsq.zig"),
        .optimize = optimise,
        .target = target,
    });

    exe.root_module.addImport("TSQ", zeys.module("TSQ"));
    b.installArtifact(exe);
}
```

3. Import the TSQ module at the top of your code (main.zig or similar) using the "@import" method.
An example is shown below:
```zig
const std = @import("std");
const tsq = @import("TSQ");

pub fn main() void {

    return;
}
```