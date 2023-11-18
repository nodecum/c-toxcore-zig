const std = @import("std");
const Tox = @import("tox");
const sodium = @import("sodium");

const secret_key_hex = "60C1208B8B0693782FF8CC04E6C1C3330A7FA6E908FC239E26138126B50486A8";
//the public_key_hex = "79A0C27CA59DEF95128CD37D1081CAFDA6315F335AC2A8A1B54503251BE8B047";
const node_port = 33446;

const bs_node_public_key_hex = "364095EFA4EFA86AC8F720A79F2040F830BCC8CFF344EC35E2F8FA4F54641A7C";
const bs_node_port = 33445;

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
    const node_name = "response node";
    try tox.setName(node_name);

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
    while (true) {
        tox.iterate({});
        std.time.sleep(tox.iterationInterval() * 1000 * 1000);
    }
}
