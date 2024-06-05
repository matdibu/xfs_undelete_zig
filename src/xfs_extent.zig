const std = @import("std");

pub const inode_entry = @import("inode_entry.zig").inode_entry;
pub const xfs_inode_t = @import("xfs_inode.zig").xfs_inode_t;
pub const xfs_error = @import("xfs_error.zig").xfs_error;
pub const xfs_superblock = @import("xfs_superblock.zig").xfs_superblock;

const c = @import("c.zig").c;

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

    // copied from "xfsprogs-dev/libxfs/xfs_bit.h"
    fn xfs_mask64lo(comptime n: u64) u64 {
        return (1 << n) - 1;
    }

    // copied from "xfsprogs-dev/include/libxfs.h"
    fn libxfs_bmbt_disk_get_all(
        rec: *const c.xfs_bmbt_rec,
        irec: *c.xfs_bmbt_irec,
    ) void {
        const l0: u64 = c.be64toh(rec.l0);
        const l1: u64 = c.be64toh(rec.l1);

        irec.br_startoff = (l0 & xfs_mask64lo(64 - c.BMBT_EXNTFLAG_BITLEN)) >> 9;
        irec.br_startblock = ((l0 & xfs_mask64lo(9)) << 43) | (l1 >> c.BMBT_BLOCKCOUNT_BITLEN);
        irec.br_blockcount = l1 & xfs_mask64lo(c.BMBT_BLOCKCOUNT_BITLEN);
        if (0 != (l0 >> (64 - c.BMBT_EXNTFLAG_BITLEN))) {
            irec.br_state = c.XFS_EXT_UNWRITTEN;
        } else {
            irec.br_state = c.XFS_EXT_NORM;
        }
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
