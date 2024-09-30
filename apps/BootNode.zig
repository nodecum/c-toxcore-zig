const std = @import("std");
const Tox = @import("tox");
const sodium = @import("sodium");
const NodeInfo = @import("NodeInfo.zig");
const hexToBytes = std.fmt.hexToBytes;
const bytesToHexBuf = Tox.hex.bytesToHexBuf;

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
    _ = try hexToBytes(&secret_key_bin, i.secret_key);
    tox_opt.savedata_data = @ptrCast(secret_key_bin[0..]);
    tox_opt.start_port = i.port;
    var tox = try Tox.init(tox_opt);
    defer tox.deinit();
    tox.setNospam(i.nospam);
    tox.connectionStatusCallback(void, connectionStatus);

    var addr_hex: [Tox.address_size * 2]u8 = undefined;
    var addr_bin: [Tox.address_size]u8 = undefined;
    try tox.getAddress(&addr_bin);
    _ = try bytesToHexBuf(&addr_bin, &addr_hex, .upper);
    log.debug("{s} startup, my address is: {s}", .{ i.name, addr_hex[0..] });

    while (@atomicLoad(bool, keep_running, .seq_cst)) {
        // log.debug("{s} iterate", .{i.name});
        tox.iterate({});
        if (@atomicLoad(bool, keep_running, .seq_cst)) {
            std.time.sleep(tox.iterationInterval() * 1000 * 1000);
        }
    }
}

pub fn run(i: NodeInfo, keep_running: *bool, failed: *bool) void {
    defer @atomicStore(bool, keep_running, false, .seq_cst);
    run_(i, keep_running) catch |err| {
        log.err("{s}", .{@errorName(err)});
        @atomicStore(bool, failed, true, .seq_cst);
    };
}
