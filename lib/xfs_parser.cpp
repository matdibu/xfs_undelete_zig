#include "xfs_parser.hpp"

#include "xfs_agf.h"           // xfs_agf_t
#include "xfs_agi.h"           // xfs_agi_t
#include "xfs_inode_entry.hpp" // uf::xfs::IInodeEntry
#include "xfs_tree.hpp"        // bplus_dump

#include <sstream> // std::stringstream

#include <spdlog/spdlog.h>

using uf::xfs::Extent;
using uf::xfs::IInodeCallback;
using uf::xfs::Inode;
using uf::xfs::Parser;
using uf::xfs::ValidationException;

Parser::Parser(const std::string& DevicePath)
    : m_device(DevicePath)
    , m_superblock{}
{
    spdlog::info("opened xfs partition \"{}\"", DevicePath.c_str());
    ReadSuperblock();
}

bool inline Parser::HasVersionFeature(uint16_t Flag) const noexcept
{
    return 0 != (Flag & be16toh(m_superblock.sb_versionnum));
}

bool inline Parser::HasVersion2Feature(uint32_t Flag) const noexcept
{
    return 0 != (Flag & be32toh(m_superblock.sb_features2));
}

bool inline Parser::HasROCompatFeature(uint32_t Flag) const noexcept
{
    return 0 != (Flag & be32toh(m_superblock.sb_features_ro_compat));
}

bool inline Parser::HasIncompatFeature(uint32_t Flag) const noexcept
{
    return 0 != (Flag & be32toh(m_superblock.sb_features_incompat));
}

void Parser::CheckSuperblockFlags() const
{
    std::stringstream log;
    log << "superblock version ";

    switch (uint16_t superblockVersion = XFS_SB_VERSION_NUMBITS & be16toh(m_superblock.sb_versionnum))
    {
    case XFS_SB_VERSION_1:
    case XFS_SB_VERSION_2:
    case XFS_SB_VERSION_3:
    case XFS_SB_VERSION_4:
    case XFS_SB_VERSION_5:
        log << superblockVersion;
        break;
    default:
        spdlog::error("unknown superblock version: {}x", superblockVersion);
        throw ValidationException("unkown superblock version");
    }
    spdlog::info("{}", log.str().c_str());

    spdlog::info("superblock features:");
    std::stringstream versionflags;
    versionflags << "\tversion: ";
    if (HasVersionFeature(XFS_SB_VERSION_ATTRBIT))
        versionflags << "attr ";

    if (HasVersionFeature(XFS_SB_VERSION_NLINKBIT))
        versionflags << "nlink ";

    if (HasVersionFeature(XFS_SB_VERSION_QUOTABIT))
        versionflags << "quota ";

    if (HasVersionFeature(XFS_SB_VERSION_ALIGNBIT))
        versionflags << "align ";

    if (HasVersionFeature(XFS_SB_VERSION_DALIGNBIT))
        versionflags << "dalign ";

    if (HasVersionFeature(XFS_SB_VERSION_SHAREDBIT))
        versionflags << "shared ";

    if (HasVersionFeature(XFS_SB_VERSION_LOGV2BIT))
        versionflags << "logv2 ";

    if (HasVersionFeature(XFS_SB_VERSION_SECTORBIT))
        versionflags << "sector ";

    if (HasVersionFeature(XFS_SB_VERSION_EXTFLGBIT))
        versionflags << "extflg ";

    if (HasVersionFeature(XFS_SB_VERSION_DIRV2BIT))
        versionflags << "dirv2 ";

    if (HasVersionFeature(XFS_SB_VERSION_BORGBIT))
        versionflags << "borg ";

    if (HasVersionFeature(XFS_SB_VERSION_MOREBITSBIT))
    {
        versionflags << "morebits ";

        if (HasVersion2Feature(XFS_SB_VERSION2_LAZYSBCOUNTBIT))
            versionflags << "lazysbcount";

        if (HasVersion2Feature(XFS_SB_VERSION2_ATTR2BIT))
            versionflags << "attr2 ";

        if (HasVersion2Feature(XFS_SB_VERSION2_PARENTBIT))
            versionflags << "parent ";

        if (HasVersion2Feature(XFS_SB_VERSION2_PROJID32BIT))
            versionflags << "projid32 ";

        if (HasVersion2Feature(XFS_SB_VERSION2_CRCBIT))
            versionflags << "crc ";

        if (HasVersion2Feature(XFS_SB_VERSION2_FTYPE))
            versionflags << "ftype ";
    }

    spdlog::info("{}", versionflags.str().c_str());

    std::stringstream rocompat;
    rocompat << "\trocompat: ";

    if (HasROCompatFeature(XFS_SB_FEAT_RO_COMPAT_FINOBT))
        rocompat << "finobt ";

    if (HasROCompatFeature(XFS_SB_FEAT_RO_COMPAT_RMAPBT))
        rocompat << "rmpabt ";

    if (HasROCompatFeature(XFS_SB_FEAT_RO_COMPAT_REFLINK))
        rocompat << "reflink ";

    spdlog::info("{}", rocompat.str().c_str());

    std::stringstream incompat;
    incompat << "\tincompat: ";
    if (HasIncompatFeature(XFS_SB_FEAT_INCOMPAT_FTYPE))
        incompat << "ftype ";

    if (HasIncompatFeature(XFS_SB_FEAT_INCOMPAT_SPINODES))
        incompat << "spinodes";

    if (HasIncompatFeature(XFS_SB_FEAT_INCOMPAT_META_UUID))
        incompat << "meta_uuid ";

    spdlog::info("{}", incompat.str().c_str());
}

