const std = @import("std");
const fs = std.fs;

fn TransformOp(comptime T: type) type {
    return fn (allocator: *std.mem.Allocator, line: []const u8) anyerror!T;
}

// pub fn transformLines(comptime T: type, allocator: *std.mem.Allocator, path: []const u8, xform: fn (line: []const u8) !T) !std.ArrayList(T) {
pub fn transformLines(comptime T: type, allocator: *std.mem.Allocator, path: []const u8, xform: TransformOp(T)) !std.ArrayList(T) {
    var line_buf: [1024]u8 = undefined;
    var f = try fs.cwd().openFile(path, .{ .read = true, .write = false, .lock = fs.File.Lock.None });
    defer f.close();

    var res = std.ArrayList(T).init(allocator);
    errdefer res.deinit();

    var reader = f.reader();
    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        const el = try xform(allocator, line);
        try res.append(el);
    }

    return res;
}
