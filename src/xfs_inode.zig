const std = @import("std");

pub const inode_entry = @import("./inode_entry.zig").inode_entry;
pub const xfs_extent_t = @import("./xfs_extent.zig").xfs_extent_t;

const c = @cImport({
    @cDefine("ASSERT", "");
    @cInclude("stddef.h");
    @cInclude("xfs/xfs.h");
    @cInclude("xfs/xfs_arch.h");
    @cInclude("xfs/xfs_format.h");
});

const xfs_error = error{
    sb_magic,
    agf_magic,
    agi_magic,
};

pub const callback_t = fn (*inode_entry) anyerror!void;

pub const xfs_inode_t = struct {
    dinode: c.xfs_dinode,
    pub fn create(
        inode_header: c.xfs_dinode,
        extent_recovered_from_list: *std.ArrayList(xfs_extent_t),
    ) xfs_inode_t {
        _ = extent_recovered_from_list;
        return xfs_inode_t{
            .dinode = inode_header,
        };
    }
};
