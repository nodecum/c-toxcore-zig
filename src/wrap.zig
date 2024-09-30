// wrap utils
const std = @import("std");
const Type = std.builtin.Type;
const c = @cImport({
    @cInclude("toxcore/tox.h");
});

pub fn ErrSet(comptime ErrEnum: type) type {
    const enum_fields = @typeInfo(ErrEnum).@"enum".fields;
    // We count all enum fields which are not named 'Ok',
    // this will be the size of the new error set.
    comptime var n = 0;
    for (enum_fields) |f| {
        if (!std.mem.eql(u8, f.name, "Ok")) n += 1;
    }
    comptime var err_fields: [n]Type.Error = undefined;
    // now we set the names, ommiting the 'Ok'
    comptime var i = 0;
    inline for (enum_fields) |f| {
        if (!std.mem.eql(u8, f.name, "Ok")) {
            err_fields[i].name = f.name;
            i += 1;
        }
    }
    return @Type(Type{ .error_set = &err_fields });
}

fn getEnumValue(
    comptime field_name: []const u8,
    comptime fields: []const Type.EnumField,
) comptime_int {
    for (fields) |f| {
        if (std.mem.eql(u8, f.name, field_name)) {
            return f.value;
        }
    }
}

/// translating C errors (c enums) to zig errors.
/// this function returns an error if the c enum value 'cerr'
/// which corresponds to an zig enum is not named 'Ok'.
pub fn checkErr(cerr: anytype, comptime ErrEnum: type) ErrSet(ErrEnum)!void {
    const enum_fields = @typeInfo(ErrEnum).@"enum".fields;
    // let us find which enum field has the name 'Ok',
    // we check for this value first to have the normal case
    // be handled fast.
    const ok_value = getEnumValue("Ok", enum_fields);
    if (cerr == ok_value) return {};
    const err_set_t = ErrSet(ErrEnum);
    const err_set = @typeInfo(err_set_t).error_set.?;
    // now return errors
    inline for (err_set) |f| {
        // find the value for the name
        const value = getEnumValue(f.name, enum_fields);
        if (cerr == value) {
            return @field(err_set_t, f.name);
        }
    }
}

pub fn getResult(
    comptime fct: anytype,
    self: anytype,
    args: anytype,
    comptime err_enum: anytype,
) !@typeInfo(@TypeOf(fct)).@"fn".return_type.? {
    // get the Error type
    const Err = @typeInfo(@typeInfo(@TypeOf(fct)).@"fn".params[args.len + 1].type.?).pointer.child;
    var err: Err = 0;
    const result = @call(.auto, fct, .{self.handle} ++ args ++ .{&err});
    try checkErr(err, err_enum);
    return result;
}

pub fn fillBuffer(
    comptime fct: anytype,
    self: anytype,
    args: anytype,
    buf: []u8,
    fill_len: usize,
    comptime err_enum: anytype,
) ![]const u8 {
    if (buf.len < fill_len)
        return error.BufferTooSmall;
    // get the Error type
    const Err = @typeInfo(@typeInfo(@TypeOf(fct)).@"fn".params[args.len + 2].type.?).pointer.child;
    var err: Err = 0;
    _ = @call(.auto, fct, .{self.handle} ++ args ++ .{ @as([*c]u8, @ptrCast(buf)), &err });
    try checkErr(err, err_enum);
    return buf[0..fill_len];
}

/// Callbacks
fn CallbackHandle(comptime Args: []const type, comptime Context: type) type {
    comptime var n = Args.len;
    if (Context != void) n += 1; // number of arguments
    comptime var params: [n]Type.Fn.Param = undefined;
    comptime var idx0 = 0;
    if (Context != void) {
        params[0] = .{ .type = Context, .is_generic = false, .is_noalias = false };
        idx0 = 1;
    }
    for (Args, idx0..) |arg, i| {
        params[i] = .{ .type = arg, .is_generic = false, .is_noalias = false };
    }
    return @Type(Type{
        .@"fn" = .{
            .calling_convention = .Unspecified,
            //.alignment = 0,
            .is_generic = false,
            .is_var_args = false,
            .return_type = void,
            .params = &params,
        },
    });
}

