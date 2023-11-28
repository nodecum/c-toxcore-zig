const std = @import("std");
const Tox = @import("tox");
const sodium = @import("sodium");

const secret_key_hex = "60C1208B8B0693782FF8CC04E6C1C3330A7FA6E908FC239E26138126B50486A8";
//the public_key_hex = "79A0C27CA59DEF95128CD37D1081CAFDA6315F335AC2A8A1B54503251BE8B047";
const node_port = 33446;

const bs_node_public_key_hex = "364095EFA4EFA86AC8F720A79F2040F830BCC8CFF344EC35E2F8FA4F54641A7C";
const bs_node_port = 33445;

const test_node_address = "7EBCF35E842C35D9A1AA49999C3B4AC27C41168316B32264254BDF8323673A7C12345678FB57";

pub fn connectionStatus(status: Tox.ConnectionStatus) void {
    const s = switch (status) {
        .none => "none",
        .tcp => "tcp",
        .udp => "udp",
    };
    std.debug.print("Connection status:{s}\n", .{s});
}

fn friendName(id: u32, string: []const u8) void {
    std.debug.print("friend name: {d}->{s}\n", .{ id, string });
}

fn friendStatusMessage(id: u32, msg: []const u8) void {
    std.debug.print("friend status message: {d}->{s}\n", .{ id, msg });
}

pub fn main() !void {
    var opt = Tox.Options{};
    var secret_key_bin: [sodium.crypto_box.secret_key_size]u8 = undefined;
    opt.savedata_type = .key;
    opt.savedata_data = @ptrCast(try sodium.hex2bin(&secret_key_bin, secret_key_hex));
    opt.start_port = node_port;

    var tox = try Tox.init(opt);
    defer tox.deinit();

    tox.connectionStatusCallback({}, connectionStatus);
    tox.friend.nameCallback({}, friendName);
    tox.friend.statusMessageCallback({}, friendStatusMessage);
    const node_name = "response-node";
    try tox.setName(node_name);
    tox.setNospam(0x12345678);

    const status_message = "responding your messages";
    try tox.setStatusMessage(status_message);

    var bs_node_public_key_bin: [sodium.crypto_box.public_key_size]u8 = undefined;
    try tox.bootstrap(
        "127.0.0.1",
        bs_node_port,
        try sodium.hex2bin(
            &bs_node_public_key_bin,
            bs_node_public_key_hex,
        ),
    );

    var addr_bin: [Tox.address_size]u8 = undefined;
    try tox.getAddress(&addr_bin);
    var addr_hex: [sodium.hexSizeForBin(Tox.address_size)]u8 = undefined;
    std.debug.print(
        "{s} address: {s}\n",
        .{
            node_name,
            try sodium.bin2hex(&addr_hex, &addr_bin, true),
        },
    );

    var tn_addr_bin: [Tox.address_size]u8 = undefined;
    _ = try sodium.hex2bin(&tn_addr_bin, test_node_address);

    const tn_id = try tox.friend.addNoRequest(&tn_addr_bin);
    std.debug.print("added friend with id:{d}\n", .{tn_id});

    while (true) {
        tox.iterate({});
        std.time.sleep(tox.iterationInterval() * 1000 * 1000);
    }
}
