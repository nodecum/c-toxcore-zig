const std = @import("std");
const sodium = @import("sodium");
const tox = @import("tox");

pub fn main() !void {
    try sodium.init();

    const pk_size = sodium.crypto_box.public_key_size;
    const sk_size = sodium.crypto_box.secret_key_size;
    const ad_size = tox.address_size;

    var pk: [pk_size]u8 = undefined;
    var sk: [sk_size]u8 = undefined;
    var ns: u32 = 0x12345678;
    var ad: [ad_size]u8 = undefined;

    try sodium.crypto_box.key_pair(&pk, &sk);
    _ = try tox.addressFromPublicKey(&pk, ns, &ad);

    const pkh_size = comptime sodium.hexSizeForBin(pk_size);
    const skh_size = comptime sodium.hexSizeForBin(sk_size);
    const adh_size = comptime sodium.hexSizeForBin(ad_size);

    var pkh: [pkh_size]u8 = undefined;
    var skh: [skh_size]u8 = undefined;
    var adh: [adh_size]u8 = undefined;

    std.debug.print(
        ".secret_key=\"{s}\",\n",
        .{try sodium.bin2hex(&skh, &sk, true)},
    );
    std.debug.print(
        ".public_key=\"{s}\",\n",
        .{try sodium.bin2hex(&pkh, &pk, true)},
    );
    std.debug.print(".nospam=0x{x},\n", .{ns});
    std.debug.print(
        ".address=\"{s}\",\n",
        .{try sodium.bin2hex(&adh, &ad, true)},
    );
}
