#ifndef _XFS_INODE_HPP_
#define _XFS_INODE_HPP_

#include "xfs_extent.hpp" // extent_t
#include <xfs/xfs_types.h>

#include <linux/types.h>
#include <vector> // std::vector

#define XFS_DINODE_MAGIC 0x494e /* 'IN' */

namespace uf::xfs {
    struct xfs_inode;
    class Inode;
} // namespace uf::xfs

/*
 * On-disk inode structure.
 *
 * This is just the header or "dinode core", the inode is expanded to fill a
 * variable size the leftover area split into a data and an attribute fork.
 * The format of the data and attribute fork depends on the format of the
 * inode as indicated by di_format and di_aformat.
 *
 * There is a very similar struct icdinode in xfs_inode which matches the
 * layout of the first 96 bytes of this structure, but is kept in native
 * format instead of big endian.
 *
 * Note: di_flushiter is only used by v1/2 inodes - it's effectively a zeroed
 * padding field for v3 inodes.
 */
struct uf::xfs::xfs_inode
{
    __be16          di_magic;     /* inode magic # = XFS_DINODE_MAGIC */
    __be16          di_mode;      /* mode and type of file */
    __u8            di_version;   /* inode version */
    __u8            di_format;    /* format of di_c data */
    __be16          di_onlink;    /* old number of links to file */
    __be32          di_uid;       /* owner's user id */
    __be32          di_gid;       /* owner's group id */
    __be32          di_nlink;     /* number of links to file */
    __be16          di_projid_lo; /* lower part of owner's project id */
    __be16          di_projid_hi; /* higher part owner's project id */
    __u8            di_pad[6];    /* unused, zeroed space */
    __be16          di_flushiter; /* incremented on flush */
    xfs_timestamp_t di_atime;     /* time last accessed */
    xfs_timestamp_t di_mtime;     /* time last modified */
    xfs_timestamp_t di_ctime;     /* time created/inode modified */
    __be64          di_size;      /* number of bytes in file */
    __be64          di_nblocks;   /* # of direct & btree blocks used */
    __be32          di_extsize;   /* basic/minimum extent size for file */
    __be32          di_nextents;  /* number of extents in data fork */
    __be16          di_anextents; /* number of extents in attribute fork*/
    __u8            di_forkoff;   /* attr fork offs, <<3 for 64b align */
    __s8            di_aformat;   /* format of attr fork's data */
    __be32          di_dmevmask;  /* DMIG event mask */
    __be16          di_dmstate;   /* DMIG state info */
    __be16          di_flags;     /* random flags, XFS_DIFLAG_... */
    __be32          di_gen;       /* generation number */

    /* di_next_unlinked is the only non-core field in the old dinode */
    __be32 di_next_unlinked; /* agi unlinked list ptr */

    /* start of the extended dinode, writable fields */
    __le32 di_crc;         /* CRC of the inode */
    __be64 di_changecount; /* number of attribute changes */
    __be64 di_lsn;         /* flush sequence */
    __be64 di_flags2;      /* more random flags */
    __be32 di_cowextsize;  /* basic cow extent size for file */
    __u8   di_pad2[12];    /* more padding for future expansion */

    /* fields only written to during inode creation */
    xfs_timestamp_t di_crtime; /* time created */
    __be64          di_ino;    /* inode number */
    uuid_t          di_uuid;   /* UUID of the filesystem */

    /* structure must be padded to 64 bit alignment */
};

class uf::xfs::Inode
{
public:
    explicit Inode(const xfs_inode& InodeHeader);

    [[nodiscard]] const std::vector<Extent>& GetExtents() const noexcept;

    void SetExtents(std::vector<Extent> Extents) noexcept;

    [[nodiscard]] xfs_ino_t GetInodeNumber() const noexcept;

    [[nodiscard]] xfs_timestamp_t GetATime() const noexcept;
    [[nodiscard]] xfs_timestamp_t GetMTime() const noexcept;
    [[nodiscard]] xfs_timestamp_t GetCTime() const noexcept;
    [[nodiscard]] xfs_timestamp_t GetCrTime() const noexcept;

private:
    void Validate() const;

    xfs_inode           m_inodeHeader;
    std::vector<Extent> m_extents;
};

#endif // !_XFS_INODE_HPP_
