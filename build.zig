const std = @import("std");

pub fn build(b: *std.Build) !void {
    b.reference_trace = 10;
    const optimise = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    _ = b.addModule("TSQ", .{
        .root_source_file = b.path("./src/tsq.zig"),
        .target = target,
        .optimize = optimise,
    });
}