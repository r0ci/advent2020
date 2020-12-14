const std = @import("std");
const expect = std.testing.expect;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const bench = @import("./bench.zig");

fn partOne(timestamp: u64, buses: []const u64) u64 {
    var min_diff: u64 = std.math.maxInt(u64);
    var min_bus: usize = 0;
    for (buses) |bus| {
        const rem = timestamp % bus;
        if (rem == 0) {
            return 0;
        }

        const diff = bus - rem;
        if (diff <= min_diff) {
            min_diff = diff;
            min_bus = bus;
        }
    }

    return min_diff * min_bus;
}

fn partOneInput(allocator: *std.mem.Allocator, inp: []const u8) !u64 {
    var lines = std.mem.tokenize(inp, "\n");
    const timestamp = try std.fmt.parseUnsigned(u64, lines.next().?, 10);

    const bus_ids_str = lines.next().?;
    var bus_ids_it = std.mem.tokenize(bus_ids_str, ",");
    var bus_ids = std.ArrayList(u64).init(allocator);
    defer bus_ids.deinit();

    while (bus_ids_it.next()) |id| {
        if (std.mem.eql(u8, id, "x")) {
            continue;
        }

        try bus_ids.append(try std.fmt.parseUnsigned(u64, id, 10));
    }

    return partOne(timestamp, bus_ids.items);
}

// The result of extended euclidean algorithm
// a*x + b*y = gcd(a,b)
const ExtGcdResult = struct {
    gcd: i64,
    x: i64,
    y: i64,
};

// I was going to try writing a solution using the existence construction method,
// so was using this to get bezout coefficients. But sieve is fast enough.
fn extendedGcd(a: i64, b: i64) ExtGcdResult {
    var old_r: i64 = a;
    var r: i64 = b;
    var old_s: i64 = 1;
    var s: i64 = 0;
    var old_t: i64 = 0;
    var t: i64 = 1;

    while (r != 0) {
        // const quot = @divTrunc(old_r, r);
        const quot = @divFloor(old_r, r);

        const tmp_r = r;
        const tmp_s = s;
        const tmp_t = t;

        r = old_r - quot * r;
        old_r = tmp_r;

        s = old_s - quot * s;
        old_s = tmp_s;

        t = old_t - quot * t;
        old_t = tmp_t;
    }

    return ExtGcdResult{
        .gcd = old_r,
        .x = old_s,
        .y = old_t,
    };
}

// descendingsort comparator for buses
fn busesDescending(_: void, a: Bus, b: Bus) bool {
    return a.id > b.id;
}

const Bus = struct {
    id: u64, list_index: u64
};

// this ends up being solved by CRT
//
// we have a system where for each bus:
// x ≡ (bus[i].id - bus[i].list_index) (mod bus[i].id)
//
// this implementation solves using the sieve method which isnt optimal
fn partTwoSieve(buses: []Bus) u64 {
    // sort the buses in descending order (using id as value)
    std.sort.sort(Bus, buses, {}, busesDescending);

    // we start with steps of the largest modulus, which is the first bus id
    var step = buses[0].id;
    var ts = (buses[0].id - buses[0].list_index);
    var curr_bus_idx: usize = 1;
    while (ts < std.math.maxInt(u64)) : (ts += step) {
        var valid: bool = true;
        const to_check = buses[curr_bus_idx..];

        for (to_check) |bus, idx| {
            if (@mod(ts + bus.list_index, bus.id) == 0) {
                // the current timestamp matches x = (bus.id - bus.list_index) (mod bus.id)
                step *= bus.id;
                curr_bus_idx += 1;
            } else {
                valid = false;
                break;
            }
        }

        if (valid) {
            return ts;
        }
    }

    return 0;
}

fn partTwoInput(allocator: *std.mem.Allocator, inp: []const u8) !u64 {
    var lines = std.mem.tokenize(inp, "\n");
    _ = lines.next();

    const bus_ids_str = lines.next().?;
    var bus_ids_it = std.mem.tokenize(bus_ids_str, ",");
    var buses = std.ArrayList(Bus).init(allocator);
    defer buses.deinit();

    var idx: u64 = 0;
    while (bus_ids_it.next()) |bus_id| : (idx += 1) {
        if (std.mem.eql(u8, bus_id, "x")) {
            continue;
        }

        try buses.append(Bus{
            .id = try std.fmt.parseUnsigned(u64, bus_id, 10),
            .list_index = idx,
        });
    }

    // try bench.writeBench("Part Two w/ Sieve", partTwoSieve, .{buses.items});

    return partTwoSieve(buses.items);
}

