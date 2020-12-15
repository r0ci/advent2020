const std = @import("std");
const expect = std.testing.expect;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;

// comptime max_u36 = std.math.maxInt(u36);
//
const Program = struct {
    // mem: [max_u36]u36 = undefined,
    mem: std.AutoArrayHashMap(u36, u36),
    // split the input mask in two
    or_mask: u36, // the mask's 1 bits
    and_mask: u36, // the mask's 0 bits

    fn init(allocator: *std.mem.Allocator) !Program {
        var mem = std.AutoArrayHashMap(u36, u36).init(allocator);
        errdefer mem.deinit();

        try mem.ensureCapacity(256);

        return Program{
            .mem = mem,
            .or_mask = 0,
            .and_mask = 0,
        };
    }

    fn deinit(self: *Program) void {
        self.mem.deinit();
    }

    fn setMask(self: *Program, one_bits: u36, zero_bits: u36) void {
        self.or_mask = one_bits;
        self.and_mask = std.math.maxInt(u36) ^ zero_bits;
    }

    fn set(self: *Program, addr: u36, value: u36) !void {
        try self.mem.put(addr, (value | self.or_mask) & self.and_mask);
    }

    fn get(self: *Program, addr: u36) u36 {
        return self.mem.get(addr) orelse 0;
    }

    fn sumInitialized(self: *Program) u64 {
        var iter = self.mem.iterator();
        var sum: u64 = 0;
        while (iter.next()) |entry| {
            sum += entry.value;
        }
        return sum;
    }

    fn run(self: *Program, source: []const u8) !u64 {
        var lines = std.mem.tokenize(source, "\n");

        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "mask")) {
                self.handleMaskWrite(line);
            } else if (std.mem.startsWith(u8, line, "mem")) {
                try self.handleMemWrite(line);
            }
        }

        return self.sumInitialized();
    }

    fn handleMaskWrite(self: *Program, line: []const u8) void {
        const mask_start = std.mem.indexOf(u8, line, " = ").? + 3;
        var mask_s = line[mask_start..];

        std.debug.assert(mask_s.len == 36);

        var count: usize = 0;

        var one_bits: u36 = 0;
        var zero_bits: u36 = 0;
        var curr_val: u36 = 1;

        while (count < mask_s.len) : ({
            count += 1;
            curr_val <<= 1;
        }) {
            const byte = mask_s[mask_s.len - count - 1];
            switch (byte) {
                '1' => one_bits ^= curr_val,
                '0' => zero_bits ^= curr_val,
                else => continue,
            }
        }

        self.setMask(one_bits, zero_bits);
    }

    fn handleMemWrite(self: *Program, line: []const u8) !void {
        const addr_start = std.mem.indexOfScalar(u8, line, '[').? + 1;
        const addr_end = std.mem.indexOfScalarPos(u8, line, addr_start, ']').?;
        const val_start = std.mem.indexOf(u8, line, " = ").? + 3;

        const addr = try std.fmt.parseUnsigned(u36, line[addr_start..addr_end], 10);
        const val = try std.fmt.parseUnsigned(u36, line[val_start..], 10);
        try self.set(addr, val);
    }
};

