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
