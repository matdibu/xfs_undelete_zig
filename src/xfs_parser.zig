const std = @import("std");

pub const inode_entry = @import("inode_entry.zig").inode_entry;
pub const xfs_inode_t = @import("xfs_inode.zig").xfs_inode_t;
pub const xfs_inode_err = @import("xfs_inode.zig").xfs_inode_err;
pub const xfs_extent_t = @import("xfs_extent.zig").xfs_extent_t;
pub const xfs_error = @import("xfs_error.zig").xfs_error;
pub const xfs_superblock = @import("xfs_superblock.zig").xfs_superblock;
pub const xfs_sb_enums = @import("xfs_superblock.zig");

const c = @import("c.zig").c;
const c_patched = @import("c.zig");

pub const btree_walk_err = (std.mem.Allocator.Error || std.fs.File.PReadError || xfs_error);

pub const callback_t = fn (*inode_entry) void;

pub const xfs_parser = struct {
    allocator: std.mem.Allocator,
    device_path: []const u8 = undefined,
    device: std.fs.File = undefined,
    superblock: xfs_superblock = undefined,

    pub fn init(allocator: std.mem.Allocator) xfs_parser {
        return .{
            .allocator = allocator,
        };
    }

    pub fn dump_inodes(self: *xfs_parser, callback: *const callback_t) !void {
        try self.read_superblock();

        var ag_free_space_header: c.xfs_agf_t = undefined;
        var ag_inode_management_header: c.xfs_agi_t = undefined;

        var ag_index: c.xfs_agnumber_t = 0;
        while (ag_index < self.superblock.sb_agcount) : (ag_index += 1) {
            // read ag_free_space_header
            const ag_fsh_offset: u64 = self.superblock.sb_blocksize * self.superblock.sb_agblocks * ag_index + self.superblock.sb_sectsize;
            _ = try self.device.pread(std.mem.asBytes(&ag_free_space_header), ag_fsh_offset);
            if (c.XFS_AGF_MAGIC != c.be32toh(ag_free_space_header.agf_magicnum)) {
                return xfs_error.agf_magic;
            }

            // read ag_inode_management_header
            const ag_imh_offset = ag_fsh_offset + self.superblock.sb_sectsize;
            _ = try self.device.pread(std.mem.asBytes(&ag_inode_management_header), ag_imh_offset);
            if (c.XFS_AGI_MAGIC != c.be32toh(ag_inode_management_header.agi_magicnum)) {
                return xfs_error.agi_magic;
            }

            const agf_block_number_root: u32 = c.be32toh(ag_free_space_header.agf_roots[c.XFS_BTNUM_BNOi]);

            if (self.superblock.has_feature(xfs_sb_enums.FEAT_RO_COMPAT.FINOBT)) {
                std.log.info("dumping finobt in ag#{d}", .{ag_index});
                try self.btree_walk(
                    c.xfs_inobt_ptr_t,
                    c.xfs_inobt_rec_t,
                    self.allocator,
                    self.device,
                    &self.superblock,
                    ag_index,
                    c.be32toh(ag_inode_management_header.agi_free_root),
                    c.XFS_FIBT_CRC_MAGIC,
                    agf_block_number_root,
                    callback,
                );
            } else {
                std.log.info("dumping inobt in ag#{d}", .{ag_index});
                try self.btree_walk(
                    c.xfs_inobt_ptr_t,
                    c.xfs_inobt_rec_t,
                    self.allocator,
                    self.device,
                    &self.superblock,
                    ag_index,
                    c.be32toh(ag_inode_management_header.agi_root),
                    c.XFS_IBT_CRC_MAGIC,
                    agf_block_number_root,
                    callback,
                );
            }
        }
    }

    fn inode_btree_callback(
        self: *xfs_parser,
        ag_index: c.xfs_agnumber_t,
        inobt_rec: c.xfs_inobt_rec_t,
        agf_root: u32,
        cb: *const callback_t,
    ) void {
        const start_inode: u32 = c.be32toh(inobt_rec.ir_startino);
        var current_inode = start_inode;

        var free_mask: u64 = c.be64toh(inobt_rec.ir_free);
        var hole_mask: u16 = c.be16toh(inobt_rec.ir_u.sp.ir_holemask);

        while (0 != free_mask) {
            if (self.superblock.has_feature(xfs_sb_enums.FEAT_INCOMPAT.SPINODES) and 0 != (hole_mask & 1)) {
                std.log.info("[{d}] spare inode hole", .{current_inode});
                hole_mask >>= 1;
                free_mask >>= 4;
                current_inode += 4;
                continue;
            }
            if (0 != (free_mask & 1)) {
                if (self.read_inode(ag_index, current_inode, agf_root)) |inode| {
                    defer inode.deinit();
                    var entry: inode_entry = inode_entry.init(
                        &self.device,
                        // &self.superblock,
                        inode.inode,
                        self.superblock.sb_blocksize,
                        inode.extents,
                    );

                    cb(&entry);
                } else |err| switch (err) {
                    xfs_inode_err.bad_magic,
                    xfs_inode_err.non_zero_mode,
                    xfs_inode_err.non_zero_nlink,
                    xfs_inode_err.version_not_3,
                    xfs_inode_err.format_is_not_extents,
                    xfs_error.no_0_start_offset,
                    => std.log.debug("skipping inode #{}, reason: {}", .{ current_inode, err }),
                    else => unreachable,
                }
            }

            free_mask >>= 1;
            current_inode += 1;
            if (((current_inode - start_inode) % 4) == 0) {
                hole_mask >>= 1;
            }
        }
    }

    fn only_within_agf(
        self: *const xfs_parser,
        extent: *const xfs_extent_t,
        ag_index: c.xfs_agnumber_t,
        agf_root: u32,
        recovered_extents: *std.ArrayList(xfs_extent_t),
    ) !void {
        const ag_offset = ag_index * self.superblock.sb_agblocks * self.superblock.sb_blocksize;
        var agf_header: c.xfs_agf_t = undefined;
        _ = try self.device.pread(
            std.mem.asBytes(&agf_header),
            ag_offset + self.superblock.sb_sectsize,
        );

        const relative_extent = xfs_extent_t{
            .file_offset = extent.file_offset,
            .block_offset = extent.block_offset - ag_offset / self.superblock.sb_blocksize,
            .block_count = extent.block_count,
            .state = extent.state,
        };

        const agf_length = c.be32toh(agf_header.agf_length);
        if (relative_extent.block_offset > agf_length) {
            std.log.debug("extent's block_offset={} is beyond the Allocation Group length={}", .{
                relative_extent.block_offset,
                agf_length,
            });
            return;
        }

        const block_offset = ag_offset + agf_root * self.superblock.sb_blocksize;

        var extent_begin = relative_extent.block_offset;
        const extent_end = extent_begin + relative_extent.block_count;

        return self.tree_check(extent, ag_offset, block_offset, &extent_begin, extent_end, recovered_extents);
    }

    fn tree_check_leaf(
        self: *const xfs_parser,
        extent: *const xfs_extent_t,
        number_of_records: u16,
        ag_offset: u64,
        block_offset: u64,
        extent_begin: *u64,
        extent_end: u64,
        recovered_extents: *std.ArrayList(xfs_extent_t),
    ) btree_walk_err!void {
        var keys = std.ArrayList(c.xfs_alloc_key_t).init(self.allocator);
        defer keys.deinit();

        var ptrs = std.ArrayList(c.xfs_alloc_ptr_t).init(self.allocator);
        defer ptrs.deinit();

        try keys.resize(number_of_records);
        try ptrs.resize(number_of_records);

        const max_records_bytes = self.superblock.sb_blocksize - btree_header_size(c.xfs_alloc_ptr_t);
        const sizeof_record = @sizeOf(c.xfs_alloc_key_t) + @sizeOf(c.xfs_alloc_ptr_t);
        const max_no_of_records = max_records_bytes / sizeof_record;

        _ = try self.device.pread(
            std.mem.sliceAsBytes(keys.items),
            block_offset + btree_header_size(c.xfs_alloc_ptr_t),
        );

        const ptrs_offset = btree_header_size(c.xfs_alloc_ptr_t) + max_no_of_records * @sizeOf(c.xfs_alloc_key_t);
        _ = try self.device.pread(
            std.mem.sliceAsBytes(ptrs.items),
            block_offset + ptrs_offset,
        );

        var left: u16 = 0;
        var right: u16 = number_of_records - 1;
        var middle: u16 = 0;

        while (left <= right) {
            middle = (left + right) / 2;
            if (extent_begin.* > c.be32toh(keys.items[middle].ar_startblock)) {
                left = middle + 1;
            } else if (extent_end < c.be32toh(keys.items[middle].ar_startblock)) {
                right = middle - 1;
            } else {
                right = middle;
                break;
            }
        }

        const ptr = c.be32toh(ptrs.items[right]);
        const seek_offset = ag_offset + ptr * self.superblock.sb_blocksize;
        return self.tree_check(
            extent,
            ag_offset,
            seek_offset,
            extent_begin,
            extent_end,
            recovered_extents,
        );
    }

    fn tree_check_recs(
        self: *const xfs_parser,
        extent: *const xfs_extent_t,
        number_of_records: u16,
        block_offset: u64,
        extent_begin: *u64,
        extent_end: u64,
        recovered_extents: *std.ArrayList(xfs_extent_t),
    ) !void {
        var records = std.ArrayList(c.xfs_alloc_rec_t).init(self.allocator);
        defer records.deinit();
        try records.resize(number_of_records);

        _ = try self.device.pread(
            std.mem.sliceAsBytes(records.items),
            block_offset + btree_header_size(c.xfs_alloc_ptr_t),
        );

        var left_index: usize = 0;
        var right_index: usize = number_of_records - 1;
        var middle_index: usize = 0;

        while (left_index <= right_index) {
            middle_index = @divFloor(left_index + right_index, 2);

            const record_begin: u32 = c.be32toh(records.items[middle_index].ar_startblock);
            const record_end: u32 = record_begin + c.be32toh(records.items[middle_index].ar_blockcount);

            if (extent_begin.* > record_end) {
                left_index = middle_index + 1;
            } else if (extent_end < record_begin) {
                right_index = middle_index - 1;
            } else {
                std.log.debug("found overlapping extent {d}->{d}", .{ record_begin, record_end });

                const target_begin = @max(record_begin, extent_begin.*);
                const target_end = @min(record_end, extent_end);

                if (target_end == target_begin) {
                    return;
                }

                std.log.debug("adding result of overlap ({d}->{d}) to valid extents", .{ target_begin, target_end });

                const to_be_added: xfs_extent_t = .{
                    .file_offset = extent.file_offset + target_begin - extent_begin.*,
                    .block_offset = target_begin,
                    .block_count = target_end - target_begin,
                    .state = 0,
                };

                try recovered_extents.append(to_be_added);

                extent_begin.* = target_end;
                right_index += 1;

                if (extent_begin.* == extent_end) {
                    return;
                }

                std.log.debug("continuing to search for extent {d}->{d}", .{ extent_begin.*, extent_end });
            }
        }
    }

    fn tree_check(
        self: *const xfs_parser,
        extent: *const xfs_extent_t,
        ag_offset: u64,
        block_offset: u64,
        extent_begin: *u64,
        extent_end: u64,
        recovered_extents: *std.ArrayList(xfs_extent_t),
    ) !void {
        var btree_block: c.xfs_btree_block = undefined;
        _ = try self.device.pread(std.mem.asBytes(&btree_block), block_offset);

        const number_of_records = c.be16toh(btree_block.bb_numrecs);
        if (c.be16toh(btree_block.bb_level) > 0) {
            return self.tree_check_leaf(
                extent,
                number_of_records,
                ag_offset,
                block_offset,
                extent_begin,
                extent_end,
                recovered_extents,
            );
        } else {
            return self.tree_check_recs(
                extent,
                number_of_records,
                block_offset,
                extent_begin,
                extent_end,
                recovered_extents,
            );
        }
    }

    fn read_inode(self: *const xfs_parser, ag_index: c.xfs_agnumber_t, current_inode: u32, agf_root: u32) !xfs_inode_t {
        const full_inode_size: u16 = self.superblock.sb_inodesize;

        var extent_recovered_from_list = std.ArrayList(xfs_extent_t).init(self.allocator);
        errdefer extent_recovered_from_list.deinit();

        var inode_header: c.xfs_dinode = undefined;

        const ag_offset: u64 = ag_index * self.superblock.sb_agblocks * self.superblock.sb_blocksize;

        const seek_offset: u64 = @as(u64, ag_offset) + @as(u64, current_inode) * @as(u64, full_inode_size);

        _ = try self.device.pread(std.mem.asBytes(&inode_header), seek_offset);

        const number_of_extents = (full_inode_size - @sizeOf(c.xfs_dinode)) / @sizeOf(c.xfs_bmbt_rec_t);
        var packed_extents = std.ArrayList(c.xfs_bmbt_rec_t).init(self.allocator);
        defer packed_extents.deinit();
        try packed_extents.resize(number_of_extents);
        _ = try self.device.pread(
            std.mem.sliceAsBytes(packed_extents.items),
            seek_offset + @sizeOf(c.xfs_dinode),
        );

        for (packed_extents.items) |packed_extent| {
            const extent = xfs_extent_t.create(&packed_extent);
            if (!extent.is_valid(&self.superblock)) {
                continue;
            }
            try self.only_within_agf(&extent, ag_index, agf_root, &extent_recovered_from_list);
        }

        var has_0_offset = false;
        for (extent_recovered_from_list.items) |extent| {
            if (extent.file_offset == 0) {
                has_0_offset = true;
            }
        }
        if (!has_0_offset) {
            return xfs_error.no_0_start_offset;
        }

        return xfs_inode_t.create(
            &inode_header,
            extent_recovered_from_list,
        );
    }

    fn read_superblock(self: *xfs_parser) !void {
        self.device = try std.fs.cwd().openFile(self.device_path, .{ .mode = .read_only, .lock = .exclusive });

        var dsb: c.xfs_dsb = undefined;
        _ = try self.device.pread(std.mem.asBytes(&dsb), 0);

        self.superblock = try xfs_superblock.init(&dsb);

        try self.superblock.check_superblock_flags();

        std.log.debug("sb_blocksize={}, sb_agblocks={}, sb_sectsize={}", .{
            self.superblock.sb_blocksize,
            self.superblock.sb_agblocks,
            self.superblock.sb_sectsize,
        });
    }

    fn btree_header_size(comptime btree_ptr_t: type) usize {
        return switch (btree_ptr_t) {
            // TODO(mateidibu): there are other XFS_BTREE_*BLOCK_*LEN macros,
            // check that they are properly covered
            c.xfs_alloc_ptr_t => c_patched.XFS_BTREE_SBLOCK_CRC_LEN,
            else => @compileError("btree_ptr_t does not have a matching XFS_BTREE_*BLOCK_CRC_LEN"),
        };
    }

    fn btree_walk(
        self: *xfs_parser,
        comptime btree_ptr_t: type,
        comptime btree_rec_t: type,
        allocator: std.mem.Allocator,
        device: std.fs.File,
        superblock: *const xfs_superblock,
        ag_index: c.xfs_agnumber_t,
        agi_root: btree_ptr_t,
        magic: u32,
        agf_block_number_root: u32,
        cb: *const callback_t,
    ) btree_walk_err!void {
        var block: c.xfs_btree_block = undefined;

        const seek_offset: u64 = self.superblock.sb_blocksize * (self.superblock.sb_agblocks * ag_index + agi_root);

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
            return self.btree_walk_pointers(
                btree_ptr_t,
                btree_rec_t,
                allocator,
                device,
                superblock,
                ag_index,
                seek_offset,
                magic,
                agf_block_number_root,
                cb,
            );
        }

        return self.btree_walk_records(
            btree_ptr_t,
            btree_rec_t,
            allocator,
            device,
            ag_index,
            seek_offset,
            agf_block_number_root,
            cb,
        );
    }

    fn btree_walk_pointers(
        self: *xfs_parser,
        comptime btree_ptr_t: type,
        comptime btree_rec_t: type,
        allocator: std.mem.Allocator,
        device: std.fs.File,
        superblock: *const xfs_superblock,
        ag_index: c.xfs_agnumber_t,
        seek_offset: u64,
        magic: u32,
        agf_block_number_root: u32,
        cb: *const callback_t,
    ) btree_walk_err!void {
        const no_of_pointers = (self.superblock.sb_blocksize - btree_header_size(btree_ptr_t)) / (@sizeOf(btree_ptr_t) * 2);

        var pointers = std.ArrayList(btree_ptr_t).init(allocator);
        defer pointers.deinit();

        const offset = seek_offset + (btree_header_size(btree_ptr_t) + self.superblock.sb_blocksize) / 2;

        try pointers.resize(no_of_pointers);
        _ = try device.pread(std.mem.sliceAsBytes(pointers.items), offset);

        for (pointers.items) |pointer| {
            try self.btree_walk(
                btree_ptr_t,
                btree_rec_t,
                allocator,
                device,
                superblock,
                ag_index,
                c.be32toh(pointer),
                magic,
                agf_block_number_root,
                cb,
            );
        }
    }

    fn btree_walk_records(
        self: *xfs_parser,
        comptime btree_ptr_t: type,
        comptime btree_rec_t: type,
        allocator: std.mem.Allocator,
        device: std.fs.File,
        ag_index: c.xfs_agnumber_t,
        seek_offset: u64,
        agf_block_number_root: u32,
        cb: *const callback_t,
    ) btree_walk_err!void {
        const no_of_records = (self.superblock.sb_blocksize - btree_header_size(btree_ptr_t)) / @sizeOf(btree_rec_t);

        var records = std.ArrayList(btree_rec_t).init(allocator);
        defer records.deinit();

        try records.resize(no_of_records);
        _ = try device.pread(
            std.mem.sliceAsBytes(records.items),
            seek_offset + btree_header_size(btree_ptr_t),
        );

        for (records.items) |record| {
            self.inode_btree_callback(ag_index, record, agf_block_number_root, cb);
        }
    }
};
