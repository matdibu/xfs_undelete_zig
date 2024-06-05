pub const c = @cImport({
    @cDefine("ASSERT", ""); // ASSERT is undefined, stub it
    @cInclude("xfs/xfs.h");
    @cInclude("xfs/xfs_arch.h");
    @cInclude("xfs/xfs_format.h");
});

// see zig github issue #20112

// /* size of a short form block */
// #define XFS_BTREE_SBLOCK_LEN \
// <-->(offsetof(struct xfs_btree_block, bb_u) + \
// <--> offsetof(struct xfs_btree_block_shdr, bb_blkno))
// /* size of a long form block */
// #define XFS_BTREE_LBLOCK_LEN \
// <-->(offsetof(struct xfs_btree_block, bb_u) + \
// <--> offsetof(struct xfs_btree_block_lhdr, bb_blkno))
//
// /* sizes of CRC enabled btree blocks */
// #define XFS_BTREE_SBLOCK_CRC_LEN \
// <-->(offsetof(struct xfs_btree_block, bb_u) + \
// <--> sizeof(struct xfs_btree_block_shdr))
// #define XFS_BTREE_LBLOCK_CRC_LEN \
// <-->(offsetof(struct xfs_btree_block, bb_u) + \
// <--> sizeof(struct xfs_btree_block_lhdr))

pub const XFS_BTREE_SBLOCK_LEN = @offsetOf(c.xfs_btree_block, "bb_u") + @offsetOf(c.xfs_btree_block_shdr, "bb_blkno");
pub const XFS_BTREE_LBLOCK_LEN = @offsetOf(c.xfs_btree_block, "bb_u") + @offsetOf(c.xfs_btree_block_lhdr, "bb_blkno");
pub const XFS_BTREE_SBLOCK_CRC_LEN = @offsetOf(c.xfs_btree_block, "bb_u") + @sizeOf(c.xfs_btree_block_shdr);
pub const XFS_BTREE_LBLOCK_CRC_LEN = @offsetOf(c.xfs_btree_block, "bb_u") + @sizeOf(c.xfs_btree_block_lhdr);

// copied from "xfsprogs-dev/libxfs/xfs_bit.h"
fn xfs_mask64lo(comptime n: u64) u64 {
    return (1 << n) - 1;
}

// copied from "xfsprogs-dev/include/libxfs.h"
pub fn libxfs_bmbt_disk_get_all(
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
