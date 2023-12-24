const std = @import("std");
const Tox = @import("tox");
const sodium = @import("sodium");
const Node = @import("Node.zig");
const NodeInfo = @import("NodeInfo.zig");
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.RespNode);

fn run_(
    allocator: Allocator,
    resp: NodeInfo,
    boot: NodeInfo,
    query: NodeInfo,
    keep_running: *bool,
) !void {
    var node = try Node.init(
        allocator,
        .{
            .name = resp.name,
            .secret_key = resp.secret_key,
            .nospam = resp.nospam,
            .port = resp.port,
            .timeout = resp.timeout,
            .keep_running = keep_running,
        },
    );
    defer node.deinit();
    try node.setName(node.name, "responding your messages");
    var addrBuf: [Tox.address_size * 2]u8 = undefined;
    log.debug("my address is: {s}", .{try node.getAddress(&addrBuf)});
    try node.bootstrap(boot.host, boot.port, boot.public_key);
    _ = try node.friendAddNoRequest(query.address);

    while (@atomicLoad(bool, keep_running, .SeqCst)) {
        node.tox.iterate(&node);
        if (@atomicLoad(bool, keep_running, .SeqCst)) {
            std.time.sleep(node.tox.iterationInterval() * 1000 * 1000);
        }
    }
}

pub fn run(
    allocator: Allocator,
    query: NodeInfo,
    boot: NodeInfo,
    resp: NodeInfo,
    keep_running: *bool,
    failed: *bool,
) void {
    defer @atomicStore(bool, keep_running, false, .SeqCst);
    run_(allocator, query, boot, resp, keep_running) catch |err| {
        log.err("{s}", .{@errorName(err)});
        @atomicStore(bool, failed, true, .SeqCst);
    };
}
