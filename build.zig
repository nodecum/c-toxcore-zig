const std = @import("std");

const APPS = .{
    "key", "show-keys", "local-test", "echo-bot",
};

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
    const libsodium_dep = b.dependency("libsodium", .{});
    const c_toxcore_lib = c_toxcore_dep.artifact("toxcore");
    const tox = b.addModule("tox", .{
        .source_file = .{ .path = "src/tox.zig" },
    });
    const sodium = b.addModule("sodium", .{
        .source_file = .{ .path = "src/sodium.zig" },
    });

    const test_exe = b.addTest(.{
        .root_source_file = .{ .path = "src/tox.zig" },
        .target = target,
        .optimize = optimize,
    });
    test_exe.linkLibrary(c_toxcore_lib);
    const run_test = b.addRunArtifact(test_exe);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_test.step);

    const all_apps_step = b.step("apps", "Build apps");
    inline for (APPS) |app_name| {
        const app = b.addExecutable(.{
            .name = app_name,
            .root_source_file = .{
                .path = "apps" ++ std.fs.path.sep_str ++ app_name ++ ".zig",
            },
            .target = target,
            .optimize = optimize,
        });
        app.addModule("sodium", sodium);
        app.addModule("tox", tox);

        app.linkLibrary(c_toxcore_lib);
        app.addIncludePath(libsodium_dep.path("src/libsodium/include"));
        var run = b.addRunArtifact(app);
        if (b.args) |args| run.addArgs(args);
        b.step(
            "run-" ++ app_name,
            "Run the " ++ app_name ++ " app",
        ).dependOn(&run.step);

        all_apps_step.dependOn(&app.step);
    }
}
