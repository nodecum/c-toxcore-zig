const std = @import("std");
const sodium = @import("sodium");

pub fn main() !void {
    try sodium.init();

    const pk_size = sodium.crypto_box.public_key_size;
    const sk_size = sodium.crypto_box.secret_key_size;

    var pk: [pk_size]u8 = undefined;
    var sk: [sk_size]u8 = undefined;

    try sodium.crypto_box.key_pair(&pk, &sk);

    const pkh_size = comptime sodium.hexSizeForBin(pk_size);
    const skh_size = comptime sodium.hexSizeForBin(sk_size);

    var pkh: [pkh_size]u8 = undefined;
    var skh: [skh_size]u8 = undefined;

    std.debug.print(
        "public key:{s}\n",
        .{try sodium.bin2hex(&pkh, &pk, true)},
    );
    std.debug.print(
        "private key:{s}\n",
        .{try sodium.bin2hex(&skh, &sk, true)},
    );
}
