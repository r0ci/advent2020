const std = @import("std");
const expect = std.testing.expect;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;

const Cell = enum(u8) {
    Empty = 'L',
    Occupied = '#',
    Floor = '.',
};

const Grid = struct {
    allocator: *std.mem.Allocator,
    step_count: u64,
    width: usize,
    height: usize,
    storage: []Cell,

    fn init(allocator: *std.mem.Allocator, width: usize, height: usize) !Grid {
        return Grid{
            .width = width,
            .height = height,
            .allocator = allocator,
            .step_count = 0,
            .storage = try allocator.alloc(Cell, 2 * width * height),
        };
    }

    fn fromInput(allocator: *std.mem.Allocator, inp: []const u8) !Grid {
        var lines = std.mem.tokenize(inp, "\n");

        const width: usize = (lines.next() orelse {
            return error.InvalidGridWidth;
        }).len;

        var height: usize = 1;

        while (lines.next()) |_| : (height += 1) {}

        var grid = try Grid.init(allocator, width, height);

        lines = std.mem.tokenize(inp, "\n");
        var idx: usize = 0;
        while (lines.next()) |line| {
            for (line) |byte| {
                // this can give undefined behavior in non debug/release-safe builds
                // realistically a safe parsing func would be used
                grid.storage[idx] = @intToEnum(Cell, byte);
                idx += 1;
            }
        }

        return grid;
    }

    fn currentSlice(self: Grid) []Cell {
        const start = self.currentStart();
        return self.storage[start .. start + self.height * self.width];
    }

    fn nextSlice(self: Grid) []Cell {
        const start = self.nextStart();
        return self.storage[start .. start + self.height * self.width];
    }

    fn currentStart(self: Grid) usize {
        return (self.step_count % 2) * (self.height * self.width);
    }

    fn nextStart(self: Grid) usize {
        return ((self.step_count +% 1) % 2) * (self.height * self.width);
    }

    fn countAdjacentOccupied(self: Grid, idx: usize) u8 {
        const y = idx / self.width % self.height;
        const x = idx % self.width;
        var count: u8 = 0;
        if (y > 0) {
            if (x > 0 and self.storage[idx - self.width - 1] == Cell.Occupied) count += 1;
            if (self.storage[idx - self.width] == Cell.Occupied) count += 1;
            if (x < self.width - 1 and self.storage[idx - self.width + 1] == Cell.Occupied) count += 1;
        }
        if (x > 0 and self.storage[idx - 1] == Cell.Occupied) count += 1;
        if (x < self.width - 1 and self.storage[idx + 1] == Cell.Occupied) count += 1;
        if (y < self.height - 1) {
            if (x > 0 and self.storage[idx + self.width - 1] == Cell.Occupied) count += 1;
            if (self.storage[idx + self.width] == Cell.Occupied) count += 1;
            if (x < self.width - 1 and self.storage[idx + self.width + 1] == Cell.Occupied) count += 1;
        }
        return count;
    }

    fn countVisibleOccupied(self: Grid, idx: usize) u8 {
        const y = idx / self.width % self.height;
        const x = idx % self.width;
        var occ_count: u8 = 0;
        // count visible diagonal up left
        var iter_count: usize = 1;
        while (iter_count <= std.math.min(x, y)) : (iter_count += 1) {
            const check_idx = idx - (self.width * iter_count) - iter_count;
            const check_cell = self.storage[check_idx];
            if (check_cell == Cell.Occupied) occ_count += 1;
            if (check_cell != Cell.Floor) break;
        }

        // count visible diagonal up right
        iter_count = 1;
        while (iter_count <= std.math.min(self.width - x - 1, y)) : (iter_count += 1) {
            const check_idx = idx - (self.width * iter_count) + iter_count;
            const check_cell = self.storage[check_idx];
            if (check_cell == Cell.Occupied) occ_count += 1;
            if (check_cell != Cell.Floor) break;
        }

        // count visible diagonal down left
        iter_count = 1;
        while (iter_count <= std.math.min(x, self.height - y - 1)) : (iter_count += 1) {
            const check_idx = idx + (self.width * iter_count) - iter_count;
            const check_cell = self.storage[check_idx];
            if (check_cell == Cell.Occupied) occ_count += 1;
            if (check_cell != Cell.Floor) break;
        }

        // count visible diagonal down right
        iter_count = 1;
        while (iter_count <= std.math.min(self.width - x - 1, self.height - y - 1)) : (iter_count += 1) {
            const check_idx = idx + (self.width * iter_count) + iter_count;
            const check_cell = self.storage[check_idx];
            if (check_cell == Cell.Occupied) occ_count += 1;
            if (check_cell != Cell.Floor) break;
        }

        // check visible up
        iter_count = 1;
        while (iter_count <= y) : (iter_count += 1) {
            const check_idx = idx - (self.width * iter_count);
            const check_cell = self.storage[check_idx];
            if (check_cell == Cell.Occupied) occ_count += 1;
            if (check_cell != Cell.Floor) break;
        }

        // check visible down
        iter_count = 1;
        while (iter_count <= self.height - y - 1) : (iter_count += 1) {
            const check_idx = idx + (self.width * iter_count);
            const check_cell = self.storage[check_idx];
            if (check_cell == Cell.Occupied) occ_count += 1;
            if (check_cell != Cell.Floor) break;
        }

        // check visible left
        iter_count = 1;
        while (iter_count <= x) : (iter_count += 1) {
            const check_idx = idx - iter_count;
            const check_cell = self.storage[check_idx];
            if (check_cell == Cell.Occupied) occ_count += 1;
            if (check_cell != Cell.Floor) break;
        }

        // check visible right
        iter_count = 1;
        while (iter_count <= self.width - x - 1) : (iter_count += 1) {
            const check_idx = idx + iter_count;
            const check_cell = self.storage[check_idx];
            if (check_cell == Cell.Occupied) occ_count += 1;
            if (check_cell != Cell.Floor) break;
        }

        return occ_count;
    }

    // Runs an iteration of the model
    fn stepPartOne(self: *Grid) void {
        const curr_start = self.currentStart();
        const next_start = self.nextStart();

        var idx: usize = 0;
        while (idx < self.height * self.width) : (idx += 1) {
            self.storage[next_start + idx] = switch (self.storage[curr_start + idx]) {
                Cell.Empty => if (self.countAdjacentOccupied(curr_start + idx) == 0) Cell.Occupied else Cell.Empty,
                Cell.Occupied => if (self.countAdjacentOccupied(curr_start + idx) >= 4) Cell.Empty else Cell.Occupied,
                Cell.Floor => Cell.Floor,
            };
        }

        self.step_count = self.step_count +% 1;
    }

    fn stepPartTwo(self: *Grid) void {
        const curr_start = self.currentStart();
        const next_start = self.nextStart();

        var idx: usize = 0;
        while (idx < self.height * self.width) : (idx += 1) {
            self.storage[next_start + idx] = switch (self.storage[curr_start + idx]) {
                Cell.Empty => if (self.countVisibleOccupied(curr_start + idx) == 0) Cell.Occupied else Cell.Empty,
                Cell.Occupied => if (self.countVisibleOccupied(curr_start + idx) >= 5) Cell.Empty else Cell.Occupied,
                Cell.Floor => Cell.Floor,
            };
        }

        self.step_count = self.step_count +% 1;
    }

    fn runPartOne(self: *Grid) void {
        while (self.step_count < std.math.maxInt(u64)) {
            self.stepPartOne();

            if (std.mem.eql(Cell, self.currentSlice(), self.nextSlice())) {
                break;
            }
        }
    }

    fn runPartTwo(self: *Grid) void {
        while (self.step_count < std.math.maxInt(u64)) {
            self.stepPartTwo();

            if (std.mem.eql(Cell, self.currentSlice(), self.nextSlice())) {
                break;
            }
        }
    }

    fn countOccupied(self: Grid) usize {
        return std.mem.count(Cell, self.currentSlice(), &[_]Cell{Cell.Occupied});
    }

    fn get(self: Grid, x: usize, y: usize) Cell {
        const off = self.currentStart();
        return self.storage[off + x + y * self.height];
    }

    fn getRow(self: Grid, y: usize) []const Cell {
        const start = y * self.width;
        return self.currentSlice()[start .. start + self.width];
    }

    fn debugPrint(self: Grid) void {
        std.debug.print("GRID (step {})\n", .{self.step_count});
        const current = self.currentSlice();
        const next = self.nextSlice();

        std.debug.print("\tCURRENT:\n", .{});
        var y: usize = 0;
        while (y < self.height) : (y += 1) {
            var x: usize = 0;
            std.debug.print("\t", .{});

            while (x < self.width) : (x += 1) {
                std.debug.print("{c}", .{@enumToInt(current[y * self.height + x])});
            }
            std.debug.print("\n", .{});
        }
    }

    fn deinit(self: Grid) void {
        self.allocator.free(self.storage);
    }
};

