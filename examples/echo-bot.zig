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
pub fn updateSavedataFile(tox: Tox, alloc: Allocator) !void {
    const size = tox.getSavedataSize();
    var mem = try alloc.alloc(u8, size);
    defer alloc.free(mem);
    tox.getSavedata(mem);
    const cwd = std.fs.cwd();
    if (cwd.createFile(savedata_tmp_fn, .{})) |sd_tmp_file| {
        {
            defer sd_tmp_file.close();
            try sd_tmp_file.writeAll(mem);
        }
        try cwd.rename(savedata_tmp_fn, savedata_fn);
    } else |_| {}
}

pub fn bootstrap(tox: Tox, alloc: Allocator) !void {
    //const Node = struct {
    //    host: [:0]const u8,
    //    port: u32,
    //    public_key: []const u8,
    //};
    const nodes = [_]std.meta.Tuple(&.{ [:0]const u8, u16, []const u8 }){
        .{
            "85.143.221.42",
            33445,
            "DA4E4ED4B697F2E9B000EEFE3A34B554ACD3F45F5C96EAEA2516DD7FF9AF7B43",
        },
        .{
            "2a04:ac00:1:9f00:5054:ff:fe01:becd",
            33445,
            "DA4E4ED4B697F2E9B000EEFE3A34B554ACD3F45F5C96EAEA2516DD7FF9AF7B43",
        },
        .{
            "78.46.73.141",
            33445,
            "02807CF4F8BB8FB390CC3794BDF1E8449E9A8392C5D3F2200019DA9F1E812E46",
        },
        .{
            "2a01:4f8:120:4091::3",
            33445,
            "02807CF4F8BB8FB390CC3794BDF1E8449E9A8392C5D3F2200019DA9F1E812E46",
        },
        .{
            "tox.initramfs.io",
            33445,
            "3F0A45A268367C1BEA652F258C85F4A66DA76BCAA667A49E770BCC4917AB6A25",
        },
        .{
            "tox2.abilinski.com",
            33445,
            "7A6098B590BDC73F9723FC59F82B3F9085A64D1B213AAF8E610FD351930D052D",
        },
        .{
            "205.185.115.131",
            53,
            "3091C6BEB2A993F1C6300C16549FABA67098FF3D62C6D253828B531470B53D68",
        },
        .{
            "tox.kurnevsky.net",
            33445,
            "82EF82BA33445A1F91A7DB27189ECFC0C013E06E3DA71F588ED692BED625EC23",
        },
    };
    var key_bin = try alloc.alloc(u8, Tox.publicKeySize());

    for (nodes) |node| {
        try tox.bootstrap(
            node[0],
            node[1],
            try Tox.hex2bin(key_bin, node[2]),
        );
    }
}

pub fn connectionStatus(status: Tox.ConnectionStatus) void {
    const s = switch (status) {
        .none => "none",
        .tcp => "tcp",
        .udp => "udp",
    };
    std.debug.print("Connection status:{s}\n", .{s});
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

    tox.connectionStatusCallback({}, connectionStatus);

    const name = "Echo Bot";
    try tox.setName(name);

    const status_message = "Echoing your messages";
    try tox.setStatusMessage(status_message);

    try bootstrap(tox, alloc);

    var adr = try alloc.alloc(u8, Tox.addressSize());
    defer alloc.free(adr);
    try tox.getAddress(adr);
    var adrhex = try alloc.alloc(u8, Tox.hexSizeForBin(Tox.addressSize()));
    defer alloc.free(adrhex);

    std.debug.print("my address is: {s}\n", .{try Tox.bin2hex(adrhex, adr, true)});
    try updateSavedataFile(tox, alloc);

    while (true) {
        tox.iterate({});
        std.time.sleep(tox.iterationInterval() * 1000 * 1000);
    }
}