void Parser::ReadSuperblock()
{
    m_device.ReadFromOffset(&m_superblock, 0, sizeof(xfs_superblock_t));

    if (XFS_SB_MAGIC != be32toh(m_superblock.sb_magicnum))
    {
        throw ValidationException("superblock magic");
    }

    CheckSuperblockFlags();
}

Inode Parser::ReadInode(const xfs_agnumber_t AGIndex, xfs_agino_t AGInode, uint32_t AGFRoot)
{
    uint16_t            fullInodeSize = be16toh(m_superblock.sb_inodesize);
    std::vector<Extent> extentFromTree;
    std::vector<Extent> extentFromList;

    // read the inode
    xfs_inode     inodeHeader = {};
    xfs_agblock_t BlocksPerAG = be32toh(m_superblock.sb_agblocks);
    uint32_t      blocksize   = be32toh(m_superblock.sb_blocksize);

    // the ag's offset
    uint64_t AGOffset =
        static_cast<uint64_t>(AGIndex) * static_cast<uint64_t>(BlocksPerAG) * static_cast<uint64_t>(blocksize);

    // ag's offset + inode's offset
    uint64_t seekOffset = AGOffset + static_cast<uint64_t>(AGInode) * static_cast<uint64_t>(fullInodeSize);

    // read the inode header
    m_device.ReadFromOffset(&inodeHeader, seekOffset, sizeof(xfs_inode));

    Inode result(inodeHeader);

    // TODO(mdibu): uncomment this when it can be tested automatically
#if 0
    // this actually never happens because, prior to deletion, a btree extent list is transformed into a 0-length extent list
    // if (XFS_DINODE_FMT_BTREE == dinode.di_format)
    if (0)
    {
        // we have to iterate ourselves through the first level of the tree since it's not like the other trees
        xfs_bmdr_block_t data_fork;
        disk.read(reinterpret_cast<char*>(&data_fork), sizeof(data_fork));

        std::vector<xfs_bmdr_ptr_t> ptrs;
        ptrs.resize((inode_size - sizeof(xfs_dinode_t) - sizeof(xfs_bmdr_block_t)) / sizeof(xfs_bmdr_ptr_t));
        uint64_t offset = (tree_len<xfs_bmdr_ptr_t>() + static_cast<uint64_t>(inode_size)) / 2LL;

        disk.clear();
        disk.seekg(seek_offset + offset, std::ios_base::beg);
        disk.read(reinterpret_cast<char*>(ptrs.data()), ptrs.size() * sizeof(xfs_bmdr_ptr_t));

        using namespace std::placeholders;
        auto callback = std::bind(extent_btree_callback, _1, _2, _3, _4, _5, &unpacked_tree);

        try
        {
            for (const auto& ptr : ptrs)
            {
                bplus_dump<xfs_bmdr_ptr_t, xfs_bmdr_rec_t>(
                    disk, sb, ag_index, ptr, XFS_BMAP_CRC_MAGIC, agf_broot, callback);
            }
        }
        catch (const std::exception&)
        {
            // probably not a bplustree
        }
    }
    else
#endif
    {
        // interpret the rest of the inode as an extent list

        // packed extents
        std::vector<xfs_bmbt_rec_t> packedExtents;

        size_t numberOfExtents = (fullInodeSize - sizeof(xfs_inode)) / sizeof(xfs_bmbt_rec_t);
        packedExtents.resize(numberOfExtents);

        // read the packed extents
        m_device.ReadFromOffset(
            packedExtents.data(), seekOffset + sizeof(inodeHeader), packedExtents.size() * sizeof(xfs_bmbt_rec_t));

        // unpack the extents
        bool has0offset = false; // if an inode has no extent starting a file offset 0, it's most likely bad
        for (const auto& packedExtent : packedExtents)
        {
            Extent extent(packedExtent);
            if (!extent.IsValid(m_superblock))
            {
                continue;
            }
            // only use the extents within the AGF
            for (const auto& validExtent : OnlyWithinAGF(extent, AGIndex, AGFRoot))
            {
                extentFromList.push_back(validExtent);
                if (validExtent.GetFileOffset() == 0)
                {
                    has0offset = true;
                }
            }
        }
        if (!has0offset)
        {
            throw ValidationException("no 0 start offset");
        }
    }

    if (extentFromList.empty() && extentFromTree.empty())
        throw ValidationException("no extents");

    if (extentFromList.size() > extentFromTree.size())
        result.SetExtents(extentFromList);
    else
        result.SetExtents(extentFromTree);

    return result;
}