fn parseInputFile(allocator: *std.mem.Allocator, file_path: []const u8) !Grid {
    const inp = try std.fs.cwd().readFileAlloc(allocator, file_path, std.math.maxInt(usize));
    defer allocator.free(inp);

    return try Grid.fromInput(allocator, inp);
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

    var grid = try parseInputFile(allocator, file_path);
    defer grid.deinit();
    grid.runPartOne();

    var grid2 = try parseInputFile(allocator, file_path);
    defer grid2.deinit();
    grid2.runPartTwo();

    std.debug.print("Day 11\n", .{});
    std.debug.print("\tPart one: {}\n", .{grid.countOccupied()});
    std.debug.print("\tPart two: {}\n", .{grid2.countOccupied()});
}

// Test helpers
fn expectGridEqual(grid: Grid, lines: []const u8) void {
    var lines_it = std.mem.tokenize(lines, "\n");
    var row_idx: usize = 0;
    while (lines_it.next()) |line| {
        const row = grid.getRow(row_idx);
        expectRowEqual(row, line);
        row_idx += 1;
    }
}

fn expectRowEqual(row: []const Cell, line: []const u8) void {
    for (row) |cell, idx| {
        expect(@enumToInt(cell) == line[idx]);
    }
}

test "example input part one" {
    const inp =
        \\L.LL.LL.LL
        \\LLLLLLL.LL
        \\L.L.L..L..
        \\LLLL.LL.LL
        \\L.LL.LL.LL
        \\L.LLLLL.LL
        \\..L.L.....
        \\LLLLLLLLLL
        \\L.LLLLLL.L
        \\L.LLLLL.LL
    ;
    const steps_exp = [_][]const u8{
        \\#.##.##.##
        \\#######.##
        \\#.#.#..#..
        \\####.##.##
        \\#.##.##.##
        \\#.#####.##
        \\..#.#.....
        \\##########
        \\#.######.#
        \\#.#####.##
        ,
        \\#.LL.L#.##
        \\#LLLLLL.L#
        \\L.L.L..L..
        \\#LLL.LL.L#
        \\#.LL.LL.LL
        \\#.LLLL#.##
        \\..L.L.....
        \\#LLLLLLLL#
        \\#.LLLLLL.L
        \\#.#LLLL.##
        ,
        \\#.##.L#.##
        \\#L###LL.L#
        \\L.#.#..#..
        \\#L##.##.L#
        \\#.##.LL.LL
        \\#.###L#.##
        \\..#.#.....
        \\#L######L#
        \\#.LL###L.L
        \\#.#L###.##
        ,
        \\#.#L.L#.##
        \\#LLL#LL.L#
        \\L.L.L..#..
        \\#LLL.##.L#
        \\#.LL.LL.LL
        \\#.LL#L#.##
        \\..L.L.....
        \\#L#LLLL#L#
        \\#.LLLLLL.L
        \\#.#L#L#.##
        ,
        \\#.#L.L#.##
        \\#LLL#LL.L#
        \\L.#.L..#..
        \\#L##.##.L#
        \\#.#L.LL.LL
        \\#.#L#L#.##
        \\..L.L.....
        \\#L#L##L#L#
        \\#.LLLLLL.L
        \\#.#L#L#.##
    };

    std.debug.print("\n", .{});
    var grid = try Grid.fromInput(std.testing.allocator, inp);
    defer grid.deinit();

    expectGridEqual(grid, inp);
    expect(grid.currentStart() == 0);
    expect(grid.nextStart() == grid.height * grid.width);

    for (steps_exp) |exp, idx| {
        grid.stepPartOne();
        expect(grid.step_count == idx + 1);
        expectGridEqual(grid, exp);
    }

    expect(grid.countOccupied() == 37);

    var grid2 = try Grid.fromInput(std.testing.allocator, inp);
    defer grid2.deinit();

    grid2.runPartOne();
    expect(grid2.countOccupied() == 37);
}

