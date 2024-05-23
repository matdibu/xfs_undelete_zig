#ifndef _XFS_TREES_H_
#define _XFS_TREES_H_

#include "xfs_types.h"

#include <cstddef>
#include <linux/types.h>

#define XFS_IBT_MAGIC      0x49414254 /* 'IABT' */
#define XFS_IBT_CRC_MAGIC  0x49414233 /* 'IAB3' */
#define XFS_FIBT_MAGIC     0x46494254 /* 'FIBT' */
#define XFS_FIBT_CRC_MAGIC 0x46494233 /* 'FIB3' */

/* size of a short form block */
#define XFS_BTREE_SBLOCK_LEN (offsetof(struct xfs_btree_block, bb_u) + offsetof(struct xfs_btree_block_shdr, bb_blkno))
/* size of a long form block */
#define XFS_BTREE_LBLOCK_LEN (offsetof(struct xfs_btree_block, bb_u) + offsetof(struct xfs_btree_block_lhdr, bb_blkno))

/* sizes of CRC enabled btree blocks */
#define XFS_BTREE_SBLOCK_CRC_LEN (offsetof(struct xfs_btree_block, bb_u) + sizeof(struct xfs_btree_block_shdr))
#define XFS_BTREE_LBLOCK_CRC_LEN (offsetof(struct xfs_btree_block, bb_u) + sizeof(struct xfs_btree_block_lhdr))

/*
 * Generic Btree block format definitions
 *
 * This is a combination of the actual format used on disk for short and long
 * format btrees.  The first three fields are shared by both format, but the
 * pointers are different and should be used with care.
 *
 * To get the size of the actual short or long form headers please use the size
 * macros below.  Never use sizeof(xfs_btree_block).
 *
 * The blkno, crc, lsn, owner and uuid fields are only available in filesystems
 * with the crc feature bit, and all accesses to them must be conditional on
 * that flag.
 */
/* short form block header */
struct xfs_btree_block_shdr
{
    __be32 bb_leftsib;
    __be32 bb_rightsib;

    __be64 bb_blkno;
    __be64 bb_lsn;
    uuid_t bb_uuid;
    __be32 bb_owner;
    __le32 bb_crc;
};

/* long form block header */
struct xfs_btree_block_lhdr
{
    __be64 bb_leftsib;
    __be64 bb_rightsib;

    __be64 bb_blkno;
    __be64 bb_lsn;
    uuid_t bb_uuid;
    __be64 bb_owner;
    __le32 bb_crc;
    __be32 bb_pad; /* padding for alignment */
};

struct xfs_btree_block
{
    __be32 bb_magic;   /* magic number for block type */
    __be16 bb_level;   /* 0 is a leaf */
    __be16 bb_numrecs; /* current # of data records */
    union
    {
        struct xfs_btree_block_shdr s;
        struct xfs_btree_block_lhdr l;
    } bb_u; /* rest */
};

#define XFS_ABTB_CRC_MAGIC 0x41423342 /* 'AB3B' */

/*
 * Data record/key structure
 */
using xfs_alloc_rec_t = struct xfs_alloc_rec
{
    __be32 ar_startblock; /* starting block number */
    __be32 ar_blockcount; /* count of free blocks */
};
using xfs_alloc_key_t = xfs_alloc_rec_t;

using xfs_alloc_rec_incore_t = struct xfs_alloc_rec_incore
{
    xfs_agblock_t ar_startblock; /* starting block number */
    xfs_extlen_t  ar_blockcount; /* count of free blocks */
};

/* btree pointer type */
using xfs_alloc_ptr_t = __be32;

#endif // !_XFS_TREES_H_
