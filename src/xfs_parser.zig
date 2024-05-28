const std = @import("std");

const xp = @import("./inode_entry.zig");
pub const inode_entry = xp.inode_entry;

const c = @cImport({
    @cDefine("ASSERT", "");
    @cInclude("xfs/xfs.h");
    @cInclude("xfs/xfs_arch.h");
    @cInclude("xfs/xfs_format.h");
});

pub const callback_t = fn (*inode_entry) anyerror!void;

pub const xfs_parser = struct {
    device_path: []const u8,
    device: std.fs.File = undefined,
    superblock: c.xfs_dsb = undefined,

    pub fn read_superblock(self: *xfs_parser) !void {
        self.device = try std.fs.cwd().openFile(self.device_path, .{ .mode = .read_only, .lock = .exclusive });
        _ = try self.device.pread(std.mem.asBytes(&self.superblock), 0);
        if (c.XFS_SB_MAGIC != c.be32toh(self.superblock.sb_magicnum)) {
            return error.Oops;
        }
    }

    pub fn dump_inodes(self: *const xfs_parser, comptime callback: callback_t) !void {
        _ = self;
        var entry: inode_entry = .{};
        return callback(&entry);
    }
};

fn lmao() void {
    const sb: c.xfs_dsb = .{};
    std.log.info("sb_fname={s}", .{sb.sb_fname});
}
