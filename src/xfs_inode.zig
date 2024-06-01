const std = @import("std");

pub const inode_entry = @import("./inode_entry.zig").inode_entry;
pub const xfs_extent_t = @import("./xfs_extent.zig").xfs_extent_t;

const c = @import("./c.zig").c;

const xfs_error = error{
    sb_magic,
    agf_magic,
    agi_magic,
};

pub const xfs_inode_err = error{
    bad_magic,
    non_zero_mode,
    version_not_3,
    format_is_not_extents,
    non_zero_nlink,
};

pub const xfs_inode_t = struct {
    extents: std.ArrayList(xfs_extent_t),
    inode: c.xfs_ino_t,

    pub fn create(
        inode_header: *const c.xfs_dinode,
        extent_recovered_from_list: std.ArrayList(xfs_extent_t),
    ) xfs_inode_err!xfs_inode_t {
        if (c.XFS_DINODE_MAGIC != c.be16toh(inode_header.di_magic)) {
            return xfs_inode_err.bad_magic;
        }
        if (0 != inode_header.di_mode) {
            return xfs_inode_err.non_zero_mode;
        }
        if (3 != inode_header.di_version) {
            return xfs_inode_err.version_not_3;
        }
        if (c.XFS_DINODE_FMT_EXTENTS != inode_header.di_format) {
            return xfs_inode_err.format_is_not_extents;
        }
        if (0 != inode_header.di_nlink) {
            return xfs_inode_err.non_zero_nlink;
        }

        return xfs_inode_t{
            .extents = extent_recovered_from_list,
            .inode = c.be64toh(inode_header.di_ino),
        };
    }

    pub fn extents(self: *const xfs_inode_t) []xfs_extent_t {
        return self.extents.items;
    }

    pub fn deinit(self: *const xfs_inode_t) void {
        self.extents.deinit();
    }
};
