#ifndef _XFS_TYPES_H_
#define _XFS_TYPES_H_

#include <cstdint>
#include <ctime>
#include <linux/types.h>

typedef uint64_t xfs_fsblock_t;   /* blockno in filesystem (agno|agbno) */
typedef uint64_t xfs_rfsblock_t;  /* blockno in filesystem (raw) */
typedef uint64_t xfs_rtblock_t;   /* extent (block) in realtime area */
typedef uint64_t xfs_fileoff_t;   /* block number in a file */
typedef uint64_t xfs_filblks_t;   /* number of blocks in a file */
typedef uint64_t xfs_ino_t;       /* inode # */
typedef uint32_t xfs_agblock_t;   /* blockno in alloc. group */
typedef uint32_t xfs_agino_t;     /* inode # within allocation grp */
typedef uint32_t xfs_extlen_t;    /* extent length in blocks */
typedef uint32_t xfs_agnumber_t;  /* allocation group number */
typedef uint32_t xfs_extnum_t;    /* # of extents in a file */
typedef uint64_t xfs_lsn_t;       /* log sequence number */
typedef __be32   xfs_inobt_ptr_t; /* btree pointer type */

typedef unsigned char uuid_t[16];

/*
 * The on-disk inode record structure has two formats. The original "full"
 * format uses a 4-byte freecount. The "sparse" format uses a 1-byte freecou
nt
 * and replaces the 3 high-order freecount bytes wth the holemask and inode
 * count.
 *
 * The holemask of the sparse record format allows an inode chunk to have ho
les
 * that refer to blocks not owned by the inode record. This facilitates inod
e
 * allocation in the event of severe free space fragmentation.
 */
struct xfs_inobt_rec_t
{
    __be32 ir_startino; /* starting inode number */
    union
    {
        struct
        {
            __be32 ir_freecount; /* count of free inodes */
        } f;
        struct
        {
            __be16 ir_holemask;  /* hole mask for sparse chunks */
            __u8   ir_count;     /* total inode count */
            __u8   ir_freecount; /* count of free inodes */
        } sp;
    } ir_u;
    __be64 ir_free; /* free inode mask */
};

struct xfs_timestamp_t
{
    __be32 t_sec;  /* timestamp seconds */
    __be32 t_nsec; /* timestamp nanoseconds */
};

#define XFS_IOC_GETBMAP _IOWR('X', 38, struct getbmap)
/*
 * Structure for XFS_IOC_GETBMAP.
 * On input, fill in bmv_offset and bmv_length of the first structure
 * to indicate the area of interest in the file, and bmv_entries with
 * the number of array elements given back.  The first structure is
 * updated on return to give the offset and length for the next call.
 */
struct getbmap
{
    __s64 bmv_offset;  /* file offset of segment in blocks */
    __s64 bmv_block;   /* starting block (64-bit daddr_t)  */
    __s64 bmv_length;  /* length of segment, blocks        */
    __s32 bmv_count;   /* # of entries in array incl. 1st  */
    __s32 bmv_entries; /* # of entries filled in (output)  */
};

/* New bulkstat structure that reports v5 features and fixes padding issues */
struct xfs_bulkstat
{
    uint64_t bs_ino;  /* inode number         */
    uint64_t bs_size; /* file size            */

    uint64_t bs_blocks; /* number of blocks     */
    uint64_t bs_xflags; /* extended flags       */

    int64_t bs_atime; /* access time, seconds     */
    int64_t bs_mtime; /* modify time, seconds     */

    int64_t bs_ctime; /* inode change time, seconds   */
    int64_t bs_btime; /* creation time, seconds   */

    uint32_t bs_gen;       /* generation count     */
    uint32_t bs_uid;       /* user id          */
    uint32_t bs_gid;       /* group id         */
    uint32_t bs_projectid; /* project id           */

    uint32_t bs_atime_nsec; /* access time, nanoseconds */
    uint32_t bs_mtime_nsec; /* modify time, nanoseconds */
    uint32_t bs_ctime_nsec; /* inode change time, nanoseconds */
    uint32_t bs_btime_nsec; /* creation time, nanoseconds   */

    uint32_t bs_blksize;         /* block size           */
    uint32_t bs_rdev;            /* device value         */
    uint32_t bs_cowextsize_blks; /* cow extent size hint, blocks */
    uint32_t bs_extsize_blks;    /* extent size hint, blocks    */

    uint32_t bs_nlink;    /* number of links      */
    uint32_t bs_extents;  /* number of extents        */
    uint32_t bs_aextents; /* attribute number of extents  */
    uint16_t bs_version;  /* structure version        */
    uint16_t bs_forkoff;  /* inode fork offset in bytes   */

    uint16_t bs_sick;    /* sick inode metadata      */
    uint16_t bs_checked; /* checked inode metadata   */
    uint16_t bs_mode;    /* type and mode        */
    uint16_t bs_pad2;    /* zeroed           */

    uint64_t bs_pad[7]; /* zeroed           */
};

/* Header for bulk inode requests. */
struct xfs_bulk_ireq
{
    uint64_t ino;         /* I/O: start with this inode   */
    uint32_t flags;       /* I/O: operation flags     */
    uint32_t icount;      /* I: count of entries in buffer */
    uint32_t ocount;      /* O: count of entries filled out */
    uint32_t agno;        /* I: see comment for IREQ_AGNO */
    uint64_t reserved[5]; /* must be zero         */
};

/*
 * ioctl structures for v5 bulkstat and inumbers requests
 */
struct xfs_bulkstat_req
{
    struct xfs_bulk_ireq hdr;
    struct xfs_bulkstat  bulkstat[];
};
#define XFS_BULKSTAT_REQ_SIZE(nr) (sizeof(struct xfs_bulkstat_req) + (nr) * sizeof(struct xfs_bulkstat))

#define XFS_IOC_BULKSTAT _IOR('X', 127, struct xfs_bulkstat_req)

struct PanXfsMACTimes
{
    time_t TimeModified;
    time_t TimeAccessed;
    time_t TimeChanged;
    time_t TimeCreated;
};

#endif // _XFS_TYPES_H_
