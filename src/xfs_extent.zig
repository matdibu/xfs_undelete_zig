const std = @import("std");

pub const inode_entry = @import("./inode_entry.zig").inode_entry;
pub const xfs_inode_t = @import("./xfs_inode.zig").xfs_inode_t;

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
    no_0_start_offset,
};

pub const xfs_extent_t = struct {
    pub fn create(packed_extent: c.xfs_bmbt_rec_t) xfs_extent_t {
        _ = packed_extent;
        return xfs_extent_t{};
    }
    pub fn is_valid(self: *const xfs_extent_t, superblock: c.xfs_dsb) bool {
        _ = self;
        _ = superblock;
        return false;
    }
    pub fn get_file_offset(self: *const xfs_extent_t) usize {
        _ = self;
        return 0;
    }
};
