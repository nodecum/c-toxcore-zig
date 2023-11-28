const std = @import("std");
const Tox = @import("tox");
const sodium = @import("sodium");
const Node = @import("Node.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    var node = try Node.init(
        alloc,
        .{
            .secret_key = "FD0E675DFE9E375FDAE430D239FE7010C9D8822B0C454CC4420FE4644AC7A575",
            //the public_key_hex = "7EBCF35E842C35D9A1AA49999C3B4AC27C41168316B32264254BDF8323673A7C";
            .node_port = 33447,
            .timeout = 10000,
        },
    );
    defer node.deinit();
    // const tox = node.tox;
    try node.setName("test-node", "test the tox api");
    std.debug.print("my address is: {s}\n", .{try node.getAddress()});
    try node.bootstrap(
        "127.0.0.1",
        33445,
        "364095EFA4EFA86AC8F720A79F2040F830BCC8CFF344EC35E2F8FA4F54641A7C",
    );
    const friend_id = try node.addFriendNoRequest(
        "79A0C27CA59DEF95128CD37D1081CAFDA6315F335AC2A8A1B54503251BE8B04712345678B8BB",
    );
    std.debug.print("added friend with id:{d}\n", .{friend_id});

    try Node.check(&node, "friends", friend_id, "name", "response-node");
    try Node.check(&node, "friends", friend_id, "status_message", "responding your messages");
    std.debug.print("all tests passed.\n", .{});
    // while (true) {
    //     tox.iterate(&node);
    //     std.time.sleep(tox.iterationInterval() * 1000 * 1000);
    // }
}