bool Parser::InodeBTreeCallback(
    const xfs_agnumber_t AGIndex,
    xfs_inobt_rec_t      InobtRecord,
    uint32_t             AGFRoot,
    IInodeCallback*      InodeCallback)
{
    // each record holds 64 consecutive inodes
    uint32_t currentInode = be32toh(InobtRecord.ir_startino);
    uint32_t startInode   = currentInode;
    // we only need look for free inodes
    uint64_t freeMask = be64toh(InobtRecord.ir_free);
    // for sparse inode allocation
    uint16_t holeMask = be16toh(InobtRecord.ir_u.sp.ir_holemask);

    // as long as there are free inodes left
    while (0 != freeMask)
    {
        // each bit in the hole mask is 4 unavailable inodes
        if (HasIncompatFeature(XFS_SB_FEAT_INCOMPAT_SPINODES) && 0 != (holeMask & 1ULL))
        {
            holeMask >>= 1ULL;
            freeMask >>= 4ULL;
            currentInode += 4UL;
            continue;
        }
        // the current inode is marked as free and available
        if (0 != (freeMask & 1ULL))
        {
            try
            {
                spdlog::trace("[{}] attempting recovery", currentInode);

                Inode inode(ReadInode(AGIndex, currentInode, AGFRoot));

                PanXfsMACTimes macTimes{};
                macTimes.TimeModified = inode.GetMTime().t_sec;
                macTimes.TimeAccessed = inode.GetATime().t_sec;
                macTimes.TimeChanged  = inode.GetCTime().t_sec;
                macTimes.TimeCreated  = inode.GetCrTime().t_sec;

                xfs::InodeEntry entry(
                    m_device,
                    m_superblock,
                    inode.GetInodeNumber(),
                    be32toh(m_superblock.sb_blocksize),
                    inode.GetExtents(),
                    macTimes);

                if (!InodeCallback(entry))
                {
                    spdlog::error("callback returned false");
                    return false;
                }
            }
            catch (const std::exception& ex)
            {
                spdlog::trace("[{}] failed: {}", currentInode, ex.what());
            }
        }

        freeMask >>= 1ULL;
        ++currentInode;
        if (((currentInode - startInode) % 4) == 0)
            holeMask >>= 1ULL;
    }
    return true;
}