test "count visible occupied" {
    const inp =
        \\.......#.
        \\...#.....
        \\.#.......
        \\.........
        \\..#L....#
        \\....#....
        \\.........
        \\#........
        \\...#.....
    ;

    var grid = try Grid.fromInput(std.testing.allocator, inp);
    defer grid.deinit();
    const idx = 3 + 4 * grid.width;
    expect(grid.storage[idx] == Cell.Empty);
    expect(grid.countVisibleOccupied(idx) == 8);

    const inp2 =
        \\.............
        \\.L.L.#.#.#.#.
        \\.............
    ;
    var grid2 = try Grid.fromInput(std.testing.allocator, inp2);
    defer grid2.deinit();
    const idx2 = 1 + grid2.width;
    expect(grid2.storage[idx2] == Cell.Empty);
    expect(grid2.countVisibleOccupied(idx2) == 0);

    const inp3 =
        \\.##.##.
        \\#.#.#.#
        \\##...##
        \\...L...
        \\##...##
        \\#.#.#.#
        \\.##.##.
    ;
    var grid3 = try Grid.fromInput(std.testing.allocator, inp3);
    defer grid3.deinit();
    const idx3 = 3 + 3 * grid3.width;
    expect(grid3.storage[idx3] == Cell.Empty);
    expect(grid3.countVisibleOccupied(idx3) == 0);
}

