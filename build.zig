const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigcli_dep = b.dependency("zig-cli", .{ .target = target });
    const zigcli_mod = zigcli_dep.module("zig-cli");

    const xfs_undelete = b.addExecutable(.{
        .name = "xfs_undelete",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    xfs_undelete.root_module.addImport("zig-cli", zigcli_mod);

    xfs_undelete.addSystemIncludePath(.{
        .path = "/nix/store/23v80anf3q5zip8ldlps7hzijnj0gx8w-xfsprogs-6.6.0-dev/include",
    });
    xfs_undelete.addSystemIncludePath(.{
        .path = "/nix/store/sw3a1cypmpgh8gvlhhxby0wl9f80wg53-util-linux-minimal-2.40.1-dev/include",
    });
    xfs_undelete.addSystemIncludePath(.{
        .path = "/nix/store/2hmd2c81sv9qpdh49xvcyvr6m1iahrs5-linux-6.9.2-dev/lib/modules/6.9.2/source/include",
    });

    b.installArtifact(xfs_undelete);

    const run_demo = b.addRunArtifact(xfs_undelete);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_demo.step);
    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_demo.addArgs(args);
    }
}
