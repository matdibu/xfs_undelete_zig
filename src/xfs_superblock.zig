const std = @import("std");

const c = @import("c.zig").c;
const xfs_error = @import("xfs_error.zig").xfs_error;

pub const VERSION = enum(u16) {
    ATTRBIT = c.XFS_SB_VERSION_ATTRBIT,
    NLINKBIT = c.XFS_SB_VERSION_NLINKBIT,
    QUOTABIT = c.XFS_SB_VERSION_QUOTABIT,
    ALIGNBIT = c.XFS_SB_VERSION_ALIGNBIT,
    DALIGNBIT = c.XFS_SB_VERSION_DALIGNBIT,
    SHAREDBIT = c.XFS_SB_VERSION_SHAREDBIT,
    LOGV2BIT = c.XFS_SB_VERSION_LOGV2BIT,
    SECTORBIT = c.XFS_SB_VERSION_SECTORBIT,
    EXTFLGBIT = c.XFS_SB_VERSION_EXTFLGBIT,
    DIRV2BIT = c.XFS_SB_VERSION_DIRV2BIT,
    BORGBIT = c.XFS_SB_VERSION_BORGBIT,
    MOREBITSBIT = c.XFS_SB_VERSION_MOREBITSBIT,
};

pub const VERSION2 = enum(u16) {
    LAZYSBCOUNTBIT = c.XFS_SB_VERSION2_LAZYSBCOUNTBIT,
    ATTR2BIT = c.XFS_SB_VERSION2_ATTR2BIT,
    PARENTBIT = c.XFS_SB_VERSION2_PARENTBIT,
    PROJID32BIT = c.XFS_SB_VERSION2_PROJID32BIT,
    CRCBIT = c.XFS_SB_VERSION2_CRCBIT,
    FTYPE = c.XFS_SB_VERSION2_FTYPE,
};

pub const FEAT_RO_COMPAT = enum(u16) {
    FINOBT = c.XFS_SB_FEAT_RO_COMPAT_FINOBT,
    RMAPBT = c.XFS_SB_FEAT_RO_COMPAT_RMAPBT,
    REFLINK = c.XFS_SB_FEAT_RO_COMPAT_REFLINK,
};

pub const FEAT_INCOMPAT = enum(u16) {
    FTYPE = c.XFS_SB_FEAT_INCOMPAT_FTYPE,
    SPINODES = c.XFS_SB_FEAT_INCOMPAT_SPINODES,
    META_UUID = c.XFS_SB_FEAT_INCOMPAT_META_UUID,
};

