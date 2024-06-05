const std = @import("std");
const cli = @import("zig-cli");

const xp = @import("xfs_parser.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
const allocator = gpa.allocator();

var config = struct {
    device: []const u8 = undefined,
    output: []const u8 = undefined,
}{};

pub fn main() !void {
    var r = try cli.AppRunner.init(allocator);

    const app = cli.App{
        .command = cli.Command{
            .name = "xfs_undelete",
            .options = &.{
                .{
                    .long_name = "device",
                    .short_alias = 'd',
                    .help = "block device of the target XFS filesystem",
                    .required = true,
                    .value_ref = r.mkRef(&config.device),
                },
                .{
                    .long_name = "output",
                    .short_alias = 'o',
                    .help = "output directory",
                    .required = true,
                    .value_ref = r.mkRef(&config.output),
                },
            },
            .target = cli.CommandTarget{
                .action = cli.CommandAction{ .exec = run },
            },
        },
    };

    try r.run(&app);

    std.log.debug("allocator leaks? {}", .{gpa.detectLeaks()});
}

fn saveInodeEntry(entry: *const xp.inode_entry) !void {
    const max_filename_len: comptime_int = comptime std.fmt.count("{d}", .{@as(u64, std.math.maxInt(u64))});
    var file_name: [max_filename_len:0]u8 = undefined;
    _ = try std.fmt.bufPrintZ(&file_name, "{d}", .{entry.inode_number});

    var bytes_left: usize = entry.get_file_size();

    var dir = try std.fs.cwd().openDir(config.output, .{});
    const file = try dir.createFileZ(&file_name, .{});
    defer file.close();
    defer dir.close();

    var offset: usize = undefined;
    var size: usize = undefined;
    var bytes_read: usize = undefined;
    var bytes_to_read: usize = undefined;
    var buffer: [std.mem.page_size]u8 = undefined;

    for (entry.extents.items) |extent| {
        offset = extent.block_offset;
        size = extent.block_count;
        bytes_read = 0;
        bytes_to_read = @min(size, buffer.len);
        while (bytes_to_read != 0) {
            try entry.get_file_content(&buffer, offset, bytes_to_read, &bytes_read);
            bytes_left -= bytes_read;
            size -= bytes_read;
            bytes_to_read = @min(size, buffer.len);
            _ = try file.pwrite(buffer[0..bytes_read], offset);
        }
    }
}

fn xfsCallback(entry: *const xp.inode_entry) void {
    std.log.info("inode={d}, file_size={d}", .{ entry.inode_number, entry.get_file_size() });
    saveInodeEntry(entry) catch |err| std.log.warn("erroring during save_file: {}", .{err});
}

fn run() !void {
    std.log.debug("started xfs_undelete, device={s}, output={s}", .{ config.device, config.output });

    var parser = xp.xfs_parser.init(allocator, config.device);
    try parser.dump_inodes(xfsCallback);
}
