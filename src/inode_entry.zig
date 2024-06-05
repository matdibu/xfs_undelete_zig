const std = @import("std");

const c = @import("c.zig").c;

const xfs_inode_t = @import("xfs_inode.zig").xfs_inode_t;
const xfs_extent_t = @import("xfs_extent.zig").xfs_extent_t;

pub const inode_entry = struct {
    inode_number: u64,
    extents: std.ArrayList(xfs_extent_t),

    pub fn init(
        inode: xfs_inode_t,
    ) inode_entry {
        return inode_entry{
            .inode_number = inode.inode,
            .extents = inode.extents,
        };
    }

    pub fn deinit(self: *inode_entry) void {
        self.extents.deinit();
    }
};
