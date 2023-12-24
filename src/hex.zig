const std = @import("std");
const assert = std.debug.assert;

/// Encodes a sequence of bytes as hexadecimal digits.
/// Input an pointer to array which has at least doubled size of input.
pub fn bytesToHexBuf(input: anytype, out: []u8, case: std.fmt.Case) ![]const u8 {
    if (input.len == 0) return &[_]u8{};
    comptime assert(@TypeOf(input[0]) == u8); // elements to encode must be unsigned bytes
    if (out.len < input.len * 2) return error.NotEnoughSpace;

    const charset = "0123456789" ++ if (case == .upper) "ABCDEF" else "abcdef";
    for (input, 0..) |b, i| {
        out[i * 2 + 0] = charset[b >> 4];
        out[i * 2 + 1] = charset[b & 15];
    }
    return out[0 .. input.len * 2];
}