bool Parser::DumpInodes(IInodeCallback* InodeCallback)
{
    xfs_agf_t agFreeSpaceHeader       = {};
    xfs_agi_t agInodeManagementHeader = {};

    // use the trees in each AG
    for (xfs_agnumber_t agIndex = 0; agIndex < be32toh(m_superblock.sb_agcount); ++agIndex)
    {
        // seek to the second sector to read the AGF
        uint64_t seekOffset = be32toh(m_superblock.sb_blocksize) *
                                  static_cast<uint64_t>(be32toh(m_superblock.sb_agblocks)) *
                                  static_cast<uint64_t>(agIndex) +
                              static_cast<uint64_t>(be16toh(m_superblock.sb_sectsize));

        m_device.ReadFromOffset(&agFreeSpaceHeader, seekOffset, sizeof(xfs_agf_t));

        if (XFS_AGF_MAGIC != be32toh(agFreeSpaceHeader.agf_magicnum))
        {
            throw ValidationException("AGF magic");
        }

        // seek to the third sector
        // the third sector in the AG contains information about the AG’s inodes and
        // is known as the AGI.
        seekOffset += be16toh(m_superblock.sb_sectsize);

        // read the AGI
        m_device.ReadFromOffset(&agInodeManagementHeader, seekOffset, sizeof(agInodeManagementHeader));

        if (XFS_AGI_MAGIC != be32toh(agInodeManagementHeader.agi_magicnum))
        {
            throw ValidationException("AGI magic");
        }

        // the root of the free space tree (by block)
        uint32_t agfBlockNoRoot = be32toh(agFreeSpaceHeader.agf_roots[XFS_BTNUM_BNOi]);

        auto callback =
            [this, InodeCallback](const xfs_agnumber_t _agIndex, xfs_inobt_rec_t _inobtRecord, uint32_t _agfRoot) {
                InodeBTreeCallback(_agIndex, _inobtRecord, _agfRoot, InodeCallback);
            };

        // Each allocation group uses a “short format” B+tree to index
        // various information about the allocation group
        if (HasROCompatFeature(XFS_SB_FEAT_RO_COMPAT_FINOBT))
        {
            spdlog::info("dumping finobt in ag#{}", agIndex);
            // iterate through the free inode b+ tree
            // std::cout << "traversing free inode b+ tree #" << ag_index;
            BTreeWalk<xfs_inobt_ptr_t, xfs_inobt_rec_t>(
                m_device,
                m_superblock,
                agIndex,
                be32toh(agInodeManagementHeader.agi_free_root),
                XFS_FIBT_CRC_MAGIC,
                agfBlockNoRoot,
                callback);
        }
        else
        {
            spdlog::info("dumping inobt in ag#{}", agIndex);
            // iterate through the inode b+ tree
            // std::cout << "traversing inode b+ tree #" << ag_index;
            BTreeWalk<xfs_inobt_ptr_t, xfs_inobt_rec_t>(
                m_device,
                m_superblock,
                agIndex,
                be32toh(agInodeManagementHeader.agi_root),
                XFS_IBT_CRC_MAGIC,
                agfBlockNoRoot,
                callback);
        }
    }

    return true;
}

