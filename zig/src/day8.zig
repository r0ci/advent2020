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

const Error = error{ ParseInstr, Unfixable };

const Ops = union(enum) {
    Acc: isize,
    Jmp: isize,
    Nop: isize,

    fn parseInstr(instr: []const u8) !Ops {
        var split = std.mem.split(instr, " ");
        const op_s = split.next().?;
        const arg_s = split.next().?;
        const arg = try std.fmt.parseInt(isize, arg_s, 10);

        if (std.mem.eql(u8, op_s, "acc")) {
            return Ops{ .Acc = arg };
        } else if (std.mem.eql(u8, op_s, "jmp")) {
            return Ops{ .Jmp = arg };
        } else if (std.mem.eql(u8, op_s, "nop")) {
            return Ops{ .Nop = arg };
        } else {
            std.debug.print("\nunreachable?: {}\n", .{op_s});
            return Error.ParseInstr;
        }
    }
};

const Machine = struct {
    accumulator: isize,
    ip: isize,
    ops: std.ArrayList(Ops),
    set: std.ArrayList(u1),

    fn init(allocator: *std.mem.Allocator, instructions: []const u8) !Machine {
        var ops = std.ArrayList(Ops).init(allocator);
        var set = std.ArrayList(u1).init(allocator);
        var it = std.mem.split(instructions, "\n");

        while (it.next()) |instr| {
            if (instr.len == 0) {
                continue;
            }
            try ops.append(try Ops.parseInstr(instr));
            try set.append(0);
        }

        return Machine{
            .accumulator = 0,
            .ip = 0,
            .ops = ops,
            .set = set,
        };
    }

    fn deinit(self: Machine) void {
        self.ops.deinit();
        self.set.deinit();
    }

    fn allVisited(self: Machine) bool {
        for (self.set.items) |bit, i| {
            // std.debug.print("set[{}]: {}\n", .{ i, bit });
            if (bit == 0) {
                return false;
            }
        }
        return true;
    }

    fn run(self: *Machine) bool {
        while (self.ip != self.ops.items.len) {
            const idx = @intCast(usize, self.ip);
            // std.debug.print("ip: {} {} {}\n", .{ self.ip, idx, self.accumulator });
            if (self.set.items[idx] == 1) {
                // std.debug.print("Instruction {} running second time, breaking\n", .{self.ip});
                return false;
            }
            self.set.items[idx] = 1;
            switch (self.ops.items[idx]) {
                Ops.Acc => |arg| {
                    self.accumulator += arg;
                    self.ip += 1;
                },
                Ops.Nop => self.ip += 1,
                Ops.Jmp => |arg| {
                    self.ip += arg;
                },
            }
        }
        return true;
    }

    fn reset(self: *Machine) void {
        std.mem.set(u1, self.set.items, 0);
        self.ip = 0;
        self.accumulator = 0;
    }

    fn bruteForce(self: *Machine) !usize {
        for (self.ops.items) |*op, i| {
            const og = op.*;
            op.* = switch (op.*) {
                Ops.Jmp => |a| Ops{ .Nop = a },
                Ops.Nop => |a| Ops{ .Jmp = a },
                else => continue,
            };
            // if (@TagType(op.*) == Ops.Jmp) {
            //     op.* = Ops{ .Nop = og };
            // } else if (@TagType(op.*) == Ops.Nop) {
            //     op.* = Ops{ .Jmp = og };
            // } else {
            //     continue;
            // }

            if (!self.run()) {
                op.* = og;
                self.reset();
            } else {
                return i;
            }
        }
        return Error.Unfixable;
    }
};

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

    const inp = try readFile(allocator, file_path);
    defer allocator.free(inp);

    var mach = try Machine.init(allocator, inp);
    defer mach.deinit();


    std.debug.print("Day 8:\n", .{});
    _ = mach.run();
    std.debug.print("\tPart one: {}\n", .{mach.accumulator});
    mach.reset();
    _ =try mach.bruteForce();
    std.debug.print("\tPart two: {}\n", .{mach.accumulator});
}

test "example input part one" {
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;
    const inp =
        \\nop +0
        \\acc +1
        \\jmp +4
        \\acc +3
        \\jmp -3
        \\acc -99
        \\acc +1
        \\jmp -4
        \\acc +6
    ;

    var mach = try Machine.init(allocator, inp);
    defer mach.deinit();

    expect(mach.run() == false);
    expect(mach.accumulator == 5);

    expect((try mach.bruteForce()) == 7);
    expect(mach.accumulator == 8);
}

test "example input part two" {
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;
    const inp =
        \\nop +0
        \\acc +1
        \\jmp +4
        \\acc +3
        \\jmp -3
        \\acc -99
        \\acc +1
        \\nop -4
        \\acc +6
    ;

    var mach = try Machine.init(allocator, inp);
    defer mach.deinit();

    expect(mach.run() == true);
    expect(mach.accumulator == 8);
}
