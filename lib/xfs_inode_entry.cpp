#include "xfs_inode_entry.hpp"

#include <spdlog/spdlog.h>

using uf::xfs::Extent;
using uf::xfs::InodeEntry;

InodeEntry::InodeEntry(
    const utils::LinuxFile& Disk,
    const xfs_superblock_t& Superblock,
    uint64_t                InodeNumber,
    uint32_t                Blocksize,
    std::vector<Extent>     Extents,
    PanXfsMACTimes          MACTimes)
    : m_disk(Disk)
    , m_superblock(Superblock)
    , m_inodeNumber(InodeNumber)
    , m_blocksize(Blocksize)
    , m_extents(std::move(Extents))
    , m_iterator(m_extents.cbegin() - 1)
    , m_macTimes(MACTimes)
{}

bool InodeEntry::GetInodeNumber(uint64_t* const InodeNumber) const noexcept
{
    *InodeNumber = m_inodeNumber;

    return true;
}

bool InodeEntry::GetSize(uint64_t* const Size) const noexcept
{
    uint64_t result = 0;

    try
    {
        for (const auto& ex : m_extents)
        {
            result += ex.GetBlockCount() * m_blocksize;
        }
        *Size = result;
    }
    catch (const std::exception& exc)
    {
        spdlog::error("failed during GetSize: {}", exc.what());
        return false;
    }

    return true;
}

bool InodeEntry::GetMACTimes(PanXfsMACTimes* const MACTimes) const noexcept
{
    *MACTimes = m_macTimes;

    return true;
}

bool InodeEntry::GetNextAvailableOffset(uint64_t* const Offset, uint64_t* const Size) noexcept
{
    ++m_iterator;

    if (m_iterator == m_extents.cend())
        return false;

    *Offset = m_iterator->GetFileOffset();
    *Size   = m_iterator->GetBlockCount() * m_blocksize;

    return true;
}

bool InodeEntry::GetFileContent(uint8_t* const DestBuffer, uint64_t Offset, uint64_t Size, uint64_t* const BytesRead)
    const noexcept
{
    *BytesRead = 0;
    for (const auto& extent : m_extents)
    {
        // end of the current extent, as file offset
        uint64_t extentEndFileOffset = extent.GetFileOffset() + extent.GetBlockCount() * m_blocksize;

        // target file offset is between the start and end file offsets of the current extent
        if (Offset >= extent.GetFileOffset() && Offset <= extentEndFileOffset)
        {
            // disk offset of the current extent
            uint64_t extentStartInBytes = extent.GetStartBlock() * m_blocksize;

            // final overlapping file offset we will read from
            // the extent's disk offset in bytes + the offset within the extent
            uint64_t targetOffset = extentStartInBytes + Offset - extent.GetFileOffset();

            // size we can and want to read
            // min of the requested size and the size of overlapping extent
            uint64_t targetSize = std::min(Size, extentEndFileOffset - Offset);
            try
            {
                // read whatever overlaps with the current extent
                m_disk.ReadFromOffset(DestBuffer, targetOffset, targetSize);
            }
            catch (const utils::LinuxFileException& exc)
            {
                spdlog::error("ReadFromOffset failed: {}", exc.what());
                return false;
            }

            // add the number of bytes we have read
            *BytesRead += targetSize;
            // look for the next possible chunk
            Offset += targetSize;
            // subtract the bytes read
            Size -= targetSize;

            // nothing left to read
            if (Size == 0)
            {
                return true;
            }
        }
    }
    return *BytesRead != 0; // partial reads are treated as successes
    // return false;           // partial reads are treated as errors
}
