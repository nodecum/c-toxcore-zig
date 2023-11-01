const std = @import("std");
const Allocator = std.mem.Allocator;
const Tox = @import("tox");

pub const std_options = struct {
    // Set the log level to info
    pub const log_level = .debug;
};
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    var opt = Tox.Options{};

    const savedata_fn = "savedata.tox";
    var buf: [1024]u8 = undefined;
    const cwd = std.fs.cwd();
    std.debug.print("path: {s}\n", .{try cwd.realpath(".", &buf)});
    if (cwd.openFile(savedata_fn, .{ .mode = .read_only })) |savedata_file| {
        std.debug.print("opening file{s}:\n", .{savedata_fn});
        defer savedata_file.close();
        if (savedata_file.reader().readAllAlloc(alloc, 12400)) |mem| {
            opt.savedata_data = mem[0..mem.len :0];
            opt.savedata_type = .save;
        } else |_| {}
    } else |_| {}
    defer if (opt.savedata_data) |mem| {
        alloc.free(mem);
    };

    var tox = try Tox.init(opt);
    defer tox.deinit();
}
