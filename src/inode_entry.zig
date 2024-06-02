const std = @import("std");

const c = @import("c.zig").c;

const xfs_inode_t = @import("xfs_inode.zig").xfs_inode_t;
const xfs_extent_t = @import("xfs_extent.zig").xfs_extent_t;

pub const inode_entry = struct {
    device: *std.fs.File,
    inode_number: u64,
    block_size: u32,
    extents: std.ArrayList(xfs_extent_t),
    iterator: usize,

    pub fn init(
        device: *std.fs.File,
        inode_number: u64,
        block_size: u32,
        extents: std.ArrayList(xfs_extent_t),
    ) inode_entry {
        return inode_entry{
            .device = device,
            .inode_number = inode_number,
            .block_size = block_size,
            .extents = extents,
            .iterator = 0,
        };
    }

    pub fn get_file_size(self: *const inode_entry) usize {
        var result: u64 = 0;
        for (self.extents.items) |extent| {
            result += extent.block_count * self.block_size;
        }
        return result;
    }

    pub fn get_file_content(self: *const inode_entry, buffer: []u8, offset: usize, bytes_to_read: usize, bytes_read: *usize) !void {
        bytes_read.* = 0;
        var bytes_left = bytes_to_read;
        var current_offset = offset;

        for (self.extents.items) |extent| {
            const end_file_offset: u64 = extent.file_offset + extent.block_count * self.block_size;
            if (current_offset >= extent.file_offset and current_offset <= end_file_offset) {
                const start_in_bytes = extent.block_offset * self.block_size;
                const target_offset = start_in_bytes + current_offset - extent.file_offset;
                const target_size = @min(bytes_left, end_file_offset - current_offset);
                _ = try self.device.pread(buffer[0..bytes_to_read], target_offset);
                bytes_read.* += target_size;
                current_offset += target_size;
                bytes_left -= target_size;
                if (bytes_left == 0) {
                    return;
                }
            }
        }
    }
};
