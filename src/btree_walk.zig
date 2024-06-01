const std = @import("std");

pub const inode_entry = @import("./inode_entry.zig").inode_entry;
pub const xfs_inode_t = @import("./xfs_inode.zig").xfs_inode_t;
pub const xfs_extent_t = @import("./xfs_extent.zig").xfs_extent_t;
pub const xfs_parser = @import("./xfs_parser.zig").xfs_parser;
pub const xfs_error = @import("./xfs_error.zig").xfs_error;

const c_patched = @import("./c.zig");
const c = c_patched.c;

pub const callback_t = fn (*inode_entry) void;

pub const btree_walk_err = (std.mem.Allocator.Error || std.fs.File.PReadError || xfs_error);

pub fn treewalk_callback_t(
    comptime btree_rec_t: type,
) type {
    return struct {
        parser: *xfs_parser = undefined,
        callback: *const callback_t,

        pub fn call(
            self: *const treewalk_callback_t(btree_rec_t),
            ag_index: c.xfs_agnumber_t,
            inobt_rec: btree_rec_t,
            agf_root: u32,
        ) void {
            self.parser.inode_btree_callback(ag_index, inobt_rec, agf_root, self.callback);
        }
    };
}

pub fn btree_header_size(comptime btree_ptr_t: type) usize {
    return switch (btree_ptr_t) {
        // TODO(mateidibu): there are other XFS_BTREE_*BLOCK_*LEN macros,
        // check that they are properly covered
        c.xfs_alloc_ptr_t => c_patched.XFS_BTREE_SBLOCK_CRC_LEN,
        else => @compileError("btree_ptr_t does not have a matching XFS_BTREE_*BLOCK_CRC_LEN"),
    };
}

pub fn btree_walk(
    comptime btree_ptr_t: type,
    comptime btree_rec_t: type,
    allocator: std.mem.Allocator,
    device: std.fs.File,
    superblock: *const c.xfs_dsb,
    ag_index: c.xfs_agnumber_t,
    agi_root: btree_ptr_t,
    magic: u32,
    agf_block_number_root: u32,
    cb: treewalk_callback_t(btree_rec_t),
) btree_walk_err!void {
    var block: c.xfs_btree_block = .{};

    const seek_offset: u64 = @as(u64, c.be32toh(superblock.sb_blocksize)) * (@as(u64, c.be32toh(superblock.sb_agblocks)) * @as(u64, ag_index) + @as(u64, agi_root));

    _ = try device.pread(std.mem.asBytes(&block), seek_offset);

    if (magic != c.be32toh(block.bb_magic)) {
        std.log.err("bad btree magic at offset {x}, expected '{s}'/{x}, got '{s}'/{x}", .{
            seek_offset,
            std.mem.asBytes(&magic)[0..4],
            magic,
            std.mem.asBytes(&block.bb_magic)[0..4],
            block.bb_magic,
        });
        return xfs_error.btree_block_magic;
    }

    if (c.be32toh(block.bb_level) > 0) {
        return btree_walk_pointers(btree_ptr_t, btree_rec_t, allocator, device, superblock, ag_index, seek_offset, magic, agf_block_number_root, cb);
    }

    return btree_walk_records(btree_ptr_t, btree_rec_t, allocator, device, superblock, ag_index, seek_offset, agf_block_number_root, cb);
}

fn btree_walk_pointers(
    comptime btree_ptr_t: type,
    comptime btree_rec_t: type,
    allocator: std.mem.Allocator,
    device: std.fs.File,
    superblock: *const c.xfs_dsb,
    ag_index: c.xfs_agnumber_t,
    seek_offset: u64,
    magic: u32,
    agf_block_number_root: u32,
    cb: treewalk_callback_t(btree_rec_t),
) btree_walk_err!void {
    const no_of_pointers = (c.be32toh(superblock.sb_blocksize) - btree_header_size(btree_ptr_t)) / (@sizeOf(btree_ptr_t) * 2);

    // var pointers = try std.ArrayList(btree_ptr_t).initCapacity(allocator, no_of_pointers);
    var pointers = std.ArrayList(btree_ptr_t).init(allocator);
    try pointers.resize(no_of_pointers);
    defer pointers.deinit();

    const offset = (btree_header_size(btree_ptr_t) + c.be32toh(superblock.sb_blocksize)) / 2;

    _ = try device.pread(std.mem.sliceAsBytes(pointers.items), seek_offset + offset);

    for (pointers.items) |pointer| {
        try btree_walk(btree_ptr_t, btree_rec_t, allocator, device, superblock, ag_index, c.be32toh(pointer), magic, agf_block_number_root, cb);
    }
}

fn btree_walk_records(
    comptime btree_ptr_t: type,
    comptime btree_rec_t: type,
    allocator: std.mem.Allocator,
    device: std.fs.File,
    superblock: *const c.xfs_dsb,
    ag_index: c.xfs_agnumber_t,
    seek_offset: u64,
    agf_block_number_root: u32,
    cb: treewalk_callback_t(btree_rec_t),
) btree_walk_err!void {
    const no_of_records = (c.be32toh(superblock.sb_blocksize) - btree_header_size(btree_ptr_t)) / @sizeOf(btree_rec_t);

    // var records = try std.ArrayList(btree_rec_t).initCapacity(allocator, no_of_records);
    var records = std.ArrayList(btree_rec_t).init(allocator);
    try records.resize(no_of_records);
    defer records.deinit();

    _ = try device.pread(std.mem.sliceAsBytes(records.items), seek_offset + btree_header_size(btree_ptr_t));

    // std.log.info("records.items={x}", .{records.items.ptr});
    for (records.items) |record| {
        cb.call(ag_index, record, agf_block_number_root);
    }
}
