#ifndef _XFS_SUPERBLOCK_H_
#define _XFS_SUPERBLOCK_H_

/* Each AG starts with a superblock.
 * The first one, in AG 0, is the primary superblock which stores aggregate AG information.
 * Secondary superblocks are only used by xfs_repair when the primary superblock has been corrupted.
 * A superblock is one sector in length.
 */

#include "xfs_types.h"

#include <cstdint>

/*
 * Super block
 * Fits into a sector-sized buffer at address 0 of each allocation group.
 * Only the first of these is ever updated except during growfs.
 */
#define XFS_SB_MAGIC               0x58465342 /* 'XFSB' */
#define XFS_SB_VERSION_1           1u         /* 5.3, 6.0.1, 6.1 */
#define XFS_SB_VERSION_2           2u         /* 6.2 - attributes */
#define XFS_SB_VERSION_3           3u         /* 6.2 - new inode version */
#define XFS_SB_VERSION_4           4u         /* 6.2+ - bitmask version */
#define XFS_SB_VERSION_5           5u         /* CRC enabled filesystem */
#define XFS_SB_VERSION_NUMBITS     0x000fu
#define XFS_SB_VERSION_ALLFBITS    0xfff0u
#define XFS_SB_VERSION_ATTRBIT     0x0010u
#define XFS_SB_VERSION_NLINKBIT    0x0020u
#define XFS_SB_VERSION_QUOTABIT    0x0040u
#define XFS_SB_VERSION_ALIGNBIT    0x0080u
#define XFS_SB_VERSION_DALIGNBIT   0x0100u
#define XFS_SB_VERSION_SHAREDBIT   0x0200u
#define XFS_SB_VERSION_LOGV2BIT    0x0400u
#define XFS_SB_VERSION_SECTORBIT   0x0800u
#define XFS_SB_VERSION_EXTFLGBIT   0x1000u
#define XFS_SB_VERSION_DIRV2BIT    0x2000u
#define XFS_SB_VERSION_BORGBIT     0x4000u /* ASCII only case-insens. */
#define XFS_SB_VERSION_MOREBITSBIT 0x8000u

/*
 * There are two words to hold XFS "feature" bits: the original
 * word, sb_versionnum, and sb_features2.  Whenever a bit is set in
 * sb_features2, the feature bit XFS_SB_VERSION_MOREBITSBIT must be set.
 *
 * These defines represent bits in sb_features2.
 */
#define XFS_SB_VERSION2_RESERVED1BIT   0x00000001u
#define XFS_SB_VERSION2_LAZYSBCOUNTBIT 0x00000002u /* Superblk counters */
#define XFS_SB_VERSION2_RESERVED4BIT   0x00000004u
#define XFS_SB_VERSION2_ATTR2BIT       0x00000008u /* Inline attr rework */
#define XFS_SB_VERSION2_PARENTBIT      0x00000010u /* parent pointers */
#define XFS_SB_VERSION2_PROJID32BIT    0x00000080u /* 32 bit project id */
#define XFS_SB_VERSION2_CRCBIT         0x00000100u /* metadata CRCs */
#define XFS_SB_VERSION2_FTYPE          0x00000200u /* inode type in dir */

#define XFS_SB_FEAT_RO_COMPAT_FINOBT  (1u << 0u) /* free inode btree */
#define XFS_SB_FEAT_RO_COMPAT_RMAPBT  (1u << 1u) /* reverse map btree */
#define XFS_SB_FEAT_RO_COMPAT_REFLINK (1u << 2u) /* reflinked files */

#define XFS_SB_FEAT_INCOMPAT_FTYPE     (1u << 0u) /* filetype in dirent */
#define XFS_SB_FEAT_INCOMPAT_SPINODES  (1u << 1u) /* sparse inode chunks */
#define XFS_SB_FEAT_INCOMPAT_META_UUID (1u << 2u) /* metadata UUID */

#define XFSLABEL_MAX 12u

