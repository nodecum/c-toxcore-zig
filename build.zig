const std = @import("std");

pub fn build(b: *std.Build) !void {
    const root_path = b.pathFromRoot(".");
    var cwd = try std.fs.openDirAbsolute(root_path, .{});
    defer cwd.close();

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const c_toxcore_dep = b.dependency(
        "c-toxcore",
        .{
            .target = target,
            .optimize = optimize,
            .static = true,
            .shared = false,
        },
    );

    //const module
    const tox = b.addModule("tox", .{
        .source_file = .{ .path = "src/tox.zig" },
    });

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tox.zig" },
        .target = target,
        .optimize = optimize,
    });
    tests.linkLibrary(c_toxcore_dep.artifact("toxcore"));

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&tests.step);

    _ = tox;
}
