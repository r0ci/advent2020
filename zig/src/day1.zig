const std = @import("std");
const expect = std.testing.expect;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const utils = @import("./utils.zig");
const bench = @import("./bench.zig");

fn Bitset(comptime S: usize) type {
    return [S + 1]u1;
}

fn helper(set: []u1, inp: []const u32, depth: u8, exp: u32) ?u64 {
    if (depth == 1) {
        if (set[exp] == 1) {
            return exp;
        } else {
            return null;
        }
    }

    for (inp) |val| {
        if (val > exp) {
            continue;
        }
        set[val] = 1;

        if (helper(set, inp, depth - 1, exp - val)) |found| {
            return val * found;
        }
    }
    return null;
}

fn genOptimized(inp: []const u32, depth: u8, comptime S: u32) ?u64 {
    var set: Bitset(S) = undefined;
    std.mem.set(u1, &set, 0);

    if (helper(&set, inp, depth, S)) |result| {
        return result;
    }
    return null;
}

fn genericized(inp: []const u32, depth: u8, exp: u32) ?u64 {
    if (depth == 1) {
        if (std.mem.indexOfScalar(u32, inp, exp)) |found_idx| {
            return inp[found_idx];
        } else {
            return null;
        }
    }

    var i: usize = 0;
    while (i < inp.len) : (i += 1) {
        if (inp[i] > exp) {
            continue;
        } else if (genericized(inp, depth - 1, exp - inp[i])) |found| {
            return inp[i] * found;
        }
    }

    return null;
}

fn parseU32(allocator: *std.mem.Allocator, line: []const u8) anyerror!u32 {
    return try std.fmt.parseInt(u32, line, 10);
}

pub fn main() anyerror!void {
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    var arg_it = std.process.args();

    // skip own exe name
    _ = arg_it.skip();

    const file_path = try (arg_it.next(allocator) orelse {
        std.log.warn("Expected argument to be path to input file", .{});
        return error.InvalidArgs;
    });
    defer allocator.free(file_path);

    var inp = try utils.transformLines(u32, allocator, file_path, parseU32);
    defer inp.deinit();

    std.debug.print("Day 1:\n", .{});
    std.debug.print("\tDepth 2: {}\n", .{genOptimized(inp.items, 2, 2020)});
    std.debug.print("\tDepth 3: {}\n", .{genOptimized(inp.items, 3, 2020)});
    std.debug.print("\tDepth 4: {}\n", .{genOptimized(inp.items, 4, 2020)});

    // try bench.writeBench("old solution, depth: 2", genericized, .{inp.items, 2, 2020});
    // try bench.writeBench("old solution, depth: 3", genericized, .{inp.items, 3, 2020});
    // try bench.writeBench("old solution, depth: 4", genericized, .{inp.items, 4, 2020});
    // try bench.writeBench("bitset solution, depth: 2", genOptimized, .{inp.items, 2, 2020});
    // try bench.writeBench("bitset solution, depth: 3", genOptimized, .{inp.items, 3, 2020});
    // try bench.writeBench("bitset solution, depth: 4", genOptimized, .{inp.items, 4, 2020});
}

fn blumpf() void {
    std.debug.print("aa\n", .{});
}

test "oooh" {
    const arr = [_]u32{ 1721, 979, 366, 299, 675, 1456 };
    var i: usize = 0;
    var prod: u64 = 0;
    while (i < arr.len) : (i += 1) {
        if (std.mem.indexOfScalar(u32, &arr, 2020 - arr[i])) |found_idx| {
            prod = arr[i] * arr[found_idx];
            break;
        }
    }
    expect(prod == 514579);
}

test "example input" {
    const arr = [_]u32{ 1721, 979, 366, 299, 675, 1456 };
    expect(genOptimized(&arr, 2, 2020).? == 514579);
    expect(genOptimized(&arr, 3, 2020).? == 241861950);
    expect(genericized(&arr, 2, 2020).? == 514579);
    expect(genericized(&arr, 3, 2020).? == 241861950);
}

test "trivial fail" {
    const arr = [_]u32{ 0, 1, 2, 3, 4 };
    expect(genOptimized(&arr, 2, 2020) == null);
    expect(genOptimized(&arr, 3, 2020) == null);
    expect(genOptimized(&arr, 4, 2020) == null);
    expect(genericized(&arr, 2, 2020) == null);
    expect(genericized(&arr, 3, 2020) == null);
    expect(genericized(&arr, 4, 2020) == null);
}

test "trivial success" {
    const arr = [_]u32{ 1, 2, 2017, 2019 };
    expect(genOptimized(&arr, 2, 2020).? == 2019);
    expect(genOptimized(&arr, 3, 2020).? == 4034);
    expect(genericized(&arr, 2, 2020).? == 2019);
    expect(genericized(&arr, 3, 2020).? == 4034);
}
