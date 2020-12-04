const std = @import("std");
const fs = std.fs;
const expect = std.testing.expect;
const utils = @import("./utils.zig");
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;

fn readFile(allocator: *std.mem.Allocator, path: []const u8) ![]const u8 {
    var line_buf: [2048]u8 = undefined;
    var f = try fs.cwd().openFile(path, .{.read=true, .write=false, .lock=fs.File.Lock.None});
    defer f.close();
    const st = try f.stat();

    return try f.reader().readAllAlloc(allocator, st.size);
}

fn processPassportDump(inp: []const u8, strict: bool) !usize {
    var it = std.mem.split(inp, "\n\n");
    var i: usize = 0;
    var count: usize = 0;

    while (it.next()) |passport| {
        const valid = validatePassport(passport, strict);
        i += 1;
        if (valid) {
            count += 1;
        }
    }
    return count;
}

const ReqKey = struct {
    name: []const u8,
    func: fn(val: []const u8) bool
};

fn validBirthYear(val: []const u8) bool {
    const year = std.fmt.parseInt(u32, val, 10) catch return false;
    return (year >= 1920 and year <= 2002);
}

fn validIssueYear(val: []const u8) bool {
    const year = std.fmt.parseInt(u32, val, 10) catch return false;
    return (year >= 2010 and year <= 2020);
}

fn validExpirationYear(val: []const u8) bool {
    const year = std.fmt.parseInt(u32, val, 10) catch return false;
    return (year >= 2020 and year <= 2030);
}

fn validHeight(val: []const u8) bool {
    const unit = val[val.len-2..];
    const num = std.fmt.parseInt(u8, val[0..val.len-2], 10) catch return false;
    if (std.mem.eql(u8, "in", unit)) {
        return (num >= 59 and num <= 76);
    } else if (std.mem.eql(u8, "cm", unit)) {
        return (num >= 150 and num <= 193);
    }
    return false;
}

fn validHairColor(val: []const u8) bool {
    if (val[0] != '#' or val.len != 7) {
        return false;
    }
    _ = std.fmt.parseInt(u64, val[1..], 16) catch return false;
    return true;
}

fn validEyeColor(val: []const u8) bool {
    const accepted = [_][]const u8{
        "amb", "blu", "brn", "gry", "grn", "hzl", "oth"
    };
    for (accepted) |v| {
        if (std.mem.eql(u8, val, v)) {
            return true;
        }
    }
    return false;
}

fn validPassportID(val: []const u8) bool {
    if (val.len != 9) {
        return false;
    }
    _ = std.fmt.parseInt(u32, val, 10) catch return false;
    return true;
}

const req_keys = [_]ReqKey{
    .{.name = "byr", .func = validBirthYear},
    .{.name = "iyr", .func = validIssueYear},
    .{.name = "eyr", .func = validExpirationYear},
    .{.name = "hgt", .func = validHeight},
    .{.name = "hcl", .func = validHairColor},
    .{.name = "ecl", .func = validEyeColor},
    .{.name = "pid", .func = validPassportID},
};

fn validatePassport(passport: []const u8, strict: bool) bool {
    var found: std.meta.Vector(req_keys.len, bool) = [_]bool{false} ** req_keys.len;

    var nl_it = std.mem.split(passport, "\n");
    while (nl_it.next()) |line| {
        var space_it = std.mem.split(line, " ");

        while (space_it.next()) |chunk| {
            var kv_it = std.mem.split(chunk, ":");
            const key = kv_it.next() orelse return false;
            const val = kv_it.next() orelse return false;

            var i: usize = 0;
            while (i < req_keys.len) : (i += 1) {
                if (std.mem.eql(u8, key, req_keys[i].name)) {
                    if (!strict or req_keys[i].func(val)) {
                        found[i] = true;
                        break;
                    } else {
                    }
                }
            }
        }
    }
    return @reduce(.And, found);
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

    const inp = try readFile(allocator, file_path);
    defer allocator.free(inp);

    std.debug.print("Day 4:\n", .{});
    std.debug.print("\tPart One: {}\n", .{processPassportDump(inp, false)});
    std.debug.print("\tPart Two: {}\n", .{processPassportDump(inp, true)});
}

test "example input" {
    const inp =
        \\ecl:gry pid:860033327 eyr:2020 hcl:#fffffd
        \\byr:1937 iyr:2017 cid:147 hgt:183cm
        \\
        \\iyr:2013 ecl:amb cid:350 eyr:2023 pid:028048884
        \\hcl:#cfa07d byr:1929
        \\
        \\hcl:#ae17e1 iyr:2013
        \\eyr:2024
        \\ecl:brn pid:760753108 byr:1931
        \\hgt:179cm
        \\
        \\hcl:#cfa07d eyr:2025 pid:166559648
        \\iyr:2011 ecl:brn hgt:59in
    ;

    expect((try processPassportDump(inp, false)) == 2);
}

