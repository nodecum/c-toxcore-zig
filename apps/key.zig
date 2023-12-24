const std = @import("std");
const sodium = @import("sodium");
const tox = @import("tox");

pub fn main() !void {
    try sodium.init();

    const key_size = sodium.crypto_box.public_key_size;
    const ad_size = tox.address_size;

    var pk: [key_size]u8 = undefined;
    var sk: [key_size]u8 = undefined;
    const ns = @as(u32, 0x12345678);
    var ad: [ad_size]u8 = undefined;

    try sodium.crypto_box.key_pair(&pk, &sk);
    _ = try tox.addressFromPublicKey(&pk, ns, &ad);

    const bytesToHex = std.fmt.fmtSliceHexUpper;

    std.debug.print(".secret_key=\"{s}\",\n", .{bytesToHex(&sk)});
    std.debug.print(".public_key=\"{s}\",\n", .{bytesToHex(&pk)});
    std.debug.print(".nospam=0x{x},\n", .{ns});
    std.debug.print(".address=\"{s}\",\n", .{bytesToHex(&ad)});
}
