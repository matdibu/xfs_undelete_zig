const std = @import("std");

const xp = @import("./inode_entry.zig");
pub const inode_entry = xp.inode_entry;

const c = @cImport({
    @cDefine("ASSERT", "");
    @cInclude("xfs/xfs.h");
    @cInclude("xfs/xfs_arch.h");
    @cInclude("xfs/xfs_format.h");
});

const xfs_error = error{
    sb_magic,
    agf_magic,
    agi_magic,
};

pub const callback_t = fn (*inode_entry) anyerror!void;

const treewalk_callback_t = struct {
    parser: *const xfs_parser = undefined,
    callback: *const callback_t = undefined,

    pub fn call(self: *treewalk_callback_t, ag_index: c.xfs_agnumber_t, inobt_rec: c.xfs_inobt_rec_t, agf_root: u32) void {
        return self.parser.inode_btree_callback(ag_index, inobt_rec, agf_root, self.callback);
    }
};

pub fn btree_walk(device: std.fs.File, superblock: c.xfs_dsb, ag_index: c.xfs_agnumber_t, agi_root: u32, magic: u32, agf_block_number_root: u32, cb: treewalk_callback_t) !void {
    _ = device;
    _ = superblock;
    _ = ag_index;
    _ = agi_root;
    _ = magic;
    _ = agf_block_number_root;
    _ = cb;
}

pub const xfs_parser = struct {
    device_path: []const u8,
    device: std.fs.File = undefined,
    superblock: c.xfs_dsb = undefined,

    pub fn dump_inodes(self: *xfs_parser, comptime callback: callback_t) !void {
        try self.read_superblock();

        var ag_free_space_header: c.xfs_agf_t = .{};
        var ag_inode_management_header: c.xfs_agi_t = .{};

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
            var cb: treewalk_callback_t = .{ .parser = self, .callback = callback };
            cb.parser = self;
            if (self.has_ro_compat_feature(c.XFS_SB_FEAT_RO_COMPAT_FINOBT)) {
                std.log.info("dumping finobt in ag#{d}", .{ag_index});
                try btree_walk(self.device, self.superblock, ag_index, c.be32toh(ag_inode_management_header.agi_free_root), c.XFS_FIBT_CRC_MAGIC, agf_block_number_root, cb);
            } else {
                std.log.info("dumping inobt in ag#{d}", .{ag_index});
                try btree_walk(self.device, self.superblock, ag_index, c.be32toh(ag_inode_management_header.agi_root), c.XFS_IBT_CRC_MAGIC, agf_block_number_root, cb);
            }
        }

        var entry: inode_entry = .{};
        return callback(&entry);
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