const ProgramV2 = struct {
    mem: std.AutoArrayHashMap(u36, u36),
    or_mask: u36, // the mask's 1 bits
    floating_mask: u36, // the mask's floating (X) bits

    fn init(allocator: *std.mem.Allocator) !ProgramV2 {
        var mem = std.AutoArrayHashMap(u36, u36).init(allocator);
        errdefer mem.deinit();

        try mem.ensureCapacity(256);

        return ProgramV2{
            .mem = mem,
            .or_mask = 0,
            .floating_mask = 0,
        };
    }

    fn deinit(self: *ProgramV2) void {
        self.mem.deinit();
    }

    fn setMask(self: *ProgramV2, one_bits: u36, x_bits: u36) void {
        self.or_mask = one_bits;
        self.floating_mask = x_bits;
    }

    fn set(self: *ProgramV2, addr: u36, value: u36) !void {
        const addr_min = addr | self.or_mask & (std.math.maxInt(u36) ^ self.floating_mask);
        const addr_max = addr_min | self.floating_mask;

        var curr = addr_min;

        // this is naive and slow
        while (curr <= addr_max) : (curr += 1) {
            if (curr & ~self.floating_mask == addr_min) {
                try self.mem.put(curr, value);
            }
        }
    }

    fn get(self: *ProgramV2, addr: u36) u36 {
        return self.mem.get(addr) orelse 0;
    }

    fn sumInitialized(self: *ProgramV2) u64 {
        var iter = self.mem.iterator();
        var sum: u64 = 0;
        while (iter.next()) |entry| {
            sum += entry.value;
        }
        return sum;
    }

    fn run(self: *ProgramV2, source: []const u8) !u64 {
        var lines = std.mem.tokenize(source, "\n");

        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "mask")) {
                self.handleMaskWrite(line);
            } else if (std.mem.startsWith(u8, line, "mem")) {
                try self.handleMemWrite(line);
            }
        }

        return self.sumInitialized();
    }

    fn handleMaskWrite(self: *ProgramV2, line: []const u8) void {
        const mask_start = std.mem.indexOf(u8, line, " = ").? + 3;
        var mask_s = line[mask_start..];

        std.debug.assert(mask_s.len == 36);

        var count: usize = 0;

        var one_bits: u36 = 0;
        var x_bits: u36 = 0;
        var curr_val: u36 = 1;

        while (count < mask_s.len) : ({
            count += 1;
            curr_val <<= 1;
        }) {
            const byte = mask_s[mask_s.len - count - 1];
            switch (byte) {
                '1' => one_bits ^= curr_val,
                'X' => x_bits ^= curr_val,
                else => continue,
            }
        }

        self.setMask(one_bits, x_bits);
    }

    fn handleMemWrite(self: *ProgramV2, line: []const u8) !void {
        const addr_start = std.mem.indexOfScalar(u8, line, '[').? + 1;
        const addr_end = std.mem.indexOfScalarPos(u8, line, addr_start, ']').?;
        const val_start = std.mem.indexOf(u8, line, " = ").? + 3;

        const addr = try std.fmt.parseUnsigned(u36, line[addr_start..addr_end], 10);
        const val = try std.fmt.parseUnsigned(u36, line[val_start..], 10);
        try self.set(addr, val);
    }
};

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

    var prog = try Program.init(allocator);
    defer prog.deinit();

    var prog2 = try ProgramV2.init(allocator);
    defer prog2.deinit();

    std.debug.print("Day 14\n", .{});
    std.debug.print("\tPart one: {}\n", .{try prog.run(inp)});
    std.debug.print("\tPart two: {}\n", .{try prog2.run(inp)});
}

test "example pre parsed" {
    var prog = try Program.init(std.testing.allocator);
    defer prog.deinit();

    prog.setMask(0b1000000, 0b10);

    try prog.set(8, 11);
    expect(prog.get(8) == 73);

    try prog.set(7, 101);
    expect(prog.get(7) == 101);

    try prog.set(8, 0);
    expect(prog.get(8) == 64);

    expect(prog.sumInitialized() == 165);
    // std.debug.print("val: {b}\n", .{val});
}

test "example input" {
    const inp =
        \\mask = XXXXXXXXXXXXXXXXXXXXXXXXXXXXX1XXXX0X
        \\mem[8] = 11
        \\mem[7] = 101
        \\mem[8] = 0
    ;

    var prog = try Program.init(std.testing.allocator);
    defer prog.deinit();
    const sum = try prog.run(inp);

    expect(prog.or_mask == 0b1000000);
    expect(prog.and_mask == std.math.maxInt(u36) ^ 0b10);

    expect(prog.get(7) == 101);
    expect(prog.get(8) == 64);
    expect(sum == 165);
}

test "example pre parsed v2" {
    var prog = try ProgramV2.init(std.testing.allocator);
    defer prog.deinit();

    prog.setMask(0b10010, 0b100001);
    expect(prog.or_mask == 0b10010);
    expect(prog.floating_mask == 0b100001);

    try prog.set(42, 100);
    expect(prog.get(26) == 100);
    expect(prog.get(27) == 100);
    expect(prog.get(58) == 100);
    expect(prog.get(59) == 100);
}

test "example input v2" {
    const inp =
        \\mask = 000000000000000000000000000000X1001X
        \\mem[42] = 100
        \\mask = 00000000000000000000000000000000X0XX
        \\mem[26] = 1
    ;
    var prog = try ProgramV2.init(std.testing.allocator);
    defer prog.deinit();

    const sum = try prog.run(inp);

    expect(prog.or_mask == 0);
    expect(prog.floating_mask == 0b1011);

    expect(prog.get(58) == 100);
    expect(prog.get(59) == 100);
    expect(prog.get(16) == 1);
    expect(prog.get(17) == 1);
    expect(prog.get(18) == 1);
    expect(prog.get(19) == 1);
    expect(prog.get(24) == 1);
    expect(prog.get(25) == 1);
    expect(prog.get(26) == 1);
    expect(prog.get(27) == 1);

    expect(sum == 208);
}
