const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const xfs_undelete = b.addExecutable(.{
        .name = "xfs_undelete",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .linkage = .dynamic,
    });

    xfs_undelete.linkLibC();

    const zigcli_dep = b.dependency("zig-cli", .{
        .target = target,
        .optimize = optimize,
    });
    const zigcli_mod = zigcli_dep.module("zig-cli");
    xfs_undelete.root_module.addImport("zig-cli", zigcli_mod);

    xfs_undelete.addSystemIncludePath(.{
        .cwd_relative = "/nix/store/1s5mym5ar49hwqmxn9baasyw0kbckgmf-xfsprogs-6.8.0-dev/include",
    });

    xfs_undelete.linkSystemLibrary("uuid");
    // the target header is at $UTIL_LINUX/include/uuid/uuid.h
    // "pkg-config uuid" returns the "include/uuid" subdir,
    // but xfsprogs-dev wants to include "uuid/uuid.h"
    xfs_undelete.addSystemIncludePath(.{
        .cwd_relative = "/nix/store/sw3a1cypmpgh8gvlhhxby0wl9f80wg53-util-linux-minimal-2.40.1-dev/include",
    });

    b.installArtifact(xfs_undelete);

    const run_demo = b.addRunArtifact(xfs_undelete);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_demo.step);
    if (b.args) |args| {
        run_demo.addArgs(args);
    }
}
