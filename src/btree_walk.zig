const std = @import("std");

pub const inode_entry = @import("./inode_entry.zig").inode_entry;
pub const xfs_inode_t = @import("./xfs_inode.zig").xfs_inode_t;
pub const xfs_extent_t = @import("./xfs_extent.zig").xfs_extent_t;
pub const xfs_parser = @import("./xfs_parser.zig").xfs_parser;

const c = @cImport({
    @cDefine("ASSERT", "");
    @cInclude("stddef.h");
    @cInclude("xfs/xfs.h");
    @cInclude("xfs/xfs_arch.h");
    @cInclude("xfs/xfs_format.h");
});

const xfs_error = error{
    sb_magic,
    agf_magic,
    agi_magic,
    no_0_start_offset,
    btree_block_magic,
};

pub const callback_t = fn (*const inode_entry) anyerror!void;

pub fn treewalk_callback_t(
    comptime btree_rec_t: type,
) type {
    return struct {
        parser: *const xfs_parser = undefined,
        callback: *const callback_t,

        pub fn call(
            self: *const treewalk_callback_t(btree_rec_t),
            ag_index: c.xfs_agnumber_t,
            inobt_rec: btree_rec_t,
            agf_root: u32,
        ) !void {
            return self.parser.inode_btree_callback(ag_index, inobt_rec, agf_root, self.callback);
        }
    };
}

fn btree_header_size(comptime btree_ptr_t: type) usize {
    return switch (@sizeOf(btree_ptr_t)) {
        4 => c.XFS_BTREE_SBLOCK_CRC_LEN,
        8 => c.XFS_BTREE_LBLOCK_CRC_LEN,
        else => @compileError("btree_ptr_t does not have a matching XFS_BTREE_*BLOCK_CRC_LEN"),
    };
}

pub fn btree_walk(
    comptime btree_ptr_t: type,
    comptime btree_rec_t: type,
    device: std.fs.File,
    superblock: c.xfs_dsb,
    ag_index: c.xfs_agnumber_t,
    agi_root: u32,
    magic: u32,
    agf_block_number_root: u32,
    cb: treewalk_callback_t(btree_rec_t),
) !void {
    var block: c.xfs_btree_block = .{};

    const seek_offset = c.be32toh(superblock.sb_blocksize) * c.be32toh(superblock.sb_agblocks) * ag_index + agi_root;

    _ = try device.pread(std.mem.asBytes(&block), seek_offset);

    if (magic != c.be32toh(block.bb_magic)) {
        return xfs_error.btree_block_magic;
    }

    if (c.be32toh(block.bb_level) > 0) {
        return btree_walk_pointers(btree_ptr_t, btree_rec_t, device, superblock, ag_index, block, seek_offset, magic, agf_block_number_root, cb);
    }

    return btree_walk_records(btree_ptr_t, btree_rec_t, device, superblock, ag_index, block, seek_offset, agf_block_number_root, cb);
}

fn btree_walk_pointers(
    comptime btree_ptr_t: type,
    comptime btree_rec_t: type,
    device: std.fs.File,
    superblock: c.xfs_dsb,
    ag_index: c.xfs_agnumber_t,
    block: c.xfs_btree_block,
    seek_offset: u32,
    magic: u32,
    agf_block_number_root: u32,
    cb: treewalk_callback_t(btree_rec_t),
) !void {
    _ = block;

    const no_of_pointers = (c.be32toh(superblock.sb_blocksize) - btree_header_size(btree_ptr_t)) / (@sizeOf(btree_ptr_t) * 2);

    var pointers = try std.ArrayList(btree_ptr_t).initCapacity(std.heap.page_allocator, no_of_pointers);

    const offset = (btree_header_size(btree_ptr_t) + c.be32toh(superblock.sb_blocksize)) / 2;

    _ = try device.pread(std.mem.asBytes(&pointers), seek_offset + offset);

    for (pointers.items) |pointer| {
        try btree_walk(btree_ptr_t, btree_rec_t, device, superblock, ag_index, c.be32toh(pointer), magic, agf_block_number_root, cb);
    }
}

fn btree_walk_records(
    comptime btree_ptr_t: type,
    comptime btree_rec_t: type,
    device: std.fs.File,
    superblock: c.xfs_dsb,
    ag_index: c.xfs_agnumber_t,
    block: c.xfs_btree_block,
    seek_offset: u32,
    agf_block_number_root: u32,
    cb: treewalk_callback_t(btree_rec_t),
) !void {
    _ = block;

    const no_of_records = (c.be32toh(superblock.sb_blocksize) - btree_header_size(btree_ptr_t)) / @sizeOf(btree_rec_t);

    var records = try std.ArrayList(btree_rec_t).initCapacity(std.heap.page_allocator, no_of_records);

    _ = try device.pread(std.mem.asBytes(&records), seek_offset + btree_header_size(btree_ptr_t));

    for (records.items) |record| {
        try cb.call(ag_index, record, agf_block_number_root);
    }
}
