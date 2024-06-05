const std = @import("std");

pub const inode_entry = @import("inode_entry.zig").inode_entry;
pub const xfs_inode_t = @import("xfs_inode.zig").xfs_inode_t;
pub const xfs_error = @import("xfs_error.zig").xfs_error;
pub const xfs_superblock = @import("xfs_superblock.zig").xfs_superblock;

const c = @import("c.zig").c;
const xfs_mask64lo = @import("c.zig").xfs_mask64lo;
const libxfs_bmbt_disk_get_all = @import("c.zig").libxfs_bmbt_disk_get_all;

pub const xfs_extent_t = struct {
    block_offset: c.xfs_fsblock_t,
    block_count: c.xfs_filblks_t,
    file_offset: c.xfs_fileoff_t,
    state: c.xfs_exntst_t,

    pub fn create(packed_extent: *const c.xfs_bmbt_rec_t) xfs_extent_t {
        var irec: c.xfs_bmbt_irec = undefined;

        libxfs_bmbt_disk_get_all(packed_extent, &irec);

        return xfs_extent_t{
            .block_count = irec.br_blockcount,
            .block_offset = irec.br_startblock,
            .file_offset = irec.br_startoff,
            .state = irec.br_state,
        };
    }

    pub fn check(self: *const xfs_extent_t, superblock: *const xfs_superblock) xfs_error!void {
        if (c.XFS_EXT_UNWRITTEN == self.state) {
            return xfs_error.xfs_ext_unwritten;
        }
        if (0 == self.block_count and 0 == self.block_offset and 0 == self.file_offset and 0 == self.state) {
            return xfs_error.xfs_ext_zeroed;
        }
        if (self.get_input_offset(superblock) + self.block_count > superblock.sb_dblocks) {
            return xfs_error.xfs_ext_beyond_sb;
        }
    }

    pub fn get_input_offset(self: *const xfs_extent_t, superblock: *const xfs_superblock) u64 {
        const agblklog = @as(u64, std.math.maxInt(u64)) << @intCast(superblock.sb_agblklog);

        const ag_relative_offset: c.xfs_fsblock_t = self.block_offset & ~agblklog;

        const ag_index: c.xfs_agnumber_t = @intCast(ag_relative_offset >> @intCast(superblock.sb_agblklog));

        const blocks_per_ag: c.xfs_filblks_t = c.be32toh(superblock.sb_blocksize);

        return ag_index * blocks_per_ag + ag_relative_offset;
    }
};
