const std = @import("std");
const Tox = @import("tox");
const sodium = @import("sodium");

const secret_key_hex = "B9103013ABD53075A71E790A386101880655A93AC3D7D50F58961EB0EB57002E";
//the public_key_hex = "364095EFA4EFA86AC8F720A79F2040F830BCC8CFF344EC35E2F8FA4F54641A7C";
const node_port = 33445;

pub fn connectionStatus(status: Tox.ConnectionStatus) void {
    const s = switch (status) {
        .none => "none",
        .tcp => "tcp",
        .udp => "udp",
    };
    std.debug.print("Connection status:{s}\n", .{s});
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

    while (true) {
        tox.iterate({});
        std.time.sleep(tox.iterationInterval() * 1000 * 1000);
    }
}
