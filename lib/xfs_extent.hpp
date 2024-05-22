#ifndef _XFS_EXTENT_HPP_
#define _XFS_EXTENT_HPP_

#include "xfs_superblock.h" // xfs_superblock_t

#include <linux/types.h>

namespace uf::xfs {
    struct xfs_bmbt_rec_t;
    class Extent;
} // namespace uf::xfs

/*
 * XFS manages space using extents, which are defined as a starting location and length.
 *
 * A fork in an XFS inode maps a logical offset to a space extent. This enables a file’s extent map to support sparse
 * files (i.e. “holes” in the file). A flag is also used to specify if the extent has been preallocated but has not yet
 * been written (unwritten extent).
 *
 * A file can have more than one extent if one chunk of contiguous disk space is not available for the file. As
 * a file grows, the XFS space allocator will attempt to keep space contiguous and to merge extents. If more than one
 * file is being allocated space in the same AG at the same time, multiple extents for the files will occur as the
 * extent allocations interleave.
 *
 * The effect of this can vary depending on the extent allocator used in the XFS driver.
 */

/*
 * Bmap btree record and extent descriptor.
 *  l0:63 is an extent flag (value 1 indicates non-normal).
 *  l0:9-62 are startoff.
 *  l0:0-8 and l1:21-63 are startblock.
 *  l1:0-20 are blockcount.
 */
#define BMBT_EXNTFLAG_BITLEN   1u
#define BMBT_STARTOFF_BITLEN   54u
#define BMBT_STARTBLOCK_BITLEN 52u
#define BMBT_BLOCKCOUNT_BITLEN 21u

#define BMBT_STARTOFF_MASK   ((1ULL << BMBT_STARTOFF_BITLEN) - 1)
#define BMBT_BLOCKCOUNT_MASK ((1ULL << BMBT_BLOCKCOUNT_BITLEN) - 1)

enum xfs_dinode_fmt
{
    XFS_DINODE_FMT_DEV,     /* xfs_dev_t */
    XFS_DINODE_FMT_LOCAL,   /* bulk data */
    XFS_DINODE_FMT_EXTENTS, /* struct xfs_bmbt_rec */
    XFS_DINODE_FMT_BTREE,   /* struct xfs_bmdr_block */
    XFS_DINODE_FMT_UUID     /* added long ago, but never used */
};

struct uf::xfs::xfs_bmbt_rec_t
{
    __be64 l0, l1;
};

enum xfs_exntst_t
{
    XFS_EXT_NORM,
    XFS_EXT_UNWRITTEN
};

class uf::xfs::Extent
{
public:
    // ctor with all the correct fields
    Extent(xfs_fileoff_t FileOffset, xfs_fsblock_t BlockOffset, xfs_filblks_t BlockCount, xfs_exntst_t State) noexcept;

    // ctor from packed big-endian disk struct
    explicit Extent(xfs_bmbt_rec_t DiskExtent) noexcept;

    [[nodiscard]] bool IsValid(const xfs_superblock_t& Superblock) const noexcept;

    [[nodiscard]] uint64_t GetInputOffset(const xfs_superblock_t& Superblock) const noexcept;

    [[nodiscard]] inline xfs_fileoff_t GetFileOffset() const noexcept
    {
        return m_fileOffset;
    }

    [[nodiscard]] inline xfs_filblks_t GetBlockCount() const noexcept
    {
        return m_blockCount;
    }

    [[nodiscard]] inline xfs_fsblock_t GetStartBlock() const noexcept
    {
        return m_blockOffset;
    }

private:
    xfs_fileoff_t m_fileOffset;  /* starting file offset */
    xfs_filblks_t m_blockCount;  /* number of blocks */
    xfs_fsblock_t m_blockOffset; /* starting block number */
    xfs_exntst_t  m_state;       /* extent state */
};

#endif // !_XFS_EXTENT_HPP_