std::vector<Extent> Parser::OnlyWithinAGF(Extent Extent, const xfs_agnumber_t agIndex, const uint32_t agfRoot)
{
    spdlog::trace(
        "extracting free extents from (startblock:{}x fileoff:{}x blockcount:{}x)",
        Extent.GetStartBlock(),
        Extent.GetFileOffset(),
        Extent.GetBlockCount());
    std::vector<uf::xfs::Extent> result;

    xfs_agblock_t blocksPerAG = be32toh(m_superblock.sb_agblocks);
    uint32_t      blocksize   = be32toh(m_superblock.sb_blocksize);

    uint64_t agOffset =
        static_cast<uint64_t>(agIndex) * static_cast<uint64_t>(blocksPerAG) * static_cast<uint64_t>(blocksize);
    xfs_agf_t agfHeader{};

    m_device.ReadFromOffset(&agfHeader, agOffset + be16toh(m_superblock.sb_sectsize), sizeof(xfs_agf_t));

    // "treeCheck" needs relative block numbers, and the extents are absolute
    uf::xfs::Extent relativeExtent(
        Extent.GetFileOffset(),
        Extent.GetStartBlock() - agOffset / blocksize,
        Extent.GetBlockCount(),
        static_cast<xfs_exntst_t>(0));

    if (relativeExtent.GetStartBlock() > be32toh(agfHeader.agf_length))
    {
        spdlog::trace("extent's startblock is beyond the AG");
        return result;
    }

    uint64_t blockOffset = agOffset + agfRoot * static_cast<uint64_t>(blocksize);

    uint64_t ExtentBegin = relativeExtent.GetStartBlock();
    uint64_t ExtentEnd   = ExtentBegin + Extent.GetBlockCount();

    TreeCheck(Extent, agOffset, blockOffset, &ExtentBegin, &ExtentEnd, &result);

    return result;
}

