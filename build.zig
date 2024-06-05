const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const xfs_undelete = b.addExecutable(.{
        .name = "xfs_undelete",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const zigcli_dep = b.dependency("zig-cli", .{ .target = target });
    const zigcli_mod = zigcli_dep.module("zig-cli");
    xfs_undelete.root_module.addImport("zig-cli", zigcli_mod);

    xfs_undelete.addSystemIncludePath(.{
        .cwd_relative = "/nix/store/23v80anf3q5zip8ldlps7hzijnj0gx8w-xfsprogs-6.6.0-dev/include",
    });

    xfs_undelete.linkSystemLibrary("uuid");
    // the target header is at $UTIL_LINUX/include/uuid/uuid.h
    // "pkg-config uuid" returns the "include/uuid" subdir,
    // but xfsprogs-dev wants to include "uuid/uuid.h"
    xfs_undelete.addSystemIncludePath(.{
        .cwd_relative = "/nix/store/h45bgvgr7ljv8qx5jmrd9vw1ll7df29l-util-linux-minimal-2.39.3-dev/include",
    });

    b.installArtifact(xfs_undelete);

    const run_demo = b.addRunArtifact(xfs_undelete);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_demo.step);
    if (b.args) |args| {
        run_demo.addArgs(args);
    }
}
