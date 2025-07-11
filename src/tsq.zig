const std = @import("std");

// FIFO thread-safe priority queue implementation
pub fn createTSQ(comptime T: type) type {
    return struct {

        ////////////////////////
        // FIELD DECLARATIONS //
        ////////////////////////

        // basic struct creation variables
        const Self = @This();
        has_been_init: bool = false,
        alloc_used: std.mem.Allocator,

        // queue variables
        buffer: []?T,
        head_i: usize,
        tail_i: usize,
        count: usize,
        capacity: usize, // holds allocated size (num of T)
        final_i: usize, // a simple way of referencing capacity in array syntax

        // thread-relevant variable creation
        mutex: std.Thread.Mutex,
        cond_push: std.Thread.Condition,
        cond_pop: std.Thread.Condition,

        //////////////////////////////
        // PUBLIC FUNC DECLARATIONS //
        //////////////////////////////

        /// inits a thread-safe queue with a fixed capacity.
        /// PARAMS:
        /// - alloc: Allocator used for memory allocation.
        /// - capacity: Maximum number of items the queue can hold.
        pub fn init(alloc: std.mem.Allocator, capacity: usize) !Self {
            return .{
                .has_been_init = true,
                .alloc_used = alloc,
                .buffer = try alloc.alloc(?T, capacity),
                .head_i = 0,
                .tail_i = 0,
                .count = 0,
                .capacity = capacity,
                .final_i = (capacity - 1),
                .mutex = std.Thread.Mutex{},
                .cond_push = std.Thread.Condition{},
                .cond_pop = std.Thread.Condition{},
            };
        }

        /// Adds an item to the back of the queue. If the queue is full, this function blocks until space becomes available.
        /// PARAMS:
        /// - self: The queue instance.
        /// - value: The item to queue.
        pub fn push(self: *Self, value: T) !void {
            if (self.has_been_init == false) return error.Not_Initialised;

            // race condition prevention
            self.mutex.lock();
            defer self.mutex.unlock();

            // waiting until there is space in the buffer
            while (self.count >= self.capacity) {
                self.cond_pop.wait(&self.mutex); // waiting for removal of a value
            }

            // only increment tail pointer if non-empty
            if (try self.isEmpty() != true) {
                // if at "end" of buffer, act as circular slice --> next index at front (if avail)
                if (self.tail_i == self.final_i) { // circular increment
                    if (self.head_i == 0) return error.Trying_To_Overwrite_FIFO_Value; // this should not ever trigger as we wait for an empty spot using mutex above
                    self.tail_i = 0;
                } else { // non-circular increment
                    self.tail_i += 1;
                }
            }

            // adding to new location and increasing counter
            self.buffer[self.tail_i] = value;
            self.count += 1;

            // throwing signal to any threads waiting for value to be pushed
            self.cond_push.signal();
        }

        /// Removes and returns the front item from the queue. If the queue is empty, this function blocks until an item becomes available.
        /// PARAMS:
        /// - self: The queue instance.
        pub fn pop(self: *Self) !T {
            if (self.has_been_init == false) return error.Not_Initialised;

            // race condition prevention
            self.mutex.lock();
            defer self.mutex.unlock();

            // waiting until there is a non-empty buffer
            while (self.count <= 0) {
                self.cond_push.wait(&self.mutex); // waiting for value to be added (signal)
            }

            // incrementing head_i ptr (circular)
            const head_i_to_remove: usize = self.head_i;
            if (self.head_i == self.final_i and self.head_i != self.tail_i) { // circular increment
                self.head_i = 0;
            } else if (self.head_i == self.tail_i) {
                self.head_i = self.head_i;
            } else { // non-circular increment
                self.head_i += 1;
            }

            // popping from prev location and decreasing counter
            const opt_popped_val = self.buffer[head_i_to_remove];
            if (opt_popped_val == null) return error.Null_Popped;

            self.buffer[head_i_to_remove] = std.mem.zeroes(@TypeOf(self.buffer[head_i_to_remove]));
            self.count -= 1;

            // throwing signal to any other threads that are waiting for non-full queue
            self.cond_pop.signal();
            return opt_popped_val.?; // checked for null in lines above
        }

        /// Attempts to remove and return the front item from the queue. Returns an error if the queue is currently empty.
        /// PARAMS:
        /// - self: The queue instance.
        pub fn tryPop(self: *Self) !T {
            if (self.has_been_init == false) return error.Not_Initialised;
            var l_mutex_unlocked: bool = false; // var to avoid double unlock on mutex

            // grabbing mutex to check the queue without race conditions
            self.mutex.lock();
            errdefer if (l_mutex_unlocked == false) self.mutex.unlock(); // unlock mutex if not done so already

            // check if there is a valid item in queue, otherwise throw an error
            if (self.count == 0) return error.EMPTY_QUEUE;

            // release mutex (will again be grabbed within .pop func)
            self.mutex.unlock();
            l_mutex_unlocked = true; // to avoid double mutex unlock (on err below)
            
            return self.pop(); // running pop as usual (value available)
        }

        /// Returns the front item from the queue without removing it. Returns null if the queue is empty.
        /// PARAMS:
        /// - self: The queue instance.
        pub fn peek(self: *Self) !?T {
            if (self.has_been_init == false) return error.Not_Initialised;

            // race condition prevention
            self.mutex.lock();
            defer self.mutex.unlock();

            // waiting until there is a non-empty buffer
            if (self.count == 0) return null;

            // throwing error if head contains a null (shouldn't be able to view a null)
            return self.buffer[self.head_i] orelse return error.Peeked_Null_Ptr_When_Should_Be_Able_To;
        }

        /// Returns the total holding capacity of the queue.
        /// PARAMS:
        /// - self: The queue instance.
        pub fn getCapacity(self: *Self) !usize {
            if (self.has_been_init == false) return error.Not_Initialised;

            // race condition prevention
            self.mutex.lock();
            defer self.mutex.unlock();

            return self.capacity;
        }

        /// Returns the number of items currently in the queue.
        /// PARAMS:
        /// - self: The queue instance.
        pub fn getSize(self: *Self) !usize {
            if (self.has_been_init == false) return error.Not_Initialised;

            // race condition prevention
            self.mutex.lock();
            defer self.mutex.unlock();

            return self.count;
        }

        /// Prints the contents of the queue to stdout. Useful for debugging.
        /// PARAMS:
        /// - self: The queue instance.
        pub fn printQueue(self: *Self) !void {
            const stdout_writer = std.io.getStdOut().writer(); // stdout ptr
            if (self.has_been_init == false) return error.Not_Initialised;

            // race condition prevention
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.count == 0) {
                try stdout_writer.print("Queue is empty.\n", .{});
                return;
            }

            // printing each value in the queue
            try stdout_writer.print("Queue contents: ", .{});
            for (0..self.capacity) |curr_i| {
                try stdout_writer.print("{any} | ", .{self.buffer[curr_i]});
            }
            try stdout_writer.print("\n", .{});
        }

        /// Clears the queue by resetting indices and zeroing memory (user must handle allocated program-specific vars)
        /// PARAMS:
        /// - self: The queue instance.
        pub fn clear(self: *Self) !void {
            if (self.has_been_init == false) return error.Not_Initialised;

            // race condition prevention
            self.mutex.lock();
            defer self.mutex.unlock();

            // resetting obj fields --> memory of slice left unchanged (just not used)
            @memset(self.buffer, 0x0);
            self.head_i = 0;
            self.tail_i = 0;
            self.count = 0;
        }

        /// deinits the queue and frees all associated memory. After calling this, the queue must not be used again unless reinit.
        /// PARAMS:
        /// - self: The queue instance.
        pub fn deinit(self: *Self) !void {
            if (self.has_been_init == false) return error.Not_Initialised;

            // race condition prevention
            self.mutex.lock();

            // deinit all memory
            self.alloc_used.free(self.buffer);
            self.buffer = undefined;
            self.alloc_used = undefined;
            self.head_i = 0;
            self.tail_i = 0;
            self.count = 0;
            self.capacity = 0;
            self.final_i = 0;
            self.cond_push = undefined;
            self.cond_pop = undefined;
            self.mutex.unlock();
            self.mutex = undefined;

            // setting the deinitialised flag
            self.has_been_init = false;
        }

        ///////////////////////////////
        // PRIVATE FUNC DECLARATIONS //
        ///////////////////////////////

        /// Some of these functions are private as to prevent race conditions
        /// due to TSQ updates after a value is returned
        /// i.e. queue returns (isFull == false) as it has one empty spot but
        /// then the spot is filled by the time the user attempts to .push()

        /// Returns true if the queue is empty. Intended for internal use only — not thread-safe when used externally.
        /// PARAMS:
        /// - self: The queue instance.
        fn isEmpty(self: *Self) !bool {
            if (self.has_been_init == false) return error.Not_Initialised;
            // no race condition prevention
            return (self.count == 0); // will return true if empty
        }

        /// Returns true if the queue is full. Intended for internal use only — not thread-safe when used externally.
        /// PARAMS:
        /// - self: The queue instance.
        fn isFull(self: *Self) !bool {
            if (self.has_been_init == false) return error.Not_Initialised;

            // no race condition prevention
            return (self.count >= self.capacity); // will return true if at capacity
        }
    };
}
