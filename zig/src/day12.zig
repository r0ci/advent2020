const std = @import("std");
const expect = std.testing.expect;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;

const Direction = enum(i64) {
    North = 0,
    East = 90,
    South = 180,
    West = 270,

    // Positive = rotate right
    // Negative = rotate left
    fn rotate(self: *Direction, degrees: i64) void {
        self.* = @intToEnum(Direction, @mod((@enumToInt(self.*) + degrees), 360));
    }
};

const Action = union(enum) {
    North: i64,
    South: i64,
    East: i64,
    West: i64,
    Rotate: i64,
    Forward: i64,

    fn fromString(str: []const u8) !Action {
        return switch (str[0]) {
            'N' => Action{ .North = try std.fmt.parseUnsigned(i64, str[1..], 10) },
            'S' => Action{ .South = try std.fmt.parseUnsigned(i64, str[1..], 10) },
            'E' => Action{ .East = try std.fmt.parseUnsigned(i64, str[1..], 10) },
            'W' => Action{ .West = try std.fmt.parseUnsigned(i64, str[1..], 10) },
            'L' => Action{ .Rotate = @mod(-1 * try std.fmt.parseUnsigned(i64, str[1..], 10), 360) },
            'R' => Action{ .Rotate = @mod(try std.fmt.parseUnsigned(i64, str[1..], 10), 360) },
            'F' => Action{ .Forward = try std.fmt.parseUnsigned(i64, str[1..], 10) },
            else => error.InvalidAction,
        };
    }
};

const Sim = struct {
    x: i64 = 0,
    y: i64 = 0,
    dir: Direction = Direction.East,

    fn step(self: *Sim, action: Action) void {
        switch (action) {
            Action.North => |dy| self.y += dy,
            Action.East => |dx| self.x += dx,
            Action.South => |dy| self.y -= dy,
            Action.West => |dx| self.x -= dx,
            Action.Rotate => |deg| self.dir.rotate(deg),
            Action.Forward => |dist| {
                switch (self.dir) {
                    Direction.North => self.y += dist,
                    Direction.East => self.x += dist,
                    Direction.South => self.y -= dist,
                    Direction.West => self.x -= dist,
                }
            },
        }
    }

    fn run(self: *Sim, actions: []const Action) void {
        for (actions) |action| {
            self.step(action);
        }
    }

    fn manhattanDistance(self: Sim) u64 {
        return std.math.absCast(self.x) + std.math.absCast(self.y);
    }
};

const SimPartTwo = struct {
    ship_x: i64 = 0,
    ship_y: i64 = 0,
    way_x: i64 = 10,
    way_y: i64 = 1,

    fn step(self: *SimPartTwo, action: Action) void {
        switch (action) {
            Action.North => |dy| self.way_y += dy,
            Action.East => |dx| self.way_x += dx,
            Action.South => |dy| self.way_y -= dy,
            Action.West => |dx| self.way_x -= dx,
            Action.Rotate => |deg| {
                // assuming its always a multiple of 90 degrees
                const scalar: i8 = if (deg < 0) -1 else 1;
                switch (std.math.absCast(deg)) {
                    0 => {},
                    90 => {
                        const temp_x = scalar * self.way_y;
                        self.way_y = scalar * -1 * self.way_x;
                        self.way_x = temp_x;
                    },
                    180 => {
                        self.way_x = -1 * self.way_x;
                        self.way_y = -1 * self.way_y;
                    },
                    270 => {
                        const temp_x = scalar * -1 * self.way_y;
                        self.way_y = scalar * self.way_x;
                        self.way_x = temp_x;
                    },
                    else => {
                        // panic!
                        unreachable;
                    },
                }
            },
            Action.Forward => |scalar| {
                self.ship_x += scalar * self.way_x;
                self.ship_y += scalar * self.way_y;
            },
        }
    }

    fn run(self: *SimPartTwo, actions: []const Action) void {
        for (actions) |action| {
            self.step(action);
        }
    }

    fn manhattanDistance(self: SimPartTwo) u64 {
        return std.math.absCast(self.ship_x) + std.math.absCast(self.ship_y);
    }
};

