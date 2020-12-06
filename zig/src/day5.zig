const std = @import("std");
const fs = std.fs;
const expect = std.testing.expect;
const utils = @import("./utils.zig");
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;

fn readFile(allocator: *std.mem.Allocator, path: []const u8) ![]const u8 {
    var line_buf: [2048]u8 = undefined;
    var f = try fs.cwd().openFile(path, .{ .read = true, .write = false, .lock = fs.File.Lock.None });
    defer f.close();
    const st = try f.stat();

    return try f.reader().readAllAlloc(allocator, st.size);
}

const Error = error{ InvalidSymbol, AmbiguousResult };

fn getRow(inp: []const u8) !u64 {
    var min: u8 = 0;
    var max: u8 = 127;
    for (inp) |item, i| {
        if (item == 'F') {
            max -= (max - min + 1) / 2;
        } else if (item == 'B') {
            min += (max - min + 1) / 2;
        } else {
            return Error.InvalidSymbol;
        }
    }

    if (max != min) {
        return Error.AmbiguousResult;
    }
    return max;
}

fn getColumn(inp: []const u8) !u64 {
    var min: u8 = 0;
    var max: u8 = 7;
    for (inp) |item, i| {
        if (item == 'L') {
            max -= (max - min + 1) / 2;
        } else if (item == 'R') {
            min += (max - min + 1) / 2;
        } else {
            return Error.InvalidSymbol;
        }
    }
    if (max != min) {
        return Error.AmbiguousResult;
    }
    return max;
}

fn getId(inp: []const u8) !u64 {
    const row = try getRow(inp[0..7]);
    const col = try getColumn(inp[7..]);
    return row * 8 + col;
}

fn wrapGetId(allocator: *std.mem.Allocator, inp: []const u8) !u64 {
    return getId(inp);
}

pub fn main() anyerror!void {
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;
    const max_id = 127 * 8 + 7;
    var set = [_]u1{0} ** max_id;

    var arg_it = std.process.args();

    // skip own exe name
    _ = arg_it.skip();

    // Not really a fan that arg parsing requires allocations
    const file_path = try (arg_it.next(allocator) orelse {
        std.log.warn("Expected argument to be path to input file", .{});
        return error.InvalidArgs;
    });
    defer allocator.free(file_path);

    // const inp = try utils.transformLines(u64, allocator, file_path, wrapGetId);
    // defer inp.deinit();
    const inp = try readFile(allocator, file_path);
    defer allocator.free(inp);

    var it = std.mem.split(inp, "\n");
    var max: u64 = 0;
    var my_seat: u64 = 0;

    while (it.next()) |s| {
        if (s.len != 10) {
            continue;
        }
        const id = try getId(s);
        set[id] = 1;
        max = (if (max > id) max else id);
    }

    // the offset fixed since the original set is zero indexed
    var i: usize = 1;
    while (i < max_id - 1) : (i += 1) {
        if (set[i] == 0 and set[i - 1] == 1 and set[i + 1] == 1) {
            my_seat = i;
        }
    }

    std.debug.print("Day 5:\n", .{});
    std.debug.print("\tPart One: {}\n", .{max});
    std.debug.print("\tPart Two: {}\n", .{my_seat});
}

test "row example input" {
    const inp = "FBFBBFFRLR";
    const inp2 = "BFFFBBFRRR";
    const inp3 = "FFFBBBFRRR";
    const inp4 = "BBFFBBFRLL";

    expect((try getRow(inp[0..7])) == 44);
    expect((try getRow(inp2[0..7])) == 70);
    expect((try getRow(inp3[0..7])) == 14);
    expect((try getRow(inp4[0..7])) == 102);
}

test "col example input" {
    const inp = "FBFBBFFRLR";
    const inp2 = "BFFFBBFRRR";
    const inp3 = "FFFBBBFRRR";
    const inp4 = "BBFFBBFRLL";

    expect((try getColumn(inp[7..])) == 5);
    expect((try getColumn(inp2[7..])) == 7);
    expect((try getColumn(inp3[7..])) == 7);
    expect((try getColumn(inp4[7..])) == 4);
}

test "id example input" {
    const inp = "FBFBBFFRLR";
    const inp2 = "BFFFBBFRRR";
    const inp3 = "FFFBBBFRRR";
    const inp4 = "BBFFBBFRLL";
    expect((try getId(inp)) == 357);
    expect((try getId(inp2)) == 567);
    expect((try getId(inp3)) == 119);
    expect((try getId(inp4)) == 820);
}
