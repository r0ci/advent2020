const std = @import("std");
const expect = std.testing.expect;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const utils = @import("./utils.zig");
const bench = @import("./bench.zig");


fn readFile(allocator: *std.mem.Allocator, path: []const u8) ![]const u8 {
    var f = try std.fs.cwd().openFile(path, .{ .read = true, .write = false, .lock = std.fs.File.Lock.None });
    defer f.close();
    const st = try f.stat();

    return try f.reader().readAllAlloc(allocator, st.size);
}

// Count the unique characters in the group
fn parseGroupAnyone(group: []const u8) u64 {
    var set = [_]u1{0} ** 26;
    var sum: u64 = 0;
    
    for (group) |byte| {
        if (byte < 'a' or byte > 'z') {
            continue;
        }
        const off = byte - 'a';
        if (set[off] == 0) {
            set[off] = 1;
            sum += 1;
        }
    }
    
    return sum;
}

fn parseGroupEveryone(group: []const u8) u64 {
    var it = std.mem.split(group, "\n");
    var set = [_]u1{1} ** 26;
    
    while (it.next()) |individual| {
        var idv_set = [_]u1{0} ** 26;
        if (individual.len == 0) {
            continue;
        }
        for (individual) |byte| {
            if (byte < 'a' or byte > 'z') {
                continue;
            }
            const off = byte - 'a';
            idv_set[off] = 1;
        }
        
        for (idv_set) |idv_bit, i| {
            set[i] &= idv_bit;
        }
    }
    
    var sum: u64 = 0;
    for (set) |bit| {
        if (bit == 1) {
            sum += 1;
        }
    }

    return sum;
}


pub fn main() !void {
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
    
    const inp = try readFile(allocator, file_path);
    defer allocator.free(inp);
    
    var it = std.mem.split(inp, "\n\n");

    var anyone_count: u64 = 0;
    var everyone_count: u64 = 0;
    while (it.next()) |group| {
        anyone_count += parseGroupAnyone(group);
        everyone_count += parseGroupEveryone(group);
    }

    std.debug.print("Day 6:\n", .{});
    std.debug.print("\tPart one: {}\n", .{anyone_count});
    std.debug.print("\tPart two: {}\n", .{everyone_count});
}

test "example input part one" {
    const inp = "abc";
    const inp2 = "a\nb\nc\n";
    const inp3 = "ab\nac\n";
    const inp4 = "a\na\na\na\n";
    const inp5 = "b";

    expect(parseGroupAnyone(inp) == 3);
    expect(parseGroupAnyone(inp2) == 3);
    expect(parseGroupAnyone(inp3) == 3);
    expect(parseGroupAnyone(inp4) == 1);
    expect(parseGroupAnyone(inp5) == 1);
}

test "example input part two" {
    const inp = "abc";
    const inp2 = "a\nb\nc\n";
    const inp3 = "ab\nac\n";
    const inp4 = "a\na\na\na\n";
    const inp5 = "b";

    expect(parseGroupEveryone(inp) == 3);
    expect(parseGroupEveryone(inp2) == 0);
    expect(parseGroupEveryone(inp3) == 1);
    expect(parseGroupEveryone(inp4) == 1);
    expect(parseGroupEveryone(inp5) == 1);
}