fn ZigToC(comptime T: type) type {
    const i = @typeInfo(T);
    return switch (i) {
        .@"enum" => i.@"enum".tag_type,
        .bool, .int, .float => T,
        else => @compileError("unimplemented conversion for " ++ @typeName(T)),
    };
}

fn cToZig(cv: anytype, comptime zy: type) zy {
    const cy = @TypeOf(cv);
    const ci = @typeInfo(cy);
    const zi = @typeInfo(zy);
    if (cy == zy) {
        return cv;
    } else if (zi == .pointer) {
        const zpy = zi.pointer.child;
        if (zi.pointer.size == .Slice) {
            if (ci == .@"struct" and ci.@"struct".is_tuple) {
                // tuple of 2 args
                if (cv.len == 2) {
                    // first argument
                    const cv0 = cv[0];
                    const cy0 = @TypeOf(cv0);
                    const ci0 = @typeInfo(cy0);
                    const cv1 = cv[1];
                    const cy1 = @TypeOf(cv1);
                    const ci1 = @typeInfo(cy1);
                    if ((ci0 == .pointer and ci0.pointer.size == .C) and
                        (ci0.pointer.child == zpy) and
                        ((ci1 == .int) or (ci1 == .comptime_int)))
                    {
                        // Pointer and length => slice
                        return @as(zy, cv0[0..cv1]);
                    }
                }
            }
        } else if (zi.pointer.size == .One) {
            return @as(zy, @ptrFromInt(@intFromPtr(cv)));
            //if (ci == .pointer and ci.pointer.size == .C) {
            //    return @as(zy, @ptrFromInt(@intFromPtr(cv)));
            // }
        }
    } else if (zi == .@"enum") {
        if (ci == .int or ci == .comptime_int) {
            return @as(zy, @enumFromInt(cv));
        }
    }
    @compileError("unimplemented conversion from " ++ @typeName(cy) ++ " to " ++ @typeName(zy));
}

test "C to Zig" {
    const s0: [*c]const u8 = "Hi";
    const s1 = cToZig(.{ s0, 2 }, []const u8);
    try std.testing.expectEqualStrings("Hi", s1);
}

/// From the parameter description get the C types.
fn CTypes(comptime args: anytype) []const type {
    const args_ty = @TypeOf(args);
    const args_ti = @typeInfo(args_ty);
    if (!(args_ti == .@"struct" and args_ti.@"struct".is_tuple)) {
        @compileError("expected tuple argument, found " ++ @typeName(args_ty));
    }
    comptime var n = 0;
    for (args) |a| {
        const a_ti = @typeInfo(@TypeOf(a));
        if (a_ti == .@"struct" and a_ti.@"struct".is_tuple) {
            // we drop the first, this is the Zig type
            for (1..a.len) |i| {
                // plain types are the c arguments
                if (@TypeOf(a[i]) == type) n += 1;
            }
        } else {
            n += 1;
        }
    }
    comptime var Res: [n]type = undefined;
    n = 0;
    for (args) |a| {
        const a_ti = @typeInfo(@TypeOf(a));
        if (a_ti == .@"struct" and a_ti.@"struct".is_tuple) {
            // we drop the first, this is the Zig type
            for (1..a.len) |i| {
                const b = a[i];
                if (@TypeOf(b) == type) {
                    Res[n] = b;
                    n += 1;
                }
            }
        } else {
            Res[n] = ZigToC(a);
            n += 1;
        }
    }
    return &Res;
}

/// get zig types from Arguments description
fn ZigTypes(comptime args: anytype) []const type {
    const args_ty = @TypeOf(args);
    const args_ti = @typeInfo(args_ty);
    if (!(args_ti == .@"struct" and args_ti.@"struct".is_tuple)) {
        @compileError("expected tuple argument, found " ++ @typeName(args_ty));
    }
    comptime var Res: [args.len]type = undefined;
    inline for (args, 0..) |a, i| {
        const a_ty = @TypeOf(a);
        const a_ti = @typeInfo(a_ty);
        if (a_ti == .@"struct" and a_ti.@"struct".is_tuple) {
            // the first member of the tuple is the
            // argument for the zig call
            Res[i] = a[0];
        } else {
            Res[i] = a;
        }
    }
    return &Res;
}

