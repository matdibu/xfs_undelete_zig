pub const c = @cImport({
    @cDefine("ASSERT", ""); // ASSERT is undefined, stub it
    @cInclude("stddef.h");
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
