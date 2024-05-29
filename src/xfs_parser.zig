const std = @import("std");

pub const inode_entry = @import("./inode_entry.zig").inode_entry;
pub const xfs_inode_t = @import("./xfs_inode.zig").xfs_inode_t;
pub const xfs_extent_t = @import("./xfs_extent.zig").xfs_extent_t;
pub const btree_walk = @import("./btree_walk.zig");

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
};

pub const callback_t = fn (*const inode_entry) anyerror!void;

pub const xfs_parser = struct {
    device_path: []const u8,
    device: std.fs.File = undefined,
    superblock: c.xfs_dsb = undefined,

    pub fn dump_inodes(self: *xfs_parser, callback: *const callback_t) !void {
        try self.read_superblock();

        var ag_free_space_header: c.xfs_agf_t = .{};
        var ag_inode_management_header: c.xfs_agi_t = .{};

        const cb: btree_walk.treewalk_callback_t(c.xfs_inobt_rec_t) = .{ .parser = self, .callback = callback };

        var ag_index: c.xfs_agnumber_t = 0;
        while (ag_index < c.be32toh(self.superblock.sb_agcount)) : (ag_index += 1) {
            var offset = c.be32toh(self.superblock.sb_blocksize) * c.be32toh(self.superblock.sb_agblocks) * ag_index + c.be16toh(self.superblock.sb_sectsize);
            _ = try self.device.pread(std.mem.asBytes(&ag_free_space_header), offset);
            if (c.XFS_AGF_MAGIC != c.be32toh(ag_free_space_header.agf_magicnum)) {
                return xfs_error.agf_magic;
            }

            offset += c.be16toh(self.superblock.sb_sectsize);
            _ = try self.device.pread(std.mem.asBytes(&ag_inode_management_header), offset);
            if (c.XFS_AGI_MAGIC != c.be32toh(ag_inode_management_header.agi_magicnum)) {
                return xfs_error.agi_magic;
            }

            const agf_block_number_root = c.be32toh(ag_free_space_header.agf_roots[c.XFS_BTNUM_BNOi]);
            if (self.has_ro_compat_feature(c.XFS_SB_FEAT_RO_COMPAT_FINOBT)) {
                std.log.info("dumping finobt in ag#{d}", .{ag_index});
                try btree_walk.btree_walk(c.xfs_inobt_ptr_t, c.xfs_inobt_rec_t, self.device, self.superblock, ag_index, c.be32toh(ag_inode_management_header.agi_free_root), c.XFS_FIBT_CRC_MAGIC, agf_block_number_root, cb);
            } else {
                std.log.info("dumping inobt in ag#{d}", .{ag_index});
                try btree_walk.btree_walk(c.xfs_inobt_ptr_t, c.xfs_inobt_rec_t, self.device, self.superblock, ag_index, c.be32toh(ag_inode_management_header.agi_root), c.XFS_IBT_CRC_MAGIC, agf_block_number_root, cb);
            }
        }

        var entry: inode_entry = .{};
        return callback(&entry);
    }

    pub fn inode_btree_callback(self: *const xfs_parser, ag_index: c.xfs_agnumber_t, inobt_rec: c.xfs_inobt_rec_t, agf_root: u32, cb: *const callback_t) !void {
        var current_inode = c.be32toh(inobt_rec.ir_startino);
        const start_inode = current_inode;
        var free_mask = c.be64toh(inobt_rec.ir_free);
        var hole_mask = c.be16toh(inobt_rec.ir_u.sp.ir_holemask);

        while (0 != free_mask) {
            if (self.has_incompat_feature(c.XFS_SB_FEAT_INCOMPAT_SPINODES) and 0 != (hole_mask & 1)) {
                hole_mask >>= 1;
                free_mask >>= 4;
                current_inode += 4;
                continue;
            }
            if (0 != (free_mask & 1)) {
                std.log.info("[{d}] attempting recovery", .{current_inode});

                const inode: xfs_inode_t = try self.read_inode(ag_index, current_inode, agf_root);

                const entry: inode_entry = inode_entry.create(inode);

                try cb(&entry);
            }

            free_mask >>= 1;
            current_inode += 1;
            if (((current_inode - start_inode) % 4) == 0) {
                hole_mask >>= 1;
            }
        }
    }

    fn only_within_agf(self: *const xfs_parser, extent: xfs_extent_t, ag_index: c.xfs_agnumber_t, agf_root: u32, recovered_extents: *std.ArrayList(xfs_extent_t)) !void {
        _ = self;
        _ = extent;
        _ = ag_index;
        _ = agf_root;
        _ = recovered_extents;
    }

    fn read_inode(self: *const xfs_parser, ag_index: c.xfs_agnumber_t, current_inode: u32, agf_root: u32) !xfs_inode_t {
        const full_inode_size: u16 = c.be16toh(self.superblock.sb_inodesize);

        var extent_recovered_from_list = std.ArrayList(xfs_extent_t).init(std.heap.page_allocator);

        var inode_header: c.xfs_dinode = .{};
        const blocks_per_ag: c.xfs_agblock_t = c.be32toh(self.superblock.sb_agblocks);
        const block_size: u32 = c.be32toh(self.superblock.sb_blocksize);

        const ag_offset: u64 = ag_index * blocks_per_ag * block_size;

        const seek_offset = ag_offset + current_inode * full_inode_size;

        _ = try self.device.pread(std.mem.asBytes(&inode_header), seek_offset);

        const number_of_extents = (full_inode_size - @sizeOf(c.xfs_dinode)) / @sizeOf(c.xfs_bmbt_rec_t);
        var packed_extents = try std.ArrayList(c.xfs_bmbt_rec_t).initCapacity(std.heap.page_allocator, number_of_extents);

        _ = try self.device.pread(std.mem.asBytes(&packed_extents), seek_offset + @sizeOf(c.xfs_dinode));

        for (packed_extents.items) |packed_extent| {
            const extent = xfs_extent_t.create(packed_extent);
            if (!extent.is_valid(self.superblock)) {
                continue;
            }
            try self.only_within_agf(extent, ag_index, agf_root, &extent_recovered_from_list);
        }

        var has_0_offset = false;
        for (extent_recovered_from_list.items) |extent| {
            if (extent.get_file_offset() == 0) {
                has_0_offset = true;
            }
        }
        if (!has_0_offset) {
            return xfs_error.no_0_start_offset;
        }

        return xfs_inode_t.create(
            inode_header,
            &extent_recovered_from_list,
        );
    }

    fn read_superblock(self: *xfs_parser) !void {
        self.device = try std.fs.cwd().openFile(self.device_path, .{ .mode = .read_only, .lock = .exclusive });
        _ = try self.device.pread(std.mem.asBytes(&self.superblock), 0);
        if (c.XFS_SB_MAGIC != c.be32toh(self.superblock.sb_magicnum)) {
            return xfs_error.sb_magic;
        }

        try self.check_superblock_flags();
    }

    fn has_version_feature(self: *const xfs_parser, flag: u16) bool {
        return 0 != (flag & c.be16toh(self.superblock.sb_versionnum));
    }

    fn has_version2_feature(self: *const xfs_parser, flag: u32) bool {
        return 0 != (flag & c.be32toh(self.superblock.sb_features2));
    }

    fn has_ro_compat_feature(self: *const xfs_parser, flag: u32) bool {
        return 0 != (flag & c.be32toh(self.superblock.sb_features_ro_compat));
    }

    fn has_incompat_feature(self: *const xfs_parser, flag: u32) bool {
        return 0 != (flag & c.be32toh(self.superblock.sb_features_incompat));
    }

    fn check_superblock_flags(self: *const xfs_parser) !void {
        const sb_version = c.XFS_SB_VERSION_NUMBITS & c.be16toh(self.superblock.sb_versionnum);
        switch (sb_version) {
            c.XFS_SB_VERSION_1, c.XFS_SB_VERSION_2, c.XFS_SB_VERSION_3, c.XFS_SB_VERSION_4, c.XFS_SB_VERSION_5 => std.log.info("sb_version={d}", .{sb_version}),
            else => std.log.err("unknown sb_version={d}", .{sb_version}),
        }

        std.log.info("version_flags:{s}{s}{s}{s}{s}{s}{s}{s}{s}{s}{s}{s}", .{
            if (self.has_version_feature(c.XFS_SB_VERSION_ATTRBIT)) " attr" else "",
            if (self.has_version_feature(c.XFS_SB_VERSION_NLINKBIT)) " nlink" else "",
            if (self.has_version_feature(c.XFS_SB_VERSION_QUOTABIT)) " quota" else "",
            if (self.has_version_feature(c.XFS_SB_VERSION_ALIGNBIT)) " align" else "",
            if (self.has_version_feature(c.XFS_SB_VERSION_DALIGNBIT)) " dalign" else "",
            if (self.has_version_feature(c.XFS_SB_VERSION_SHAREDBIT)) " shared" else "",
            if (self.has_version_feature(c.XFS_SB_VERSION_LOGV2BIT)) " logv2" else "",
            if (self.has_version_feature(c.XFS_SB_VERSION_SECTORBIT)) " sector" else "",
            if (self.has_version_feature(c.XFS_SB_VERSION_EXTFLGBIT)) " extflg" else "",
            if (self.has_version_feature(c.XFS_SB_VERSION_DIRV2BIT)) " dirv2" else "",
            if (self.has_version_feature(c.XFS_SB_VERSION_BORGBIT)) " borg" else "",
            if (self.has_version_feature(c.XFS_SB_VERSION_MOREBITSBIT)) " morebits" else "",
        });

        if (self.has_version_feature(c.XFS_SB_VERSION_MOREBITSBIT)) {
            std.log.info("version2_flags:{s}{s}{s}{s}{s}{s}", .{
                if (self.has_version2_feature(c.XFS_SB_VERSION2_LAZYSBCOUNTBIT)) " lazysbcount" else "",
                if (self.has_version2_feature(c.XFS_SB_VERSION2_ATTR2BIT)) " attr2" else "",
                if (self.has_version2_feature(c.XFS_SB_VERSION2_PARENTBIT)) " parent" else "",
                if (self.has_version2_feature(c.XFS_SB_VERSION2_PROJID32BIT)) " projid32" else "",
                if (self.has_version2_feature(c.XFS_SB_VERSION2_CRCBIT)) " crc" else "",
                if (self.has_version2_feature(c.XFS_SB_VERSION2_FTYPE)) " ftype" else "",
            });
        }

        std.log.info("ro_compat_flags:{s}{s}{s}", .{
            if (self.has_ro_compat_feature(c.XFS_SB_FEAT_RO_COMPAT_FINOBT)) " finobt" else "",
            if (self.has_ro_compat_feature(c.XFS_SB_FEAT_RO_COMPAT_RMAPBT)) " rmapbt" else "",
            if (self.has_ro_compat_feature(c.XFS_SB_FEAT_RO_COMPAT_REFLINK)) " reflink" else "",
        });

        std.log.info("incompat_flags:{s}{s}{s}", .{
            if (self.has_ro_compat_feature(c.XFS_SB_FEAT_INCOMPAT_FTYPE)) " ftype" else "",
            if (self.has_ro_compat_feature(c.XFS_SB_FEAT_INCOMPAT_SPINODES)) " spinodes" else "",
            if (self.has_ro_compat_feature(c.XFS_SB_FEAT_INCOMPAT_META_UUID)) " meta_uuid" else "",
        });
    }
};
