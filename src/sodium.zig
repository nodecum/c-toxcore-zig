const std = @import("std");

const c = @cImport({
    @cInclude("sodium.h");
});

/// Call this if you use libsodium
/// and have not initialized tox before.
/// returns error.Failed on failure.
pub fn init() !void {
    if (c.sodium_init() < 0) return error.Failed;
}

/// hex size for bin2hex conversion
/// is twice as long plus one (zero terminated)
pub fn hexSizeForBin(bin_size: usize) usize {
    return 2 * bin_size + 1;
}
/// Write byte sequence as hexadecimal string,
/// Returns zero terminated result.
/// hex.len should be greater or equal to hex_size_for_bin(),
/// returns error.BufferTooSmall if this is smaller.
pub fn bin2hex(hex: []u8, bin: []const u8, uppercase: bool) ![:0]const u8 {
    if (hex.len < hexSizeForBin(bin.len))
        return error.BufferTooSmall;
    _ = c.sodium_bin2hex(
        @ptrCast(hex),
        hex.len,
        @ptrCast(bin),
        bin.len,
    );
    if (uppercase) {
        for (0..hex.len - 1) |i| {
            hex[i] = std.ascii.toUpper(hex[i]);
        }
    }
    return hex[0..(hex.len - 1) :0];
}
/// parse hexadecimal string into byte sequence
/// returns error.BufferTooSmall if there is
/// not enough space in bin.
pub fn hex2bin(bin: []u8, hex: []const u8) ![]const u8 {
    var bin_len: usize = 0;
    const n = c.sodium_hex2bin(
        @ptrCast(bin),
        bin.len,
        @ptrCast(hex),
        hex.len,
        null,
        &bin_len,
        null,
    );
    if (n == -1) return error.BufferTooSmall else return bin[0..bin_len];
}

pub const crypto_box = struct {
    pub const public_key_size: usize = c.crypto_box_PUBLICKEYBYTES;
    pub const secret_key_size: usize = c.crypto_box_SECRETKEYBYTES;
    pub fn key_pair(public_key: []u8, secret_key: []u8) !void {
        if ((public_key.len < public_key_size) or
            (secret_key.len < secret_key_size))
        {
            return error.BufferTooSmall;
        }
        if (c.crypto_box_keypair(@ptrCast(public_key), @ptrCast(secret_key)) < 0) {
            return error.Failed;
        }
    }
};
