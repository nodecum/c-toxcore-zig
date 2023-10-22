const c = @cImport({
    @cInclude("toxcore/tox.h");
});

pub const Tox = struct {
    handle: *c.Tox,

    pub fn new() !Tox {
        var self: Tox = Tox{ .handle = undefined };
        var options: c.struct_Tox_Options = undefined;
        var err: c.Tox_Err_New = undefined;
        const maybe_tox = c.tox_new(&options, &err);
        if (maybe_tox) |tox| {
            self.handle = tox;
        } else {
            return error.ToxNewFailed;
        }
        return self;
    }

    pub fn kill(self: Tox) void {
        c.tox_kill(self.handle);
    }
};

test "tox_new" {
    var tox = try Tox.new();
    defer tox.kill();
}