pub fn main() !void {
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    var arg_it = std.process.ArgIteratorPosix.init();

    _ = arg_it.skip();

    const file_path = arg_it.next() orelse {
        std.log.warn("Expected argument to be path to input file", .{});
        return error.InvalidArgs;
    };

    const inp = try std.fs.cwd().readFileAlloc(allocator, file_path, std.math.maxInt(usize));
    defer allocator.free(inp);

    std.debug.print("Day 13\n", .{});
    std.debug.print("\tPart one: {}\n", .{try partOneInput(allocator, inp)});
    std.debug.print("\tPart two: {}\n", .{try partTwoInput(allocator, inp)});
}

test "example input part one" {
    expect(partOne(939, &[_]u64{ 7, 13, 59, 31, 19 }) == 295);
}

test "example input part two" {
    var inp = [_]Bus{
        .{ .id = 17, .list_index = 0 },
        .{ .id = 13, .list_index = 2 },
        .{ .id = 19, .list_index = 3 },
    };
    expect(partTwoSieve(&inp) == 3417);

    var inp2 = [_]Bus{
        .{ .id = 67, .list_index = 0 },
        .{ .id = 7, .list_index = 1 },
        .{ .id = 59, .list_index = 2 },
        .{ .id = 61, .list_index = 3 },
    };
    expect(partTwoSieve(&inp2) == 754018);

    var inp3 = [_]Bus{
        .{ .id = 67, .list_index = 0 },
        .{ .id = 7, .list_index = 2 },
        .{ .id = 59, .list_index = 3 },
        .{ .id = 61, .list_index = 4 },
    };
    expect(partTwoSieve(&inp3) == 779210);

    var inp4 = [_]Bus{
        .{ .id = 67, .list_index = 0 },
        .{ .id = 7, .list_index = 1 },
        .{ .id = 59, .list_index = 3 },
        .{ .id = 61, .list_index = 4 },
    };
    expect(partTwoSieve(&inp4) == 1261476);

    var inp5 = [_]Bus{
        .{ .id = 1789, .list_index = 0 },
        .{ .id = 37, .list_index = 1 },
        .{ .id = 47, .list_index = 2 },
        .{ .id = 1889, .list_index = 3 },
    };
    expect(partTwoSieve(&inp5) == 1202161486);

    var inp6 = [_]Bus{
        .{ .id = 7, .list_index = 0 },
        .{ .id = 13, .list_index = 1 },
        .{ .id = 59, .list_index = 4 },
        .{ .id = 31, .list_index = 6 },
        .{ .id = 19, .list_index = 7 },
    };
    expect(partTwoSieve(&inp6) == 1068781);
}

test "extended gcd" {
    const res = extendedGcd(12, 42);
    expect(res.gcd == 6);
    expect(res.x == -3);
    expect(res.y == 1);

    const res2 = extendedGcd(1180, 482);
    expect(res2.gcd == 2);
    expect(res2.x == -29);
    expect(res2.y == 71);

    const res3 = extendedGcd(3, 4);
    expect(res3.gcd == 1);
    expect(res3.x == -1);
    expect(res3.y == 1);

    const res4 = extendedGcd(5, 12);
    expect(res4.gcd == 1);
    expect(res4.x == 5);
    expect(res4.y == -2);
}

test "buses sort" {
    var inp = [_]Bus{
        .{ .id = 1789, .list_index = 0 },
        .{ .id = 37, .list_index = 1 },
        .{ .id = 47, .list_index = 2 },
        .{ .id = 1889, .list_index = 3 },
    };

    std.sort.sort(Bus, &inp, {}, busesDescending);
    expect(inp[0].id == 1889);
    expect(inp[1].id == 1789);
    expect(inp[2].id == 47);
    expect(inp[3].id == 37);
}
