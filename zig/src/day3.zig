const std = @import("std");
const expect = std.testing.expect;
const utils = @import("./utils.zig");
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;

const Square = enum(u8) {
    Open = '.',
    Tree = '#',
};

const Slope = struct {
    dx: usize,
    dy: usize,
};

const Row = []const u8;

// Probably would want this to have the init/deinit functions
// in reality to better encapsulate state/make resource management
// cleaner.
const Board = struct {
    // Using the slice isntead of the actual array list here
    // Since the board isn't actually being init'd
    rows: []const Row,
    // invalid y index is user error and will panic
    fn get(self: *const Board, x: usize, y: usize) u8 {
        // on the odd chance that our rows aren't all equal len?
        const row = self.rows[y];
        return row[x % row.len];
    }

    fn countCollisions(self: *const Board, slope: Slope) usize {
        var x: usize = 0;
        var y: usize = 0;
        var count: usize = 0;
        while (y < self.rows.len) : ({
            y += slope.dy;
            x += slope.dx;
        }) {
            if (self.get(x, y) == '#') {
                count += 1;
            }
        }
        return count;
    }

    fn countCollisionsVec(self: *const Board, slopes: []const Slope) usize {
        var prod: usize = 1;
        for (slopes) |slope| {
            prod *= self.countCollisions(slope);
        }
        return prod;
    }
};

fn parseRow(allocator: *std.mem.Allocator, line: []const u8) anyerror!Row {
    return try std.mem.dupe(allocator, u8, line);
}

pub fn main() anyerror!void {
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

    var inp = try utils.transformLines(Row, allocator, file_path, parseRow);
    defer {
        for (inp.items) |row| {
            allocator.free(row);
        }
        inp.deinit();
    }

    const board = Board{ .rows = inp.items };

    std.debug.print("Day 3:\n", .{});
    std.debug.print("\tPart One: {}\n", .{board.countCollisions(.{ .dx = 3, .dy = 1 })});

    const slopes = [_]Slope{
        .{ .dx = 1, .dy = 1 },
        .{ .dx = 3, .dy = 1 },
        .{ .dx = 5, .dy = 1 },
        .{ .dx = 7, .dy = 1 },
        .{ .dx = 1, .dy = 2 },
    };
    std.debug.print("\tPart Two: {}\n", .{board.countCollisionsVec(&slopes)});
}

test "example input" {
    const rows = [_][]const u8{
        "..##.......",
        "#...#...#..",
        ".#....#..#.",
        "..#.#...#.#",
        ".#...##..#.",
        "..#.##.....",
        ".#.#.#....#",
        ".#........#",
        "#.##...#...",
        "#...##....#",
        ".#..#...#.#",
    };
    const slopes = [_]Slope{
        .{ .dx = 1, .dy = 1 },
        .{ .dx = 3, .dy = 1 },
        .{ .dx = 5, .dy = 1 },
        .{ .dx = 7, .dy = 1 },
        .{ .dx = 1, .dy = 2 },
    };
    const board = Board{ .rows = &rows };
    expect(board.countCollisions(.{ .dx = 3, .dy = 1 }) == 7);
    expect(board.countCollisionsVec(&slopes) == 336);
}
