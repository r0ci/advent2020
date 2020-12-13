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

const Contains = struct {
    count: usize,
    idx: usize,
};

const Bag = struct {
    contains: std.ArrayList(Contains),
    contained_by: std.ArrayList(usize),
    name: []const u8,
    visited: bool = false,

    fn init(allocator: *std.mem.Allocator, name: []const u8) Bag {
        var contains = std.ArrayList(Contains).init(allocator);
        var contained_by = std.ArrayList(usize).init(allocator);

        return Bag{
            .contains = contains,
            .contained_by = contained_by,
            .name = name,
        };
    }

    fn deinit(self: *Bag) void {
        self.contained_by.deinit();
        self.contains.deinit();
    }

    fn addContains(self: *Bag, bag_idx: usize, count: usize) !void {
        try self.contains.append(.{ .count = count, .idx = bag_idx });
    }

    fn addContainedBy(self: *Bag, bag_idx: usize) !void {
        try self.contained_by.append(bag_idx);
    }
};

const BagGraph = struct {
    allocator: *std.mem.Allocator,
    // map of name -> index in storage
    map: std.StringHashMap(usize),
    storage: std.ArrayList(Bag),

    fn init(allocator: *std.mem.Allocator) BagGraph {
        return BagGraph{
            .allocator = allocator,
            .map = std.StringHashMap(usize).init(allocator),
            .storage = std.ArrayList(Bag).init(allocator),
        };
    }

    fn deinit(self: *BagGraph) void {
        self.map.deinit();
        for (self.storage.items) |*bag| {
            bag.deinit();
        }
        self.storage.deinit();
    }

    fn getOrAddBag(self: *BagGraph, name: []const u8) !usize {
        return self.map.get(name) orelse {
            const idx = self.storage.items.len;
            var bag = Bag.init(self.allocator, name);
            errdefer bag.deinit();

            try self.storage.append(bag);
            errdefer _ = self.storage.pop();

            try self.map.putNoClobber(name, idx);

            return idx;
        };
    }

    fn dfsContainedByHelper(self: *BagGraph, idx: usize) usize {
        var bag: *Bag = &self.storage.items[idx];
        if (bag.visited) {
            return 0;
        }
        bag.visited = true;

        var sum: usize = 1;
        for (bag.contained_by.items) |next_idx| {
            sum += self.dfsContainedByHelper(next_idx);
        }

        return sum;
    }

    // count number of unique bags that can contain root
    fn dfsCountContainedBy(self: *BagGraph, root: []const u8) usize {
        const idx: usize = self.map.get(root).?;
        var bag: *Bag = &self.storage.items[idx];
        bag.visited = true;

        var sum: usize = 0;
        for (bag.contained_by.items) |next_idx| {
            sum += self.dfsContainedByHelper(next_idx);
        }

        return sum;
    }

    fn dfsContainsHelper(self: *BagGraph, idx: usize) usize {
        const bag: Bag = self.storage.items[idx];

        // if (bag.contains.items.len == 0) {
        //     return 1;
        // }

        var sum: usize = 1;
        for (bag.contains.items) |c| {
            sum += (self.dfsContainsHelper(c.idx)) * c.count;
        }

        return sum;
    }

    fn dfsCountContains(self: *BagGraph, root: []const u8) usize {
        const idx: usize = self.map.get(root).?;
        const bag: Bag = self.storage.items[idx];

        var sum: usize = 0;
        for (bag.contains.items) |c| {
            sum += self.dfsContainsHelper(c.idx) * c.count;
        }

        return sum;
    }

    fn linkBags(self: *BagGraph, container_idx: usize, count: usize, containee_idx: usize) !void {
        var container = &self.storage.items[container_idx];
        try container.addContains(containee_idx, count);
        var containee = &self.storage.items[containee_idx];
        try containee.addContainedBy(container_idx);
    }

    fn parseRuleSet(self: *BagGraph, rules: []const u8) !void {
        var lines_it = std.mem.tokenize(rules, "\n");
        while (lines_it.next()) |line| {
            // muted lime bags contain 1 wavy lime bag, 1 vibrant green bag, 3 light yellow bags.
            // dotted teal bags contain no other bags.
            var words = std.mem.tokenize(line, " ");
            var split = std.mem.split(line, " contain ");
            const first_half = split.next().?;
            const second_half = split.next().?;

            const containing_name = substring(first_half, " bag");
            // This will add the bag to storage if it doesnt already exist
            const containing_idx = try self.getOrAddBag(containing_name);

            // If this is a leaf bag we can skip the rest of the line
            if (std.mem.startsWith(u8, second_half, "no other bags")) continue;

            var containee_it = std.mem.split(second_half, ", ");
            while (containee_it.next()) |containee_str| {
                // each slice will end up with
                // 'N adj color bag(s)(.)'
                // where the s and period are optional

                // get past the numeric count (for now we dont care)
                var num_split = std.mem.split(containee_str, " ");
                const count_s = num_split.next().?;
                const count = try std.fmt.parseUnsigned(usize, count_s, 10);

                // take the rest and substring up to needle ' bag'
                const containee_name = substring(num_split.rest(), " bag");
                const containee_idx = try self.getOrAddBag(containee_name);
                try self.linkBags(containing_idx, count, containee_idx);
            }
        }
    }
};

fn substring(str: []const u8, sub: []const u8) []const u8 {
    return str[0..std.mem.indexOf(u8, str, sub).?];
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

    var graph = BagGraph.init(allocator);
    defer graph.deinit();

    try graph.parseRuleSet(inp);

    std.debug.print("Day 7:\n", .{});
    std.debug.print("\tPart one: {}\n", .{graph.dfsCountContainedBy("shiny gold")});
    std.debug.print("\tPart two: {}\n", .{graph.dfsCountContains("shiny gold")});
}

test "example input part one" {
    const inp =
        \\light red bags contain 1 bright white bag, 2 muted yellow bags.
        \\dark orange bags contain 3 bright white bags, 4 muted yellow bags.
        \\bright white bags contain 1 shiny gold bag.
        \\muted yellow bags contain 2 shiny gold bags, 9 faded blue bags.
        \\shiny gold bags contain 1 dark olive bag, 2 vibrant plum bags.
        \\dark olive bags contain 3 faded blue bags, 4 dotted black bags.
        \\vibrant plum bags contain 5 faded blue bags, 6 dotted black bags.
        \\faded blue bags contain no other bags.
        \\dotted black bags contain no other bags.
    ;

    var bags = BagGraph.init(std.testing.allocator);
    defer bags.deinit();

    try bags.parseRuleSet(inp);
    expect(bags.storage.items.len == 9);
    const count = bags.dfsCountContainedBy("shiny gold");
    expect(count == 4);
}

test "example input part two" {
    const inp =
        \\shiny gold bags contain 2 dark red bags.
        \\dark red bags contain 2 dark orange bags.
        \\dark orange bags contain 2 dark yellow bags.
        \\dark yellow bags contain 2 dark green bags.
        \\dark green bags contain 2 dark blue bags.
        \\dark blue bags contain 2 dark violet bags.
        \\dark violet bags contain no other bags.
    ;

    var bags = BagGraph.init(std.testing.allocator);
    defer bags.deinit();

    try bags.parseRuleSet(inp);
    const count = bags.dfsCountContains("shiny gold");
    expect(count == 126);
}
