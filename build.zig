const std = @import("std");
const Build = std.Build;

const APPS = .{
    "key", "show-keys", "local-test", "echo-bot",
};

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep = .{
        .c_toxcore = b.dependency("c-toxcore-build-with-zig", .{ .target = target, .optimize = optimize }),
        .sodium = b.dependency("libsodium", .{ .target = target, .optimize = optimize }),
    };
    const tox = b.addModule("tox", .{
        .root_source_file = b.path("src/tox.zig"),
        .target = target,
        .optimize = optimize,
    });
    tox.addImport("c-toxcore", dep.c_toxcore.module("c-toxcore"));
    const sodium = b.addModule("sodium", .{
        .root_source_file = b.path("src/sodium.zig"),
    });
    sodium.addIncludePath(dep.sodium.path("src/libsodium/include"));
    const test_exe = b.addTest(.{
        .root_source_file = b.path("src/tox.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_exe.root_module.addImport("c-toxcore", dep.c_toxcore.module("c-toxcore"));
    b.installArtifact(test_exe);
    const run_test = b.addRunArtifact(test_exe);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_test.step);

    const all_apps_step = b.step("apps", "Build apps");
    inline for (APPS) |app_name| {
        const app = b.addExecutable(.{
            .name = app_name,
            .root_source_file = b.path("apps" ++ std.fs.path.sep_str ++ app_name ++ ".zig"),
            .target = target,
            .optimize = optimize,
        });
        app.root_module.addImport("sodium", sodium);
        app.root_module.addImport("tox", tox);

        var run = b.addRunArtifact(app);
        b.installArtifact(app);
        if (b.args) |args| run.addArgs(args);
        b.step(
            "run-" ++ app_name,
            "Run the " ++ app_name ++ " app",
        ).dependOn(&run.step);

        all_apps_step.dependOn(&app.step);
    }
}
