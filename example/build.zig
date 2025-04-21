const std = @import("std");

pub fn build(b: *std.Build) !void {
    b.reference_trace = 10;
    const optimise = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const tsq_module = b.addModule("TSQ", .{
        .root_source_file = b.path("../src/tsq.zig"),
    });

    const exe = b.addExecutable(.{
        .name = "TSQ",
        .root_source_file = b.path("./src/example.zig"),
        .target = target,
        .optimize = optimise,
    });
    exe.root_module.addImport("TSQ", tsq_module); 

    // building executable
    b.installArtifact(exe);
}