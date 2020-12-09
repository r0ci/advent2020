const std = @import("std");
const expect = std.testing.expect;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;

fn isValid(preamble: []const u64, val: u64) bool {
    var i: usize = 0;
    while (i < preamble.len - 1) : (i += 1) {
        var j = i + 1;
        const first = preamble[i];
        while (j < preamble.len) : (j += 1) {
            const second = preamble[j];
            if ((first + second) == val) {
                return true;
            }
        }
    }

    return false;
}

fn parseInput(allocator: *std.mem.Allocator, inp: []const u8) !std.ArrayList(u64) {
    var storage = std.ArrayList(u64).init(allocator);
    var lines = std.mem.tokenize(inp, "\n");

    while (lines.next()) |line| {
        try storage.append(try std.fmt.parseUnsigned(u64, line, 10));
    }
    return storage;
}

const MinMax = struct {
    min: u64 = std.math.maxInt(u64),
    max: u64 = std.math.minInt(u64),
};

fn partTwo(storage: []const u64, value: u64) ?MinMax {
    var i: usize = 0;
    while (i < storage.len) : (i += 1) {
        var sum: usize = 0;
        var j: usize = i;
        var res = MinMax{};
        while (j < storage.len) : (j += 1) {
            const curr = storage[j];
            if (curr > res.max) {
                res.max = curr;
            }
            if (curr < res.min) {
                res.min = curr;
            }

            sum += curr;
            if (sum == value) {
                std.debug.print("range {} to {}, min {}, max {}\n", .{ i, j, res.min, res.max });
                return res;
            }
        }
    }
    return null;
}

fn firstInvalid(storage: []const u64, preamble_len: usize) ?u64 {
    var i = preamble_len;
    while (i < storage.len) : (i += 1) {
        if (i >= preamble_len) {
            if (!isValid(storage[i - preamble_len .. i], storage[i])) {
                return storage[i];
            }
        }
    }
    return null;
}

pub fn main() !void {
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    var arg_it = std.process.args();

    // skip own exe name
    _ = arg_it.skip();

    // Not really a fan that arg parsing requires allocations
    const file_path = try (arg_it.next(allocator) orelse {
        std.log.warn("Expected argument to be path to input file", .{});
        return error.InvalidArgs;
    });
    defer allocator.free(file_path);

    // learned that this is a thing
    const inp = try std.fs.cwd().readFileAlloc(allocator, file_path, std.math.maxInt(usize));
    defer allocator.free(inp);

    var storage = try parseInput(allocator, inp);
    defer storage.deinit();

    const first = firstInvalid(storage.items, 25).?;
    const second = partTwo(storage.items, first).?;

    std.debug.print("Day 9:\n", .{});
    std.debug.print("\tPart one: {}\n", .{first});
    std.debug.print("\tPart two: {}\n", .{second.min + second.max});
}

test "example input part one" {
    const inp =
        \\35
        \\20
        \\15
        \\25
        \\47
        \\40
        \\62
        \\55
        \\65
        \\95
        \\102
        \\117
        \\150
        \\182
        \\127
        \\219
        \\299
        \\277
        \\309
        \\576
    ;

    var storage = try parseInput(std.testing.allocator, inp);
    defer storage.deinit();

    const first_invalid = firstInvalid(storage.items, 5).?;
    expect(first_invalid == 127);

    const min_max = partTwo(storage.items, first_invalid).?;
    std.debug.print("{} {}", .{ min_max.min, min_max.max });
    expect(min_max.min == 15);
    expect(min_max.max == 47);
}
