const std = @import("std");

const EXAMPLES = .{
    "echo-bot",
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
    const c_toxcore_lib = c_toxcore_dep.artifact("toxcore");
    const tox = b.addModule("tox", .{
        .source_file = .{ .path = "src/tox.zig" },
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

    const all_example_step = b.step("examples", "Build examples");
    inline for (EXAMPLES) |example_name| {
        const example = b.addExecutable(.{
            .name = example_name,
            .root_source_file = .{ .path = "examples" ++ std.fs.path.sep_str ++ example_name ++ ".zig" },
            .target = target,
            .optimize = optimize,
        });
        example.addModule("tox", tox);
        example.linkLibrary(c_toxcore_lib);

        var run = b.addRunArtifact(example);
        if (b.args) |args| run.addArgs(args);
        b.step("run-" ++ example_name, "Run the " ++ example_name ++ " example").dependOn(&run.step);

        all_example_step.dependOn(&example.step);
    }
}
