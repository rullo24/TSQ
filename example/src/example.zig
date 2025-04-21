const std = @import("std");
const tsq = @import("TSQ");

fn pushThread(queue: anytype) !void {
    for (1..20) |i| {
        try queue.push(@intCast(i));
        try queue.printQueue();
    }
}

fn popThread(queue: anytype) !void {
    var i: usize = 0;
    while (i < 40) : (i += 1) {
        _ = queue.pop() catch {
            std.debug.print("an error occurred\n", .{});
        };
        try queue.printQueue();
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const TSQ = tsq.createTSQ(i32);
    var queue = try TSQ.init(alloc, 5);
    defer { 
        var temp = queue.deinit();
        _ = &temp;
    }

    // Single-threaded test
    try queue.push(10);
    try queue.push(20);
    try queue.push(30);

    std.debug.print("Queue size: {any}\n", .{queue.getSize()});
    std.debug.print("Front element (peek): {any}\n", .{try queue.peek()});

    const popped = try queue.pop();
    std.debug.print("Popped: {any}\n", .{popped});

    std.debug.print("Queue size after pop: {any}\n", .{queue.getSize()});

    // Optional: Clear the queue
    try queue.clear();
    std.debug.print("Queue cleared. Size: {any}\n", .{queue.getSize()});

    // Multi-threaded test
    try queue.printQueue();
    var thread1 = try std.Thread.spawn(.{}, pushThread, .{&queue});
    var thread2 = try std.Thread.spawn(.{}, popThread, .{&queue});
    var thread3 = try std.Thread.spawn(.{}, pushThread, .{&queue});
    thread1.join();
    thread2.join();
    thread3.join();
    try queue.printQueue();

}

