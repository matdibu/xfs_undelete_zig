const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut();
    var bw = std.io.bufferedWriter(stdout.writer());
    const w = bw.writer();
    try w.print("hello!", .{});
    try bw.flush();
}
