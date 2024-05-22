#ifndef _XFS_TREE_HPP_
#define _XFS_TREE_HPP_

#include "linux_file.hpp"     // uf::xfs::LinuxFile
#include "xfs_exceptions.hpp" // uf::xfs::ValidationException

#include "xfs_superblock.h" // xfs_superblock_t
#include "xfs_trees.h"      // XFS_BTREE_* xfs_btree_block

#include <fstream>    // std::basic_ifstream
#include <functional> // std::function
#include <vector>     // std::vector

namespace uf::xfs {
    // callback for each record in the tree
    template <typename btree_rec_t>
    using BTreeRecordCallback =
        std::function<void(const xfs_agnumber_t& ag_index, btree_rec_t rec, uint32_t agf_broot)>;

    // main traversal function
    template <typename btree_ptr_t, typename btree_rec_t>
    void BTreeWalk(
        const utils::LinuxFile&          Disk,
        const xfs_superblock_t&          sb,
        xfs_agnumber_t                   ag_index,
        btree_ptr_t                      ptr,
        uint32_t                         magic,
        uint32_t                         agf_broot,
        BTreeRecordCallback<btree_rec_t> callback);

    // get the tree length macro based on ptr size
    template <typename btree_ptr_t>
    constexpr off_t BTreeHeaderSize();

    // This is the format of a standard b+tree node:
    // +--------+---------+---------+---------+---------+
    // | header |   key   | keys... |   ptr   | ptrs... |
    // +--------+---------+---------+---------+---------+
    //
    // iterate through the pointers
    template <typename btree_ptr_t, typename btree_rec_t>
    void BTreeWalkPointers(
        const utils::LinuxFile& Disk,
        const xfs_superblock_t& sb,
        xfs_agnumber_t          ag_index,
        const struct xfs_btree_block& /*block*/,
        off_t                            seek_offset,
        uint32_t                         magic,
        uint32_t                         agf_broot,
        BTreeRecordCallback<btree_rec_t> callback);

    // leaf blocks of both types of b+trees have the same general format:
    // a header describing the data in the block, and an array of records.
    // +--------+------------+------------+
    // | header |   record   | records... |
    // +--------+------------+------------+
    //
    // iterate through the records
    template <typename btree_ptr_t, typename btree_rec_t>
    void BTreeWalkRecords(
        const utils::LinuxFile& Disk,
        const xfs_superblock_t& sb,
        xfs_agnumber_t          ag_index,
        const struct xfs_btree_block& /*block*/,
        off_t                            seek_offset,
        uint32_t                         agf_broot,
        BTreeRecordCallback<btree_rec_t> callback);

} // namespace uf::xfs

template <typename btree_ptr_t>
constexpr off_t uf::xfs::BTreeHeaderSize()
{
    if (sizeof(btree_ptr_t) == 4)
    {
        return XFS_BTREE_SBLOCK_CRC_LEN;
    }
    if (sizeof(btree_ptr_t) == 8)
    {
        return XFS_BTREE_LBLOCK_CRC_LEN;
    }
}

template <typename btree_ptr_t, typename btree_rec_t>
void uf::xfs::BTreeWalkPointers(
    const utils::LinuxFile& Disk,
    const xfs_superblock_t& sb,
    xfs_agnumber_t          ag_index,
    const struct xfs_btree_block& /*block*/,
    off_t                            seek_offset,
    uint32_t                         magic,
    uint32_t                         agf_broot,
    BTreeRecordCallback<btree_rec_t> callback)
{
    std::vector<btree_ptr_t> pointers;
    // pointers.resize(be16toh(block.bb_numrecs));
    pointers.resize((be32toh(sb.sb_blocksize) - BTreeHeaderSize<btree_ptr_t>()) / (sizeof(btree_ptr_t) * 2));

    off_t offset = (BTreeHeaderSize<btree_ptr_t>() + static_cast<off_t>(be32toh(sb.sb_blocksize))) / 2LL;

    Disk.ReadFromOffset(pointers.data(), seek_offset + offset, pointers.size() * sizeof(btree_ptr_t));

    for (const auto& ptr : pointers)
    {
        BTreeWalk<btree_ptr_t, btree_rec_t>(Disk, sb, ag_index, be32toh(ptr), magic, agf_broot, callback);
    }
}

template <typename btree_ptr_t, typename btree_rec_t>
void uf::xfs::BTreeWalkRecords(
    const utils::LinuxFile& Disk,
    const xfs_superblock_t& sb,
    xfs_agnumber_t          ag_index,
    const struct xfs_btree_block& /*block*/,
    off_t                            seek_offset,
    uint32_t                         agf_broot,
    BTreeRecordCallback<btree_rec_t> callback)
{
    // vector of records, of count block.bb_numrecs
    std::vector<btree_rec_t> records;
    // records.resize(be16toh(block.bb_numrecs));
    records.resize((be32toh(sb.sb_blocksize) - BTreeHeaderSize<btree_ptr_t>()) / sizeof(btree_rec_t));

    // read the records into the vector
    Disk.ReadFromOffset(
        records.data(), seek_offset + BTreeHeaderSize<btree_ptr_t>(), records.size() * sizeof(btree_rec_t));

    // some records are duplicated on-disk, nothing we can do
    for (const auto& rec : records)
    {
        callback(ag_index, rec, agf_broot);
    }
}

template <typename btree_ptr_t, typename btree_rec_t>
void uf::xfs::BTreeWalk(
    const utils::LinuxFile&          Disk,
    const xfs_superblock_t&          sb,
    xfs_agnumber_t                   ag_index,
    btree_ptr_t                      ptr,
    uint32_t                         magic,
    uint32_t                         agf_broot,
    BTreeRecordCallback<btree_rec_t> callback)
{
    struct xfs_btree_block block = {};
    off_t                  seek_offset =
        static_cast<off_t>(be32toh(sb.sb_blocksize)) *
        static_cast<off_t>((be32toh(sb.sb_agblocks)) * static_cast<off_t>(ag_index) + static_cast<off_t>(ptr));

    Disk.ReadFromOffset(&block, seek_offset, BTreeHeaderSize<btree_ptr_t>());

    if (magic != be32toh(block.bb_magic))
    {
        throw uf::xfs::ValidationException("btree_block magic");
    }

    if (be32toh(block.bb_level) > 0)
    {
        // this is a node
        // walk the 'pointer' records
        BTreeWalkPointers<btree_ptr_t, btree_rec_t>(Disk, sb, ag_index, block, seek_offset, magic, agf_broot, callback);
    }
    else
    {
        // this is a leaf
        // walk the 'leaf' records
        BTreeWalkRecords<btree_ptr_t, btree_rec_t>(Disk, sb, ag_index, block, seek_offset, agf_broot, callback);
    }
}

#endif // !_XFS_TREE_HPP_
