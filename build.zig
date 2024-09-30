const std = @import("std");
const Build = std.Build;

const APPS = .{
    "key", "show-keys", "local-test", "echo-bot",
};

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const c_toxcore_dep = b.dependency(
        "build-c-toxcore-with-zig",
        .{
            .target = target,
            .optimize = optimize,
            //.static = true,
            //.shared = false,
        },
    );
    const libsodium_dep = b.dependency("libsodium", .{});
    const c_toxcore_lib = c_toxcore_dep.artifact("build-c-toxcore-with-zig");
    const tox = b.addModule("tox", .{
        .root_source_file = b.path("src/tox.zig"),
    });
    tox.addIncludePath(c_toxcore_dep.path("zig-out/include"));
    const sodium = b.addModule("sodium", .{
        .root_source_file = b.path("src/sodium.zig"),
    });
    sodium.addIncludePath(libsodium_dep.path("src/libsodium/include"));
    const test_exe = b.addTest(.{
        .root_source_file = b.path("src/tox.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_exe.linkLibrary(c_toxcore_lib);
    //test_exe.installLibraryHeaders(c_toxcore_lib);
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

        app.linkLibrary(c_toxcore_lib);
        //app.installLibraryHeaders(c_toxcore_lib);

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
