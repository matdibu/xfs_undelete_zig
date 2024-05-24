const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const xfs_undelete = b.addExecutable(.{
        .name = "xfs_undelete",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(xfs_undelete);

    const run_demo = b.addRunArtifact(xfs_undelete);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_demo.step);
}