fn zigValues(
    comptime args: anytype,
    c_args: anytype,
    e_args: anytype,
) std.meta.Tuple(ZigTypes(args)) {
    const args_ty = @TypeOf(args);
    const args_ti = @typeInfo(args_ty);
    if (!(args_ti == .@"struct" and args_ti.@"struct".is_tuple)) {
        @compileError("expected tuple argument, found " ++ @typeName(args_ty));
    }

    var res: std.meta.Tuple(ZigTypes(args)) = undefined;
    comptime var ci = 0;
    comptime var ei = 0;
    inline for (args, 0..) |a, i| {
        const a_ty = @TypeOf(a);
        const a_ti = @typeInfo(a_ty);
        if (a_ti == .@"struct" and a_ti.@"struct".is_tuple) {
            comptime var d: [a.len - 1]type = undefined;
            inline for (1..a.len, 0..) |j, k| {
                const b = a[j];
                const b_ty = @TypeOf(b);
                const b_ti = @typeInfo(b);
                if (b_ti == .@"struct" and b_ti.@"struct".is_tuple) {
                    d[k] = b[0];
                } else if (b_ty == type) {
                    d[k] = b;
                } else {
                    @compileError("expected either an type or tuple, found " ++ @typeName(b_ty));
                }
            }
            // create the conversion tuple arg
            var tuple: std.meta.Tuple(&d) = undefined;
            inline for (1..a.len, 0..) |j, k| {
                const b = a[j];
                const b_ty = @TypeOf(b);
                const b_ti = @typeInfo(b_ty);
                if (b_ty == type) {
                    tuple[k] = c_args[ci];
                    ci += 1;
                } else if (b_ti == .@"struct" and b_ti.@"struct".is_tuple) {
                    tuple[k] = e_args[ei];
                    ei += 1;
                }
            }
            res[i] = cToZig(tuple, a[0]);
        } else {
            // no tuple
            res[i] = cToZig(c_args[ci], a);
            ci += 1;
        }
    }
    return res;
}

fn callHandle(
    comptime Ctx: type,
    Args: anytype,
    comptime hd: CallbackHandle(ZigTypes(Args), Ctx),
    c_args: anytype,
    e_args: anytype,
    ctx: anytype,
) void {
    const zv = zigValues(Args, c_args, e_args);
    if (Ctx == void) {
        @call(.auto, hd, zv);
    } else {
        @call(.auto, hd, .{cToZig(ctx, Ctx)} ++ zv);
    }
}

pub fn setCallback(
    self: anytype,
    comptime Ctx: type,
    fct: anytype,
    comptime Args: anytype,
    e_args: anytype,
    comptime hd: CallbackHandle(ZigTypes(Args), Ctx),
) void {
    const H = switch (CTypes(Args).len) {
        1 => struct {
            fn cb(_: ?*c.Tox, c0: CTypes(Args)[0], cx: ?*anyopaque) callconv(.C) void {
                callHandle(Ctx, Args, hd, .{c0}, e_args, cx);
            }
        },
        2 => struct {
            fn cb(_: ?*c.Tox, c0: CTypes(Args)[0], c1: CTypes(Args)[1], cx: ?*anyopaque) callconv(.C) void {
                callHandle(Ctx, Args, hd, .{ c0, c1 }, e_args, cx);
            }
        },
        3 => struct {
            fn cb(_: ?*c.Tox, c0: CTypes(Args)[0], c1: CTypes(Args)[1], c2: CTypes(Args)[2], cx: ?*anyopaque) callconv(.C) void {
                callHandle(Ctx, Args, hd, .{ c0, c1, c2 }, e_args, cx);
            }
        },
        4 => struct {
            fn cb(_: ?*c.Tox, c0: CTypes(Args)[0], c1: CTypes(Args)[1], c2: CTypes(Args)[2], c3: CTypes(Args)[3], cx: ?*anyopaque) callconv(.C) void {
                callHandle(Ctx, Args, hd, .{ c0, c1, c2, c3 }, e_args, cx);
            }
        },
        else => struct {},
    };
    fct(self.handle, H.cb);
}
