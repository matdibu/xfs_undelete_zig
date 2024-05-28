const std = @import("std");

pub const inode_entry = struct {
    const data = "hello world!";
    pub fn get_inode_number(self: *const inode_entry) usize {
        _ = self;
        return 1;
    }
    pub fn get_file_size(self: *const inode_entry) usize {
        _ = self;
        return data.len;
    }
    pub fn get_next_available_offset(self: *const inode_entry, offset: *usize, size: *usize) !void {
        _ = self;
        offset.* = 0;
        size.* = data.len;
    }
    pub fn get_file_content(self: *const inode_entry, buffer: []u8, offset: usize, bytes_to_read: usize, bytes_read: *usize) !void {
        _ = self;
        _ = offset;
        _ = bytes_to_read;
        @memcpy(buffer[0..data.len], data);
        bytes_read.* = data.len;
    }
};
