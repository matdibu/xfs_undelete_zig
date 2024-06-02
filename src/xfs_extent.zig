const std = @import("std");

pub const inode_entry = @import("inode_entry.zig").inode_entry;
pub const xfs_inode_t = @import("xfs_inode.zig").xfs_inode_t;
pub const xfs_error = @import("xfs_error.zig").xfs_error;

const c = @import("c.zig").c;

pub const xfs_extent_t = struct {
    file_offset: c.xfs_fileoff_t,
    block_count: c.xfs_filblks_t,
    block_offset: c.xfs_fsblock_t,
    state: c.xfs_exntst_t,

    pub fn create(packed_extent: *const c.xfs_bmbt_rec_t) xfs_extent_t {
        const l0: u64 = c.be64toh(packed_extent.l0);
        const l1: u64 = c.be64toh(packed_extent.l1);

        return xfs_extent_t{
            .file_offset = l0 & c.BMBT_STARTOFF_MASK,
            .block_count = l1 & c.BMBT_BLOCKCOUNT_MASK,
            .block_offset = ((l0 & ~c.BMBT_STARTOFF_MASK) << (@as(u64, 63) - c.BMBT_STARTBLOCK_BITLEN)) + ((l1 & ~c.BMBT_BLOCKCOUNT_MASK) >> (c.BMBT_BLOCKCOUNT_BITLEN)),
            .state = @truncate(l0 & (~@as(u64, (@as(u64, std.math.maxInt(u64)) >> c.BMBT_EXNTFLAG_BITLEN)))),
        };
    }
    pub fn is_valid(self: *const xfs_extent_t, superblock: *const c.xfs_dsb) bool {
        if (c.XFS_EXT_UNWRITTEN == self.state) {
            return false;
        }
        if (0 == self.block_count and 0 == self.block_offset and 0 == self.file_offset and 0 == self.state) {
            return false;
        }
        if (self.get_input_offset(superblock) + self.block_count > c.be64toh(superblock.sb_dblocks)) {
            return false;
        }

        return true;
    }

    pub fn get_input_offset(self: *const xfs_extent_t, superblock: *const c.xfs_dsb) u64 {
        const ag_index: c.xfs_agnumber_t = @intCast((self.block_offset & ~(@as(u64, std.math.maxInt(u64)) << @intCast(superblock.sb_agblklog))) >> @intCast(superblock.sb_agblklog));
        const ag_relative_offset: c.xfs_fsblock_t = self.block_offset & ~(@as(u64, std.math.maxInt(u64)) << @intCast(superblock.sb_agblklog));
        const blocks_per_ag: c.xfs_filblks_t = c.be32toh(superblock.sb_blocksize);

        return ag_index * blocks_per_ag + ag_relative_offset;
    }
};
