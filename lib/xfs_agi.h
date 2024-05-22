#ifndef _XFS_AGI_H_
#define _XFS_AGI_H_

/*
 * Each AG manages its own inodes.
 *
 * The third sector in the AG contains information about the AG’s inodes and is known as the AGI.
 *
 */

#include "xfs_types.h"

#include <linux/types.h>

constexpr uint64_t XFS_AGI_UNLINKED_BUCKETS = 64;

constexpr uint64_t XFS_AGI_MAGIC = 0x58414749; /* 'XAGI' */

using xfs_agi_t = struct xfs_agi
{
    /*
     * Common allocation group header information
     */
    __be32 agi_magicnum;   /* magic number == XFS_AGI_MAGIC */
    __be32 agi_versionnum; /* header version == XFS_AGI_VERSION */
    __be32 agi_seqno;      /* sequence # starting from 0 */
    __be32 agi_length;     /* size in blocks of a.g. */
    /*
     * Inode information
     * Inodes are mapped by interpreting the inode number, so no
     * mapping data is needed here.
     */
    __be32 agi_count;     /* count of allocated inodes */
    __be32 agi_root;      /* root of inode btree */
    __be32 agi_level;     /* levels in inode btree */
    __be32 agi_freecount; /* number of free inodes */
    __be32 agi_newino;    /* new inode just allocated */
    __be32 agi_dirino;    /* last directory inode chunk */
    /*
     * Hash table of inodes which have been unlinked but are
     * still being referenced.
     */
    __be32 agi_unlinked[XFS_AGI_UNLINKED_BUCKETS];
    /*
     * This marks the end of logging region 1 and start of logging region 2.
     */
    uuid_t agi_uuid; /* uuid of filesystem */
    __be32 agi_crc;  /* crc of agi sector */
    __be32 agi_pad32;
    __be64 agi_lsn; /* last write sequence */

    __be32 agi_free_root;  /* root of the free inode btree */
    __be32 agi_free_level; /* levels in free inode btree */

    /* structure must be padded to 64 bit alignment */
};

#endif // !_XFS_AGI_H_
