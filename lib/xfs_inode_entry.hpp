#ifndef _XFS_INODE_ENTRY_HPP_
#define _XFS_INODE_ENTRY_HPP_

#include "linux_file.hpp" // utils::LinuxFile
#include "xfs_extent.hpp" // unpacked_extent_t
#include "xfs_types.h"    // xfs_timestamp_t

#include <cstdint> // uint8_t uint32_t uint64_t
#include <fstream> // std::ifstream
#include <vector>  // vector

namespace uf::xfs {
    class InodeEntry;
} // namespace uf::xfs

class uf::xfs::InodeEntry
{
public:
    InodeEntry(
        const utils::LinuxFile& Disk,
        const xfs_superblock_t& Superblock,
        uint64_t                InodeNumber,
        uint32_t                Blocksize,
        std::vector<Extent>     Extents,
        PanXfsMACTimes          MACTimes);

    bool GetInodeNumber(uint64_t* InodeNumber) const noexcept;
    bool GetSize(uint64_t* Size) const noexcept;
    bool GetMACTimes(PanXfsMACTimes* MACTimes) const noexcept;
    bool GetNextAvailableOffset(uint64_t* Offset, uint64_t* Size) noexcept;
    bool GetFileContent(uint8_t* DestBuffer, uint64_t Offset, uint64_t Size, uint64_t* BytesRead) const noexcept;

private:
    const utils::LinuxFile&             m_disk;
    const xfs_superblock_t&             m_superblock;
    const uint64_t                      m_inodeNumber;
    const uint64_t                      m_blocksize;
    const std::vector<Extent>           m_extents;
    std::vector<Extent>::const_iterator m_iterator;
    const PanXfsMACTimes                m_macTimes;
};

#endif // !_XFS_INODE_ENTRY_HPP_
