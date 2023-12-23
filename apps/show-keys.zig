const std = @import("std");
const Allocator = std.mem.Allocator;
const Tox = @import("tox");
const sodium = @import("sodium");

const savedata_fn = "toxic_profile.tox";

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

    const key_size = sodium.crypto_box.public_key_size;

    var sk: [key_size]u8 = undefined;
    var pk: [key_size]u8 = undefined;
    _ = try tox.getSecretKey(&sk);
    _ = try tox.getPublicKey(&pk);

    const bytesToHex = std.fmt.fmtSliceHexUpper;
    std.debug.print(
        ".secret_key=\"{s}\",\n",
        .{bytesToHex(&sk)},
    );
    std.debug.print(
        ".public_key=\"{s}\",\n",
        .{bytesToHex(&pk)},
    );
}
