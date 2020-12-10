const std = @import("std");
const expect = std.testing.expect;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;

const asc_u64 = std.sort.asc(u64);

fn parseInputFile(allocator: *std.mem.Allocator, file_path: []const u8) !std.ArrayList(u64) {
    const inp = try std.fs.cwd().readFileAlloc(allocator, file_path, std.math.maxInt(usize));
    defer allocator.free(inp);

    return try parseInput(allocator, inp);
}

fn parseInput(allocator: *std.mem.Allocator, inp: []const u8) !std.ArrayList(u64) {
    // learned that this is a thing
    var storage = std.ArrayList(u64).init(allocator);
    var lines = std.mem.tokenize(inp, "\n");

    while (lines.next()) |line| {
        try storage.append(try std.fmt.parseUnsigned(u64, line, 10));
    }

    std.sort.sort(u64, storage.items, {}, asc_u64);
    return storage;
}

// cache via storage so this doesnt take forever
fn countArrangements(adapters: []const u64, idx: usize, storage: []u64) u64 {
    // assume we setup our slices properly
    if (storage[idx] != 0) {
        return storage[idx];
    }

    if (idx == 0) {
        storage[idx] = 1;
        return 1;
    }
    var arr_count: u64 = 0;

    var iter_count: usize = 0;
    while (iter_count < idx) : (iter_count += 1) {
        const cmp_idx = idx - (iter_count + 1);
        if (adapters[idx] - adapters[cmp_idx] <= 3) {
            arr_count += countArrangements(adapters, cmp_idx, storage);
        } else {
            break;
        }
    }

    // special case for jolts <= 3
    if (adapters[idx] <= 3) {
        arr_count += 1;
    }

    storage[idx] = arr_count;
    return arr_count;
}

const Diffs = struct {
    one: u64 = 0, three: u64 = 1
};

fn countDiffs(adapters: []const u64) Diffs {
    var i: usize = 0;
    var res = Diffs{};

    if (adapters[0] == 3) {
        res.three += 1;
    } else if (adapters[0] == 1) {
        res.one += 1;
    }

    while (i < adapters.len - 1) : (i += 1) {
        const diff = adapters[i + 1] - adapters[i];
        if (diff == 3) {
            res.three += 1;
        } else if (diff == 1) {
            res.one += 1;
        }
    }
    return res;
}

pub fn main() !void {
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    var arg_it = std.process.ArgIteratorPosix.init();

    // skip own exe name
    _ = arg_it.skip();

    // Not really a fan that arg parsing requires allocations
    const file_path = arg_it.next() orelse {
        std.log.warn("Expected argument to be path to input file", .{});
        return error.InvalidArgs;
    };

    var adapters = try parseInputFile(allocator, file_path);
    defer adapters.deinit();

    // const device_jolts = adapters.items[adapters.items.len - 1] + 3;

    const diffs = countDiffs(adapters.items);
    std.debug.print("\n{} {}\n", .{ diffs.one, diffs.three });

    var storage = try std.ArrayList(u64).initCapacity(allocator, adapters.items.len);
    storage.appendNTimesAssumeCapacity(0, adapters.items.len);
    defer storage.deinit();

    const arrs = countArrangements(adapters.items, adapters.items.len - 1, storage.items);

    std.debug.print("Day 10:\n", .{});
    std.debug.print("\tPart one: {}\n", .{diffs.one * diffs.three});
    std.debug.print("\tPart two: {}\n", .{arrs});
}

test "example input part one short" {
    const inp =
        \\16
        \\10
        \\15
        \\5
        \\1
        \\11
        \\7
        \\19
        \\6
        \\12
        \\4
    ;
    var adapters = try parseInput(std.testing.allocator, inp);
    defer adapters.deinit();

    const diffs = countDiffs(adapters.items);
    std.debug.print("\n{} {}\n", .{ diffs.one, diffs.three });
    expect(diffs.one == 7);
    expect(diffs.three == 5);
}

test "example input part one long" {
    const inp =
        \\28
        \\33
        \\18
        \\42
        \\31
        \\14
        \\46
        \\20
        \\48
        \\47
        \\24
        \\23
        \\49
        \\45
        \\19
        \\38
        \\39
        \\11
        \\1
        \\32
        \\25
        \\35
        \\8
        \\17
        \\7
        \\9
        \\4
        \\2
        \\34
        \\10
        \\3
    ;
    var adapters = try parseInput(std.testing.allocator, inp);
    defer adapters.deinit();
    const diffs = countDiffs(adapters.items);
    std.debug.print("\n{} {}\n", .{ diffs.one, diffs.three });
    expect(diffs.one == 22);
    expect(diffs.three == 10);
}

test "example input part two short" {
    const inp =
        \\16
        \\10
        \\15
        \\5
        \\1
        \\11
        \\7
        \\19
        \\6
        \\12
        \\4
    ;

    var adapters = try parseInput(std.testing.allocator, inp);
    defer adapters.deinit();

    var storage = try std.ArrayList(u64).initCapacity(std.testing.allocator, adapters.items.len * 2);
    defer storage.deinit();
    storage.appendNTimesAssumeCapacity(0, adapters.items.len);

    const count = countArrangements(adapters.items, adapters.items.len - 1, storage.items);
    expect(count == 8);
}

test "example input part two long" {
    const inp =
        \\28
        \\33
        \\18
        \\42
        \\31
        \\14
        \\46
        \\20
        \\48
        \\47
        \\24
        \\23
        \\49
        \\45
        \\19
        \\38
        \\39
        \\11
        \\1
        \\32
        \\25
        \\35
        \\8
        \\17
        \\7
        \\9
        \\4
        \\2
        \\34
        \\10
        \\3
    ;
    var adapters = try parseInput(std.testing.allocator, inp);
    defer adapters.deinit();

    var storage = try std.ArrayList(u64).initCapacity(std.testing.allocator, adapters.items.len);
    defer storage.deinit();
    storage.appendNTimesAssumeCapacity(0, adapters.items.len);

    const count = countArrangements(adapters.items, adapters.items.len - 1, storage.items);
    std.debug.print("\n{}\n", .{count});
    expect(count == 19208);
}
