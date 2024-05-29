const std = @import("std");
const cli = @import("zig-cli");

const xp = @import("./xfs_parser.zig");

const allocator = std.heap.page_allocator;

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

    return r.run(&app);
}

fn save_file(entry: *const xp.inode_entry) !void {
    var file_name: [std.mem.page_size:0]u8 = undefined;
    _ = try std.fmt.bufPrintZ(&file_name, "{s}/{d}", .{ config.output, entry.get_inode_number() });

    std.log.info("starting to undelete file '{s}'", .{file_name});

    var bytes_left: usize = entry.get_file_size();

    const file = try std.fs.cwd().createFileZ(&file_name, .{});
    defer file.close();

    var offset: usize = undefined;
    var size: usize = undefined;
    var bytes_read: usize = undefined;
    var bytes_to_read: usize = undefined;
    var buffer: [std.mem.page_size]u8 = undefined;

    while (bytes_left != 0) {
        try entry.get_next_available_offset(&offset, &size);
        bytes_read = 0;
        std.log.info("buffer len is {d}", .{buffer.len});
        bytes_to_read = @min(size, buffer.len);
        while (bytes_to_read != 0) {
            try entry.get_file_content(&buffer, offset, bytes_to_read, &bytes_read);
            std.log.info("bytes_left={d}, size={d}, bytes_to_read={d}, bytes_read={d}", .{ bytes_left, size, bytes_to_read, bytes_read });
            bytes_left -= bytes_read;
            size -= bytes_read;
            bytes_to_read = @min(size, buffer.len);
            _ = try file.pwrite(buffer[0..bytes_read], offset);
            std.log.info("wrote {d} bytes at offset {d}", .{ bytes_read, offset });
        }
    }
}

fn xfs_callback(entry: *const xp.inode_entry) !void {
    std.log.info("inode={d}, file_size={d}", .{ entry.get_inode_number(), entry.get_file_size() });
    try save_file(entry);
}

fn run() !void {
    std.log.debug("started xfs_undelete, device={s}, output={s}", .{ config.device, config.output });

    var output_dir = try std.fs.cwd().makeOpenPath(config.output, .{});
    defer output_dir.close();

    var parser: xp.xfs_parser = .{ .device_path = config.device };
    try parser.dump_inodes(&xfs_callback);
}