fn parseFile(allocator: *std.mem.Allocator, file_path: []const u8) !std.ArrayList(Action) {
    const inp = try std.fs.cwd().readFileAlloc(allocator, file_path, std.math.maxInt(usize));
    defer allocator.free(inp);

    return parseInput(allocator, inp);
}

fn parseInput(allocator: *std.mem.Allocator, inp: []const u8) !std.ArrayList(Action) {
    var lines = std.mem.tokenize(inp, "\n");

    var res = std.ArrayList(Action).init(allocator);
    errdefer res.deinit();

    while (lines.next()) |line| {
        try res.append(try Action.fromString(line));
    }

    return res;
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

    const actions = try parseFile(allocator, file_path);
    defer actions.deinit();

    var sim = Sim{};
    sim.run(actions.items);

    var sim2 = SimPartTwo{};
    sim2.run(actions.items);

    std.debug.print("Day 12\n", .{});
    std.debug.print("\tPart one: {}\n", .{sim.manhattanDistance()});
    std.debug.print("\tPart two: {}\n", .{sim2.manhattanDistance()});
}

test "example input part one" {
    const inp =
        \\F10
        \\N3
        \\F7
        \\R90
        \\F11
    ;
    const Expected = struct { x: i64, y: i64, dir: Direction };
    const exp_arr = [_]Expected{
        .{ .x = 10, .y = 0, .dir = Direction.East },
        .{ .x = 10, .y = 3, .dir = Direction.East },
        .{ .x = 17, .y = 3, .dir = Direction.East },
        .{ .x = 17, .y = 3, .dir = Direction.South },
        .{ .x = 17, .y = -8, .dir = Direction.South },
    };

    const actions = try parseInput(std.testing.allocator, inp);
    defer actions.deinit();

    var sim = Sim{};
    std.debug.print("\n{}\n", .{sim});

    for (actions.items) |action, idx| {
        const exp = exp_arr[idx];
        sim.step(action);
        std.debug.print("step[{}] (action {}) -> {}\n", .{ idx, action, sim });
        expect(sim.x == exp.x);
        expect(sim.y == exp.y);
        expect(sim.dir == exp.dir);
    }

    expect(sim.manhattanDistance() == 25);

    var sim2 = Sim{};
    sim2.run(actions.items);
    expect(sim2.manhattanDistance() == 25);
}

test "waypoint rotate" {
    var sim = SimPartTwo{};
    expect(sim.way_x == 10);
    expect(sim.way_y == 1);

    sim.step(Action{ .Rotate = 90 });
    expect(sim.way_x == 1);
    expect(sim.way_y == -10);

    sim.step(Action{ .Rotate = 180 });
    expect(sim.way_x == -1);
    expect(sim.way_y == 10);

    sim.step(Action{ .Rotate = -90 });
    expect(sim.way_x == -10);
    expect(sim.way_y == -1);

    sim.step(Action{ .Rotate = 270 });
    expect(sim.way_x == 1);
    expect(sim.way_y == -10);
}

test "example input part two" {
    const inp =
        \\F10
        \\N3
        \\F7
        \\R90
        \\F11
    ;
    const exp_arr = [_][4]i64{
        .{ 100, 10, 10, 1 },
        .{ 100, 10, 10, 4 },
        .{ 170, 38, 10, 4 },
        .{ 170, 38, 4, -10 },
        .{ 214, -72, 4, -10 },
    };

    const actions = try parseInput(std.testing.allocator, inp);
    defer actions.deinit();

    var sim = SimPartTwo{};

    for (actions.items) |action, idx| {
        const exp = exp_arr[idx];
        sim.step(action);
        std.debug.print("step[{}] (action {}) -> {}\n", .{ idx, action, sim });
        expect(sim.ship_x == exp[0]);
        expect(sim.ship_y == exp[1]);
        expect(sim.way_x == exp[2]);
        expect(sim.way_y == exp[3]);
    }

    expect(sim.manhattanDistance() == 286);

    var sim2 = SimPartTwo{};
    sim2.run(actions.items);
    expect(sim2.manhattanDistance() == 286);
}
