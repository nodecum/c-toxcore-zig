const std = @import("std");
const NodeInfo = @import("NodeInfo.zig");
const BootNode = @import("BootNode.zig");
const RespNode = @import("RespNode.zig");
const QueryNode = @import("QueryNode.zig");

pub const std_options = struct {
    // Set the log level to info
    pub const log_level = .info;
};

const localhost = "127.0.0.1";

const boot = NodeInfo{
    .name = "boot-node",
    .secret_key = "EB5782C054AD97D1B353045AEB56F20E94E085FBCC03F4350E33D0E826124DDB",
    .public_key = "E9879C360F953486E4416AA8EB3FB6A64D2F063697B3AED17E13EBD7FCC84A7F",
    .nospam = 0x12345678,
    .address = "E9879C360F953486E4416AA8EB3FB6A64D2F063697B3AED17E13EBD7FCC84A7F123456788896",
    .host = localhost,
    .port = 33445,
};
const resp = NodeInfo{
    .name = "resp-node",
    .secret_key = "07EE9026A567D4A8713222DACF686A40207A9922EEC36E109F9C1BD4DE07D2B8",
    .public_key = "6AF61B03D5668780A0D10F31808BBB07321E2C07B9D319DC4EAC88B638D0282B",
    .nospam = 0x12345678,
    .address = "6AF61B03D5668780A0D10F31808BBB07321E2C07B9D319DC4EAC88B638D0282B123456789BC4",
    .host = localhost,
    .port = 33446,
};
const query = NodeInfo{
    .name = "query-node",
    .secret_key = "3562524D9D1272EA982382BCC094E3C708948CBED7E3F647B31251AB46E57F6B",
    .public_key = "2FA9EF99E15B667A286187F13D7C82A9F9A12E08355BAF2503EEECC19F7ABA0F",
    .nospam = 0x12345678,
    .address = "2FA9EF99E15B667A286187F13D7C82A9F9A12E08355BAF2503EEECC19F7ABA0F123456789495",
    .host = localhost,
    .port = 33447,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var keep_running = true;
    var failure = false;
    var threads: [3]std.Thread = undefined;
    threads[0] = try std.Thread.spawn(
        .{},
        BootNode.run,
        .{ boot, &keep_running, &failure },
    );
    threads[1] = try std.Thread.spawn(
        .{},
        RespNode.run,
        .{ alloc, resp, boot, query, &keep_running, &failure },
    );
    threads[2] = try std.Thread.spawn(
        .{},
        QueryNode.run,
        .{ alloc, query, boot, resp, &keep_running, &failure },
    );

    for (threads) |t| {
        t.join();
    }
    if (failure) {
        std.debug.print("test failed.\n", .{});
    } else {
        std.debug.print("all tests passed.\n", .{});
    }
}
