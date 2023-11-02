const std = @import("std");
const Allocator = std.mem.Allocator;
const Tox = @import("tox");

pub const std_options = struct {
    // Set the log level to info
    pub const log_level = .debug;
};

const savedata_fn = "savedata.tox";
const savedata_tmp_fn = "savedata.tox.tmp";

/// update savedata file
pub fn update_savedata_file(tox: Tox, alloc: Allocator) !void {
    const size = tox.get_savedata_size();
    var mem = try alloc.alloc(u8, size);
    defer alloc.free(mem);
    tox.get_savedata(mem);
    const cwd = std.fs.cwd();
    if (cwd.createFile(savedata_tmp_fn, .{})) |sd_tmp_file| {
        {
            defer sd_tmp_file.close();
            try sd_tmp_file.writeAll(mem);
        }
        try cwd.rename(savedata_tmp_fn, savedata_fn);
    } else |_| {}
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    var opt = Tox.Options{};

    var buf: [1024]u8 = undefined;
    const cwd = std.fs.cwd();
    std.debug.print("path: {s}\n", .{try cwd.realpath(".", &buf)});
    if (cwd.openFile(savedata_fn, .{ .mode = .read_only })) |savedata_file| {
        std.debug.print("opening file:{s}\n", .{savedata_fn});
        defer savedata_file.close();
        if (savedata_file.reader().readAllAlloc(alloc, 12400)) |mem| {
            opt.savedata_data = mem[0..(mem.len - 1) :0];
            opt.savedata_type = .save;
        } else |_| {}
    } else |_| {}
    defer if (opt.savedata_data) |mem| {
        alloc.free(mem);
    };
    var tox = try Tox.init(opt);
    defer tox.deinit();
    var adr = try alloc.alloc(u8, Tox.address_size());
    defer alloc.free(adr);
    try tox.get_address(adr);
    var adrhex = try alloc.alloc(u8, Tox.hex_size_for_bin(Tox.address_size()));
    defer alloc.free(adrhex);

    std.debug.print("my address is: {s}\n", .{try Tox.bin2hex(adrhex, adr, true)});
    try update_savedata_file(tox, alloc);
}
