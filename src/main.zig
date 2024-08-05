const std = @import("std");
const cli = @import("zig-cli");

const xp = @import("xfs_parser.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
const allocator = gpa.allocator();

var config = struct {
    device: []const u8 = undefined,
    output: []const u8 = undefined,
}{};

var device: std.fs.File = undefined;

var block_size: u64 = undefined;

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

    _ = gpa.detectLeaks();
}

fn saveInodeEntry(entry: *const xp.inode_entry) !void {
    const max_filename_len: comptime_int = comptime std.fmt.count("{d}", .{@as(u64, std.math.maxInt(u64))});
    var file_name: [max_filename_len:0]u8 = undefined;
    _ = try std.fmt.bufPrintZ(&file_name, "{d}", .{entry.inode_number});

    var dir = try std.fs.cwd().makeOpenPath(config.output, .{});
    const file = try dir.createFileZ(&file_name, .{});
    defer file.close();
    defer dir.close();

    for (entry.extents.items) |extent| {
        std.log.debug("extent={}", .{extent});
        const bytecount = try std.posix.copy_file_range(
            device.handle,
            extent.block_offset * block_size,
            file.handle,
            extent.file_offset,
            extent.block_count * block_size,
            0,
        );
        std.log.debug("copied {d} bytes from {s} to {s}/{s}", .{
            bytecount,
            config.device,
            config.output,
            file_name,
        });
    }
}

fn xfsCallback(entry: *const xp.inode_entry) void {
    var file_size: u64 = 0;
    for (entry.extents.items) |extent| {
        file_size += extent.block_count * block_size;
    }
    std.log.info("inode={d}, file_size={d}", .{ entry.inode_number, file_size });
    saveInodeEntry(entry) catch |err| std.log.warn("erroring during save_file: {}", .{err});
}

fn run() !void {
    std.log.debug("started xfs_undelete, device={s}, output={s}", .{ config.device, config.output });

    device = try std.fs.cwd().openFile(config.device, .{ .mode = .read_only });
    defer device.close();

    var parser = try xp.xfs_parser.init(allocator, config.device);

    block_size = try parser.get_blocksize();

    try parser.dump_inodes(xfsCallback);
}