test "example input strict" {
    const valid =
        \\pid:087499704 hgt:74in ecl:grn iyr:2012 eyr:2030 byr:1980
        \\hcl:#623a2f
        \\
        \\eyr:2029 ecl:blu cid:129 byr:1989
        \\iyr:2014 pid:896056539 hcl:#a97842 hgt:165cm
        \\
        \\hcl:#888785
        \\hgt:164cm byr:2001 iyr:2015 cid:88
        \\pid:545766238 ecl:hzl
        \\eyr:2022
        \\
        \\iyr:2010 hgt:158cm hcl:#b6652a ecl:blu byr:1944 eyr:2021 pid:093154719
    ;

    expect((try processPassportDump(valid, true)) == 4);

    const invalid =
        \\eyr:1972 cid:100
        \\hcl:#18171d ecl:amb hgt:170 pid:186cm iyr:2018 byr:1926
        \\
        \\iyr:2019
        \\hcl:#602927 eyr:1967 hgt:170cm
        \\ecl:grn pid:012533040 byr:1946
        \\
        \\hcl:dab227 iyr:2012
        \\ecl:brn hgt:182cm pid:021572410 eyr:2020 byr:1992 cid:277
        \\
        \\hgt:59cm ecl:zzz
        \\eyr:2038 hcl:74454a iyr:2023
        \\pid:3556412378 byr:2007
    ;
    expect((try processPassportDump(invalid, true)) == 0);
}


test "validate trivial" {
    const inp = "byr:1 iyr:2 eyr:3 hgt:4 hcl:5 ecl:6 pid:7 cid:8";
    expect(validatePassport(inp, false));

    const inp2 = "byr:1 iyr:2 eyr:3 hgt:4 hcl:5 ecl:6 pid:7";
    expect(validatePassport(inp2, false));
    
    const inp3 =
        \\byr:1
        \\iyr:2 eyr:3
        \\hgt:4
        \\hcl:5
        \\ecl:6 pid:7
    ;
    expect(validatePassport(inp3, false));

    const inp4 = 
        \\iyr:2 eyr:3
        \\hgt:4
        \\byr:1
        \\hcl:5
        \\ecl:6 pid:7
    ;
    expect(validatePassport(inp4, false));
}

test "invalid trivial" {
    const inp = ""; 
    expect(validatePassport(inp, false) == false);

    const inp2 = "byr:1 eyr:3 hgt:4 hcl:5 ecl:6 pid:7";
    expect(validatePassport(inp2, false) == false);
}

test "birthyear validation" {
    const inp = "1920";
    expect(validBirthYear(inp));

    const inp2 = "2000";
    expect(validBirthYear(inp2));

    const inp3 = "2002";
    expect(validBirthYear(inp3));

    const inp4 = "fail";
    expect(validBirthYear(inp4) == false);
    
    const inp5 = "1800";
    expect(validBirthYear(inp4) == false);

    const inp6 = "2020";
    expect(validBirthYear(inp4) == false);
}

test "issue year validation" {
    const inp = "2010";
    expect(validIssueYear(inp));

    const inp2 = "2015";
    expect(validIssueYear(inp2));

    const inp3 = "2020";
    expect(validIssueYear(inp3));

    const inp4 = "fail";
    expect(validIssueYear(inp4) == false);
    
    const inp5 = "1800";
    expect(validIssueYear(inp4) == false);

    const inp6 = "2030";
    expect(validIssueYear(inp4) == false);
}

test "exp year validation" {
    const inp = "2020";
    expect(validExpirationYear(inp));

    const inp2 = "2025";
    expect(validExpirationYear(inp2));

    const inp3 = "2030";
    expect(validExpirationYear(inp3));

    const inp4 = "fail";
    expect(validExpirationYear(inp4) == false);
    
    const inp5 = "1800";
    expect(validExpirationYear(inp4) == false);

    const inp6 = "2040";
    expect(validExpirationYear(inp4) == false);
}

test "height validation cm" {
    const inp = "150cm";
    expect(validHeight(inp));

    const inp2 = "193cm";
    expect(validHeight(inp2));

    const inp3 = "180cm";
    expect(validHeight(inp3));

    const inp4 = "149cm";
    expect(validHeight(inp4) == false);
    
    const inp5 = "194cm";
    expect(validHeight(inp4) == false);

    const inp6 = "185ccm";
    expect(validHeight(inp4) == false);
}

test "height validation in" {
    const inp = "59in";
    expect(validHeight(inp));

    const inp2 = "76in";
    expect(validHeight(inp2));

    const inp3 = "65in";
    expect(validHeight(inp3));

    const inp4 = "58in";
    expect(validHeight(inp4) == false);
    
    const inp5 = "77in";
    expect(validHeight(inp4) == false);

    const inp6 = "155sin";
    expect(validHeight(inp4) == false);
}

test "hair color validation" {
    const inp = "#0a0a0a";
    expect(validHairColor(inp));

    const inp2 = "#000000";
    expect(validHairColor(inp2));

    const inp3 = "#ffffff";
    expect(validHairColor(inp3));

    const inp4 = "#fffffff";
    expect(validHairColor(inp4) == false);
    
    const inp5 = "ff00ff";
    expect(validHairColor(inp4) == false);

    const inp6 = "#0F0F0F";
    expect(validHairColor(inp4) == false);
}

test "eye color validation" {
    const accepted = [_][]const u8{
        "amb", "blu", "brn", "gry", "grn", "hzl", "oth"
    };
    for (accepted) |v| {
        expect(validEyeColor(v));
    }
    const inp = "bru";
    expect(validHairColor(inp) == false);
}

test "passport id validation" {
    const inp = "012345678";
    expect(validPassportID(inp));

    const inp2 = "000000000";
    expect(validPassportID(inp2));

    const inp3 = "12345678";
    expect(validPassportID(inp3) == false);

    const inp4 = "fail";
    expect(validPassportID(inp4) == false);
    
    const inp5 = "1234567890";
    expect(validPassportID(inp5) == false);
}