void Parser::TreeCheck(
    const Extent&                 Extent,
    const uint64_t                AGOffset,
    const uint64_t                BlockOffset,
    uint64_t*                     ExtentBegin,
    uint64_t*                     ExtentEnd,
    std::vector<uf::xfs::Extent>* Result)
{
    xfs_btree_block btreeBlock = {};
    const uint32_t  blocksize  = be32toh(m_superblock.sb_blocksize);

    m_device.ReadFromOffset(&btreeBlock, BlockOffset, BTreeHeaderSize<xfs_alloc_ptr_t>());

    const uint16_t numberOfRecords = be16toh(btreeBlock.bb_numrecs);
    if (be16toh(btreeBlock.bb_level) > 0)
    {
        std::vector<xfs_alloc_key_t> keys;
        std::vector<xfs_alloc_ptr_t> ptrs;

        keys.resize(numberOfRecords);
        ptrs.resize(numberOfRecords);

        const auto max_numrecs = static_cast<uint16_t>(
            (blocksize - BTreeHeaderSize<xfs_alloc_ptr_t>()) / (sizeof(xfs_alloc_key_t) + sizeof(xfs_alloc_ptr_t)));

        m_device.ReadFromOffset(
            keys.data(), BlockOffset + BTreeHeaderSize<xfs_alloc_ptr_t>(), keys.size() * sizeof(xfs_alloc_key_t));

        // big-endian, again ...
        for (auto& key : keys)
        {
            key.ar_blockcount = be32toh(key.ar_blockcount);
            key.ar_startblock = be32toh(key.ar_startblock);
        }

        const uint64_t ptrs_offset = BTreeHeaderSize<xfs_alloc_ptr_t>() + max_numrecs * sizeof(xfs_alloc_key_t);
        m_device.ReadFromOffset(ptrs.data(), BlockOffset + ptrs_offset, ptrs.size() * sizeof(xfs_alloc_ptr_t));

        // big-endian, again ...
        for (auto& ptr : ptrs)
        {
            ptr = be32toh(ptr);
        }

        uint16_t left  = 0;
        uint16_t right = numberOfRecords - 1;

        while (left <= right)
        {
            uint16_t middle = (left + right) / 2;
            if (*ExtentBegin > keys[middle].ar_startblock)
            {
                left = middle + 1;
            }
            else if (*ExtentEnd < keys[middle].ar_startblock)
            {
                right = middle - 1;
            }
            else
            {
                // 'right' is always right
                right = middle;
                break;
            }
        }

        // seek to ptrs[right]
        uint64_t seekOffset = AGOffset + static_cast<uint64_t>(ptrs[right]) * blocksize;
        TreeCheck(Extent, AGOffset, seekOffset, ExtentBegin, ExtentEnd, Result);
    }
    else
    {
        // hit that leaf
        std::vector<xfs_alloc_rec_t> recs;

        recs.resize(numberOfRecords);

        m_device.ReadFromOffset(
            recs.data(), BlockOffset + BTreeHeaderSize<xfs_alloc_ptr_t>(), recs.size() * sizeof(xfs_alloc_rec_t));

        int16_t leftIndex  = 0;
        int16_t rightIndex = numberOfRecords - 1;

#if 0

    E  -> extent
    R  -> record
    _B -> begin
    _E -> end

    there are 4 overlapping cases:

      EB       EXTENT         EE
      <------------------------>
      |                        |
      |                        |
  RB  |  RE                    |
1 <------->                    |
      |                        |
      |                        |
  RB  |                        |  RE
2 <-------------------------------->
      |                        |
      |                        |
      |                    RB  |  RE
3     |                    <------->
      |                        |
      |                        |
      |   RB              RE   |
4     |   <---------------->   |
      |                        |


              RB             RE

      1: RB < EB < EE   EB < RE < EE
      2: RB < EB < EE   EB < EE < RE
      3: EB < RB < EE   EB < EE < RE
      4: EB < RB < EE   EB < RE < EE

we already checked:

         RE >= EB (!RE < EB)
         RB <= EE (!RB > EE)

after some simplications:

      1: RB < EB        RE < EE
      2: RB < EB        EE < RE
      3: EB < RB        EE < RE
      4: EB < RB        RE < EE

conditions:
    if RB <= EB
        add EB to min(RE,EE)
    else
        add RB to min(RE,EE)

after some simplications:

    add max(RB, EB) to min(RE,EE)

#endif
        while (leftIndex <= rightIndex)
        {
            int16_t middleIndex = (leftIndex + rightIndex) / 2;

            uint64_t RecordBegin = be32toh(recs[middleIndex].ar_startblock);
            uint64_t RecordEnd   = RecordBegin + be32toh(recs[middleIndex].ar_blockcount);

            // entire target is to the right of the record
            if (*ExtentBegin > RecordEnd)
            {
                leftIndex = middleIndex + 1;
            }

            // entire target is to the left of the record
            else if (*ExtentEnd < RecordBegin)
            {
                rightIndex = middleIndex - 1;
            }

            else
            {
                spdlog::trace("found overlapping extent {}u->{}u", RecordBegin, RecordEnd);

                uint64_t TargetBegin = std::max(RecordBegin, *ExtentBegin);
                uint64_t TargetEnd   = std::min(RecordEnd, *ExtentEnd);
                if (TargetBegin == TargetEnd)
                    return;

                spdlog::trace("added result of overlap ({}u->{}u) to valid extents", TargetBegin, TargetEnd);

                class Extent toBeAdded(
                    static_cast<xfs_fileoff_t>(Extent.GetFileOffset() + TargetBegin - *ExtentBegin),
                    static_cast<xfs_fsblock_t>(TargetBegin),
                    static_cast<xfs_filblks_t>(TargetEnd - TargetBegin),
                    static_cast<xfs_exntst_t>(0));

                Result->push_back(toBeAdded);

                // any part of the extent to the left is discarded
                *ExtentBegin = TargetEnd;
                ++rightIndex;
                if (*ExtentBegin == *ExtentEnd)
                {
                    return;
                }

                spdlog::trace("continuing to search for extent {}u->{}u", *ExtentBegin, *ExtentEnd);
            }
        }
    }
}
