const std = @import("std");
const Tox = @import("tox");
const sodium = @import("sodium");
const NodeInfo = @import("NodeInfo.zig");

const log = std.log.scoped(.BootNode);

fn connectionStatus(status: Tox.ConnectionStatus) void {
    const s = switch (status) {
        .none => "none",
        .tcp => "tcp",
        .udp => "udp",
    };
    log.info("connection status: {s}", .{s});
}

fn run_(i: NodeInfo, keep_running: *bool) !void {
    var tox_opt = Tox.Options{};
    var secret_key_bin: [sodium.crypto_box.secret_key_size]u8 = undefined;
    tox_opt.savedata_type = .key;
    tox_opt.savedata_data = @ptrCast(
        try sodium.hex2bin(&secret_key_bin, i.secret_key),
    );
    tox_opt.start_port = i.port;
    var tox = try Tox.init(tox_opt);
    defer tox.deinit();
    tox.setNospam(i.nospam);
    tox.connectionStatusCallback(void, connectionStatus);
    while (@atomicLoad(bool, keep_running, .SeqCst)) {
        tox.iterate({});
        if (@atomicLoad(bool, keep_running, .SeqCst)) {
            std.time.sleep(tox.iterationInterval() * 1000 * 1000);
        }
    }
}

pub fn run(i: NodeInfo, keep_running: *bool, failed: *bool) void {
    defer @atomicStore(bool, keep_running, false, .SeqCst);
    run_(i, keep_running) catch |err| {
        log.err("{s}", .{@errorName(err)});
        @atomicStore(bool, failed, true, .SeqCst);
    };
}
