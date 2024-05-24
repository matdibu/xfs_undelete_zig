const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libfizzbuzz = b.addSharedLibrary(.{
        .name = "fizzbuzz",
        .root_source_file = b.path("lib/fizzbuzz.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
    });

    const demo = b.addExecutable(.{
        .name = "demo",
        .root_source_file = b.path("bin/demo.zig"),
        .target = target,
        .optimize = optimize,
        .linkage = .dynamic,
        .link_libc = true,
        .pic = true,
    });

    demo.linkLibrary(libfizzbuzz);

    b.installArtifact(libfizzbuzz);
    b.installArtifact(demo);

    const run_demo = b.addRunArtifact(demo);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_demo.step);
}