test "example input part two" {
    const inp =
        \\L.LL.LL.LL
        \\LLLLLLL.LL
        \\L.L.L..L..
        \\LLLL.LL.LL
        \\L.LL.LL.LL
        \\L.LLLLL.LL
        \\..L.L.....
        \\LLLLLLLLLL
        \\L.LLLLLL.L
        \\L.LLLLL.LL
    ;
    const steps_exp = [_][]const u8{
        \\#.##.##.##
        \\#######.##
        \\#.#.#..#..
        \\####.##.##
        \\#.##.##.##
        \\#.#####.##
        \\..#.#.....
        \\##########
        \\#.######.#
        \\#.#####.##
        ,
        \\#.LL.LL.L#
        \\#LLLLLL.LL
        \\L.L.L..L..
        \\LLLL.LL.LL
        \\L.LL.LL.LL
        \\L.LLLLL.LL
        \\..L.L.....
        \\LLLLLLLLL#
        \\#.LLLLLL.L
        \\#.LLLLL.L#
        ,
        \\#.L#.##.L#
        \\#L#####.LL
        \\L.#.#..#..
        \\##L#.##.##
        \\#.##.#L.##
        \\#.#####.#L
        \\..#.#.....
        \\LLL####LL#
        \\#.L#####.L
        \\#.L####.L#
        ,
        \\#.L#.L#.L#
        \\#LLLLLL.LL
        \\L.L.L..#..
        \\##LL.LL.L#
        \\L.LL.LL.L#
        \\#.LLLLL.LL
        \\..L.L.....
        \\LLLLLLLLL#
        \\#.LLLLL#.L
        \\#.L#LL#.L#
        ,
        \\#.L#.L#.L#
        \\#LLLLLL.LL
        \\L.L.L..#..
        \\##L#.#L.L#
        \\L.L#.#L.L#
        \\#.L####.LL
        \\..#.#.....
        \\LLL###LLL#
        \\#.LLLLL#.L
        \\#.L#LL#.L#
        ,
        \\#.L#.L#.L#
        \\#LLLLLL.LL
        \\L.L.L..#..
        \\##L#.#L.L#
        \\L.L#.LL.L#
        \\#.LLLL#.LL
        \\..#.L.....
        \\LLL###LLL#
        \\#.LLLLL#.L
        \\#.L#LL#.L#
    };

    std.debug.print("\n", .{});
    var grid = try Grid.fromInput(std.testing.allocator, inp);
    defer grid.deinit();

    expectGridEqual(grid, inp);
    expect(grid.currentStart() == 0);
    expect(grid.nextStart() == grid.height * grid.width);

    for (steps_exp) |exp, idx| {
        grid.stepPartTwo();
        expect(grid.step_count == idx + 1);
        expectGridEqual(grid, exp);
    }

    expect(grid.countOccupied() == 26);

    var grid2 = try Grid.fromInput(std.testing.allocator, inp);
    defer grid2.deinit();

    grid2.runPartTwo();
    expect(grid2.countOccupied() == 26);
}
