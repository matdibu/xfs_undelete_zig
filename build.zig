const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libxfs_undelete = b.addSharedLibrary(.{
        .name = "xfs_undelete",
        .target = target,
        .optimize = optimize,
    });
    libxfs_undelete.linkLibCpp();
    libxfs_undelete.linkSystemLibrary("spdlog");

    const cflags = [_][]const u8{
        "-Wall",
        "-Wextra",
        "-pedantic",
        "-std=c++20",
    };

    libxfs_undelete.addCSourceFiles(
        .{
            .files = &.{
                "lib/linux_file.cpp",
                "lib/xfs_exceptions.cpp",
                "lib/xfs_extent.cpp",
                "lib/xfs_inode.cpp",
                "lib/xfs_inode_entry.cpp",
                "lib/xfs_parser.cpp",
            },
            .flags = &cflags,
        },
    );

    b.installArtifact(libxfs_undelete);
}
