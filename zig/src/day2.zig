const std = @import("std");
const expect = std.testing.expect;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const utils = @import("./utils.zig");
const indexOfScalar = std.mem.indexOfScalar;

const PwPolicy = struct {
    min_occur: u32,
    max_occur: u32,
    char: u8,
    pw: []const u8,

    fn validPartOne(self: *const PwPolicy) bool {
        // there must be a way to convert a u8 to a slice of size 1...
        // const count = std.mem.count(u8, self.pw, self.char);
        //
        // for now
        var count: usize = 0;
        for (self.pw) |byte| {
            if (byte == self.char) {
                count += 1;
                // fail fast since we aren't just using std.mem.count
                if (count > self.max_occur) {
                    return false;
                }
            }
        }
        return count >= self.min_occur;
        // return (count >= self.min_occur and count <= self.max_occur);
    }

    fn validPartTwo(self: *const PwPolicy) bool {
        // Not zero indexed
        // min_occur and max_occur are actually indexes in the pw

        // SIMD???
        const vec: std.meta.Vector(2, bool) = [_]bool{ self.pw[self.min_occur - 1] == self.char, self.pw[self.max_occur - 1] == self.char };
        return @reduce(.Xor, vec);
    }
};

const Error = error{ParsePwPolicy};

fn parsePwPolicy(allocator: *std.mem.Allocator, line: []const u8) Error!PwPolicy {
    // {min}-{max} {char}: {pw}
    // Not the cleanest parsing but whatever.
    const min_end = indexOfScalar(u8, line, '-') orelse return Error.ParsePwPolicy;
    const max_end = min_end + 1 + (indexOfScalar(u8, line[min_end + 1 ..], ' ') orelse return Error.ParsePwPolicy);
    const char_end = max_end + 1 + (indexOfScalar(u8, line[max_end + 1 ..], ':') orelse return Error.ParsePwPolicy);

    const min_occur = std.fmt.parseInt(u32, line[0..min_end], 10) catch return Error.ParsePwPolicy;
    const max_occur = std.fmt.parseInt(u32, line[min_end + 1 .. max_end], 10) catch return Error.ParsePwPolicy;
    const char = line[max_end + 1];
    const pw = std.mem.dupe(allocator, u8, line[char_end + 2 ..]) catch return Error.ParsePwPolicy;

    return PwPolicy{
        .min_occur = min_occur,
        .max_occur = max_occur,
        .char = char,
        .pw = pw,
    };
}

fn countValidPartOne(inp: []const PwPolicy) usize {
    var count: usize = 0;
    for (inp) |policy| {
        if (policy.validPartOne()) {
            count += 1;
        }
    }
    return count;
}

fn countValidPartTwo(inp: []const PwPolicy) usize {
    var count: usize = 0;
    for (inp) |policy| {
        if (policy.validPartTwo()) {
            count += 1;
        }
    }
    return count;
}

pub fn main() anyerror!void {
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    var arg_it = std.process.args();
    _ = arg_it.skip();

    const file_path = try (arg_it.next(allocator) orelse {
        std.log.warn("Expected argument to be path to input file", .{});
        return error.InvalidArgs;
    });
    defer allocator.free(file_path);

    var inp = try utils.transformLines(PwPolicy, allocator, file_path, parsePwPolicy);
    defer {
        for (inp.items) |policy| {
            allocator.free(policy.pw);
        }
        inp.deinit();
    }

    std.debug.print("Day 2:\n", .{});
    std.debug.print("\tPart One: {}\n", .{countValidPartOne(inp.items)});
    std.debug.print("\tPart Two: {}\n", .{countValidPartTwo(inp.items)});
}

test "example input" {
    const arr = [_]PwPolicy{
        .{ .min_occur = 1, .max_occur = 3, .char = 'a', .pw = "abcde" },
        .{ .min_occur = 1, .max_occur = 3, .char = 'b', .pw = "cdefg" },
        .{ .min_occur = 2, .max_occur = 9, .char = 'c', .pw = "ccccccccc" },
    };
    expect(countValidPartOne(&arr) == 2);
    expect(countValidPartTwo(&arr) == 1);
}

test "part one trivial is valid" {
    const arr = [_]PwPolicy{
        .{ .min_occur = 1, .max_occur = 2, .char = 'b', .pw = "aaaaab" },
        .{ .min_occur = 4, .max_occur = 8, .char = 'z', .pw = "azazzazz" },
        .{ .min_occur = 1, .max_occur = 10, .char = 'b', .pw = "b" },
    };
    expect(arr[0].validPartOne());
    expect(arr[1].validPartOne());
    expect(arr[2].validPartOne());
}

test "part one trivial is invalid" {
    const arr = [_]PwPolicy{
        .{ .min_occur = 5, .max_occur = 6, .char = 'c', .pw = "a" },
        .{ .min_occur = 1, .max_occur = 3, .char = 'c', .pw = "cccc" },
    };
    expect(arr[0].validPartOne() == false);
    expect(arr[1].validPartOne() == false);
}

test "part two trivial is valid" {
    const arr = [_]PwPolicy{
        .{ .min_occur = 1, .max_occur = 2, .char = 'b', .pw = "ab" },
        .{ .min_occur = 3, .max_occur = 5, .char = 'c', .pw = "aabaczz" },
    };
    expect(arr[0].validPartTwo());
    expect(arr[1].validPartTwo());
}

test "part one trivial is invalid" {
    const arr = [_]PwPolicy{
        .{ .min_occur = 1, .max_occur = 2, .char = 'b', .pw = "zzz" },
        .{ .min_occur = 3, .max_occur = 5, .char = 'c', .pw = "aacaczz" },
    };
}