pub const xfs_superblock = struct {
    sb_blocksize: u32 = undefined,
    sb_agblocks: u32 = undefined,
    sb_dblocks: u64 = undefined,
    sb_sectsize: u16 = undefined,
    sb_agcount: u32 = undefined,
    sb_agblklog: u8 = undefined,
    sb_inodesize: u16 = undefined,
    sb_versionnum: u16 = undefined,
    sb_features2: u32 = undefined,
    sb_features_ro_compat: u32 = undefined,
    sb_features_incompat: u32 = undefined,

    pub fn init(dsb: *const c.xfs_dsb) xfs_error!xfs_superblock {
        if (c.XFS_SB_MAGIC != c.be32toh(dsb.sb_magicnum)) {
            return xfs_error.sb_magic;
        }

        return .{
            .sb_blocksize = c.be32toh(dsb.sb_blocksize),
            .sb_agblocks = c.be32toh(dsb.sb_agblocks),
            .sb_dblocks = c.be64toh(dsb.sb_dblocks),
            .sb_sectsize = c.be16toh(dsb.sb_sectsize),
            .sb_agcount = c.be32toh(dsb.sb_agcount),
            .sb_agblklog = dsb.sb_agblklog,
            .sb_inodesize = c.be16toh(dsb.sb_inodesize),
            .sb_versionnum = c.be16toh(dsb.sb_versionnum),
            .sb_features2 = c.be32toh(dsb.sb_features2),
            .sb_features_ro_compat = c.be32toh(dsb.sb_features_ro_compat),
            .sb_features_incompat = c.be32toh(dsb.sb_features_incompat),
        };
    }

    pub fn has_feature(self: *const xfs_superblock, comptime flag: anytype) bool {
        const flag_field = switch (@TypeOf(flag)) {
            VERSION => self.sb_versionnum,
            VERSION2 => self.sb_features2,
            FEAT_INCOMPAT => self.sb_features_incompat,
            FEAT_RO_COMPAT => self.sb_features_ro_compat,
            else => @compileError("unknown type used in xfs_superblock.has_feature"),
        };

        return 0 != (flag_field & @intFromEnum(flag));
    }

    pub fn check_superblock_flags(self: *const xfs_superblock) xfs_error!void {
        const sb_version = c.XFS_SB_VERSION_NUMBITS & self.sb_versionnum;
        switch (sb_version) {
            c.XFS_SB_VERSION_1,
            c.XFS_SB_VERSION_2,
            c.XFS_SB_VERSION_3,
            c.XFS_SB_VERSION_4,
            c.XFS_SB_VERSION_5,
            => std.log.debug("sb_version={d}", .{sb_version}),
            else => {
                std.log.err("unknown sb_version={d}", .{sb_version});
                return xfs_error.sb_version;
            },
        }

        std.log.debug("version_flags:{s}{s}{s}{s}{s}{s}{s}{s}{s}{s}{s}{s}", .{
            if (self.has_feature(VERSION.ATTRBIT)) " attr" else "",
            if (self.has_feature(VERSION.NLINKBIT)) " nlink" else "",
            if (self.has_feature(VERSION.QUOTABIT)) " quota" else "",
            if (self.has_feature(VERSION.ALIGNBIT)) " align" else "",
            if (self.has_feature(VERSION.DALIGNBIT)) " dalign" else "",
            if (self.has_feature(VERSION.SHAREDBIT)) " shared" else "",
            if (self.has_feature(VERSION.LOGV2BIT)) " logv2" else "",
            if (self.has_feature(VERSION.SECTORBIT)) " sector" else "",
            if (self.has_feature(VERSION.EXTFLGBIT)) " extflg" else "",
            if (self.has_feature(VERSION.DIRV2BIT)) " dirv2" else "",
            if (self.has_feature(VERSION.BORGBIT)) " borg" else "",
            if (self.has_feature(VERSION.MOREBITSBIT)) " morebits" else "",
        });

        if (self.has_feature(VERSION.MOREBITSBIT)) {
            std.log.debug("version2_flags:{s}{s}{s}{s}{s}{s}", .{
                if (self.has_feature(VERSION2.LAZYSBCOUNTBIT)) " lazysbcount" else "",
                if (self.has_feature(VERSION2.ATTR2BIT)) " attr2" else "",
                if (self.has_feature(VERSION2.PARENTBIT)) " parent" else "",
                if (self.has_feature(VERSION2.PROJID32BIT)) " projid32" else "",
                if (self.has_feature(VERSION2.CRCBIT)) " crc" else "",
                if (self.has_feature(VERSION2.FTYPE)) " ftype" else "",
            });
        }

        std.log.debug("ro_compat_flags:{s}{s}{s}", .{
            if (self.has_feature(FEAT_RO_COMPAT.FINOBT)) " finobt" else "",
            if (self.has_feature(FEAT_RO_COMPAT.RMAPBT)) " rmapbt" else "",
            if (self.has_feature(FEAT_RO_COMPAT.REFLINK)) " reflink" else "",
        });

        std.log.debug("incompat_flags:{s}{s}{s}", .{
            if (self.has_feature(FEAT_INCOMPAT.FTYPE)) " ftype" else "",
            if (self.has_feature(FEAT_INCOMPAT.SPINODES)) " spinodes" else "",
            if (self.has_feature(FEAT_INCOMPAT.META_UUID)) " meta_uuid" else "",
        });
    }
};
