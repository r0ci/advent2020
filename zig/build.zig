const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) anyerror!void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    const run_step = b.step("run", "Run all the things");
    const test_step = b.step("test", "Test all the things");

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();
    const BuildItem = struct{
        exe_name: []const u8,
        src_name: []const u8
    };
    const BuildVec = std.ArrayList(BuildItem);


    var src_dir = try std.fs.cwd().openDir("src", .{.iterate=true});
    defer src_dir.close();
    var it = src_dir.iterate();

    var to_build = BuildVec.init(b.allocator);
    defer to_build.deinit();

    const sources = [_][3][]const u8 {
        .{"src/day1.zig", "day1", "inputs/day1.txt"},
        .{"src/day2.zig", "day2", "inputs/day2.txt"},
        .{"src/day3.zig", "day3", "inputs/day3.txt"},
    };

    for (sources) |item| {
        const exe = b.addExecutable(item[1], item[0]);
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.install();

        const test_exe = b.addTest(item[0]);
        test_step.dependOn(&test_exe.step);

        const run_cmd = exe.run();
        const args = [_][]const u8{item[2]};
        run_cmd.step.dependOn(b.getInstallStep());
        run_cmd.addArgs(&args);

        run_step.dependOn(&run_cmd.step);
    }
}
