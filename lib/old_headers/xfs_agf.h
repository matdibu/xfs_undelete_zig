#ifndef _XFS_AGF_H_
#define _XFS_AGF_H_
/*
 * The XFS filesystem tracks free space in an allocation group using two B+trees. One B+tree tracks space by block
 * number, the second by the size of the free space block. This scheme allows XFS to find quickly free space near a
 * given block or of a given size.
 *
 * All block numbers, indexes, and counts are AG relative.
 *
 */

#include "xfs_types.h"

#include <linux/types.h>

constexpr uint32_t XFS_AGF_MAGIC = 0x58414746; /* 'XAGF' */

using xfs_btnum_t = enum
{
    XFS_BTNUM_BNOi,
    XFS_BTNUM_CNTi,
    XFS_BTNUM_RMAPi,
    XFS_BTNUM_BMAPi,
    XFS_BTNUM_INOi,
    XFS_BTNUM_FINOi,
    XFS_BTNUM_REFCi,
    XFS_BTNUM_MAX
};

/*
 * Btree number 0 is bno, 1 is cnt, 2 is rmap. This value gives the size of
the
 * arrays below.
 */
#define XFS_BTNUM_AGF (static_cast<int>(XFS_BTNUM_RMAPi + 1))

using xfs_agf_t = struct xfs_agf
{
    /*
     * Common allocation group header information
     */
    __be32 agf_magicnum;   /* magic number == XFS_AGF_MAGIC */
    __be32 agf_versionnum; /* header version == XFS_AGF_VERSION */
    __be32 agf_seqno;      /* sequence # starting from 0 */
    __be32 agf_length;     /* size in blocks of a.g. */
    /*
     * Freespace and rmap information
     */
    __be32 agf_roots[XFS_BTNUM_AGF];  /* root blocks */
    __be32 agf_levels[XFS_BTNUM_AGF]; /* btree levels */

    __be32 agf_flfirst;  /* first freelist block's index */
    __be32 agf_fllast;   /* last freelist block's index */
    __be32 agf_flcount;  /* count of blocks in freelist */
    __be32 agf_freeblks; /* total free blocks */

    __be32 agf_longest;   /* longest free space */
    __be32 agf_btreeblks; /* # of blocks held in AGF btrees */
    uuid_t agf_uuid;      /* uuid of filesystem */

    __be32 agf_rmap_blocks;     /* rmapbt blocks used */
    __be32 agf_refcount_blocks; /* refcountbt blocks used */

    __be32 agf_refcount_root;  /* refcount tree root block */
    __be32 agf_refcount_level; /* refcount btree levels */

    /*
     * reserve some contiguous space for future logged fields before we add
     * the unlogged fields. This makes the range logging via flags and
     * structure offsets much simpler.
     */
    __be64 agf_spare64[14];

    /* unlogged fields, written during buffer writeback. */
    __be64 agf_lsn; /* last write sequence */
    __be32 agf_crc; /* crc of agf sector */
    __be32 agf_spare2;

    /* structure must be padded to 64 bit alignment */
};

#endif // !_XFS_AGF_H_