using xfs_superblock_t = struct xfs_superblock
{
    uint32_t       sb_magicnum;            /* magic number == XFS_SB_MAGIC */
    uint32_t       sb_blocksize;           /* logical block size, bytes */
    xfs_rfsblock_t sb_dblocks;             /* number of data blocks */
    xfs_rfsblock_t sb_rblocks;             /* number of realtime blocks */
    xfs_rtblock_t  sb_rextents;            /* number of realtime extents */
    uuid_t         sb_uuid;                /* user-visible file system unique id */
    xfs_fsblock_t  sb_logstart;            /* starting block of log if internal */
    xfs_ino_t      sb_rootino;             /* root inode number */
    xfs_ino_t      sb_rbmino;              /* bitmap inode for realtime extents */
    xfs_ino_t      sb_rsumino;             /* summary inode for rt bitmap */
    xfs_agblock_t  sb_rextsize;            /* realtime extent size, blocks */
    xfs_agblock_t  sb_agblocks;            /* size of an allocation group */
    xfs_agnumber_t sb_agcount;             /* number of allocation groups */
    xfs_extlen_t   sb_rbmblocks;           /* number of rt bitmap blocks */
    xfs_extlen_t   sb_logblocks;           /* number of log blocks */
    uint16_t       sb_versionnum;          /* header version == XFS_SB_VERSION */
    uint16_t       sb_sectsize;            /* volume sector size, bytes */
    uint16_t       sb_inodesize;           /* inode size, bytes */
    uint16_t       sb_inopblock;           /* inodes per block */
    char           sb_fname[XFSLABEL_MAX]; /* file system name */
    uint8_t        sb_blocklog;            /* log2 of sb_blocksize */
    uint8_t        sb_sectlog;             /* log2 of sb_sectsize */
    uint8_t        sb_inodelog;            /* log2 of sb_inodesize */
    uint8_t        sb_inopblog;            /* log2 of sb_inopblock */
    uint8_t        sb_agblklog;            /* log2 of sb_agblocks (rounded up) */
    uint8_t        sb_rextslog;            /* log2 of sb_rextents */
    uint8_t        sb_inprogress;          /* mkfs is in progress, don't mount */
    uint8_t        sb_imax_pct;            /* max % of fs for inode space */
    /* statistics */
    /*
     * These fields must remain contiguous.  If you really
     * want to change their layout, make sure you fix the
     * code in xfs_trans_apply_sb_deltas().
     */
    uint64_t sb_icount;    /* allocated inodes */
    uint64_t sb_ifree;     /* free inodes */
    uint64_t sb_fdblocks;  /* free data blocks */
    uint64_t sb_frextents; /* free realtime extents */
    /*
     * End contiguous fields.
     */
    xfs_ino_t    sb_uquotino;    /* user quota inode */
    xfs_ino_t    sb_gquotino;    /* group quota inode */
    uint16_t     sb_qflags;      /* quota flags */
    uint8_t      sb_flags;       /* misc. flags */
    uint8_t      sb_shared_vn;   /* shared version number */
    xfs_extlen_t sb_inoalignmt;  /* inode chunk alignment, fsblocks */
    uint32_t     sb_unit;        /* stripe or raid unit */
    uint32_t     sb_width;       /* stripe or raid width */
    uint8_t      sb_dirblklog;   /* log2 of dir block size (fsbs) */
    uint8_t      sb_logsectlog;  /* log2 of the log sector size */
    uint16_t     sb_logsectsize; /* sector size for the log, bytes */
    uint32_t     sb_logsunit;    /* stripe unit size for the log */
    uint32_t     sb_features2;   /* additional feature bits */
    /*
     * bad features2 field as a result of failing to pad the sb structure to
     * 64 bits. Some machines will be using this field for features2 bits.
     * Easiest just to mark it bad and not use it for anything else.
     *
     * This is not kept up to date in memory; it is always overwritten by
     * the value in sb_features2 when formatting the incore superblock to
     * the disk buffer.
     */
    uint32_t sb_bad_features2;

    /* version 5 superblock fields start here */

    /* feature masks */
    uint32_t sb_features_compat;
    uint32_t sb_features_ro_compat;
    uint32_t sb_features_incompat;
    uint32_t sb_features_log_incompat;

    uint32_t     sb_crc;         /* superblock crc */
    xfs_extlen_t sb_spino_align; /* sparse inode chunk alignment */

    xfs_ino_t sb_pquotino;  /* project quota inode */
    xfs_lsn_t sb_lsn;       /* last write sequence */
    uuid_t    sb_meta_uuid; /* metadata file system unique id */

    /* must be padded to 64 bit alignment */
};

#endif // !_XFS_SUPERBLOCK_H_
