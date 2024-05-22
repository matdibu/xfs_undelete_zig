#include "xfs_extent.hpp"

#include <endian.h> // be64toh

using uf::xfs::Extent;

Extent::Extent(
    xfs_fileoff_t FileOffset,
    xfs_fsblock_t BlockOffset,
    xfs_filblks_t BlockCount,
    xfs_exntst_t  State) noexcept
    : m_fileOffset(FileOffset)
    , m_blockCount(BlockCount)
    , m_blockOffset(BlockOffset)
    , m_state(State)
{}

Extent::Extent(xfs_bmbt_rec_t DiskExtent) noexcept
{
    // the extent is stored as two big-endian 64 bit chunks
    DiskExtent.l0 = be64toh(DiskExtent.l0);
    DiskExtent.l1 = be64toh(DiskExtent.l1);

    /*
     * Bmap btree record and extent descriptor.
     *  l0:63           : extent flag (value 1 indicates non-normal).
     *  l0:9-62         : file offset.
     *  l0:0-8 l1:21-63 : block offset.
     *  l1:0-20         : block count.
     */
    m_state      = static_cast<xfs_exntst_t>(DiskExtent.l0 & (~(static_cast<uint64_t>(-1ULL) >> BMBT_EXNTFLAG_BITLEN)));
    m_fileOffset = DiskExtent.l0 & BMBT_STARTOFF_MASK;
    m_blockOffset = ((DiskExtent.l0 & ~BMBT_STARTOFF_MASK) << (63ULL - BMBT_STARTBLOCK_BITLEN)) +
                    ((DiskExtent.l1 & ~BMBT_BLOCKCOUNT_MASK) >> BMBT_BLOCKCOUNT_BITLEN);
    m_blockCount = DiskExtent.l1 & BMBT_BLOCKCOUNT_MASK;
}

bool Extent::IsValid(const xfs_superblock_t& Superblock) const noexcept
{
    // extent has been preallocated but has not yet been written
    if (XFS_EXT_UNWRITTEN == m_state)
    {
        return false;
    }

    // zero length extents are not worth considering
    if (0 == m_blockCount)
    {
        return false;
    }

    // ignore unused extents (zeroed out)
    // could remove br_state from this check because of the previous check
    if (0 == m_blockCount && 0 == m_blockOffset && 0 == m_fileOffset && 0 == m_state)
    {
        return false;
    }

    // ignore extents beyond the filesystem
    // could there be an overflow here?
    if (GetInputOffset(Superblock) + m_blockCount > be64toh(Superblock.sb_dblocks))
    {
        return false;
    }

    return true;
}

uint64_t Extent::GetInputOffset(const xfs_superblock_t& Superblock) const noexcept
{
    // br_startblock is an unsigned 64 bit filesystem block number combining AG number and block offset into the AG.

    auto agIndex = static_cast<xfs_agnumber_t>(
        (m_blockOffset & ~((static_cast<uint64_t>(-1)) << Superblock.sb_agblklog)) >> Superblock.sb_agblklog);

    xfs_fsblock_t agRelativeOffset = m_blockOffset & ~((static_cast<uint64_t>(-1)) << Superblock.sb_agblklog);
    xfs_filblks_t blocksPerAG      = be32toh(Superblock.sb_blocksize);

    return agIndex * blocksPerAG + agRelativeOffset;
}
