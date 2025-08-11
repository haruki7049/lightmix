const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;

const bad_type = "sample type must be u8, i16, i24, i32, or f32";

/// Converts between PCM and float sample types.
pub fn convert(comptime T: type, value: anytype) T {
    const S = @TypeOf(value);
    if (S == T) {
        return value;
    }

    // PCM uses unsigned 8-bit ints instead of signed. Special case.
    if (S == u8) {
        return convert(T, @as(i8, @bitCast(value -% 128)));
    } else if (T == u8) {
        return @as(u8, @bitCast(convert(i8, value))) +% 128;
    }

    return switch (S) {
        i8, i16, i24, i32 => switch (T) {
            i8, i16, i24, i32 => convertSignedInt(T, value),
            f32 => convertIntToFloat(T, value),
            else => @compileError(bad_type),
        },
        f32 => switch (T) {
            i8, i16, i24, i32 => convertFloatToInt(T, value),
            f32 => value,
            else => @compileError(bad_type),
        },
        else => @compileError(bad_type),
    };
}

fn convertFloatToInt(comptime T: type, value: anytype) T {
    const S = @TypeOf(value);

    const min: S = comptime @floatFromInt(std.math.minInt(T));
    const max: S = comptime @floatFromInt(std.math.maxInt(T));

    // Need lossyCast instead of @floatToInt because float representation of max/min T may be
    // out of range.
    return std.math.lossyCast(T, std.math.clamp(@round(value * (1.0 + max)), min, max));
}

fn convertIntToFloat(comptime T: type, value: anytype) T {
    const S = @TypeOf(value);
    return 1.0 / (1.0 + @as(T, @floatFromInt(std.math.maxInt(S)))) * @as(T, @floatFromInt(value));
}

fn convertSignedInt(comptime T: type, value: anytype) T {
    const S = @TypeOf(value);

    const src_bits = @typeInfo(S).int.bits;
    const dst_bits = @typeInfo(T).int.bits;

    if (src_bits < dst_bits) {
        const shift = dst_bits - src_bits;
        return @as(T, value) << shift;
    } else if (src_bits > dst_bits) {
        const shift = src_bits - dst_bits;
        return @intCast(value >> shift);
    }

    comptime std.debug.assert(S == T);
    return value;
}

fn expectApproxEqualInt(expected: anytype, actual: @TypeOf(expected), tolerance: @TypeOf(expected)) !void {
    const abs = if (expected > actual) expected - actual else actual - expected;
    try std.testing.expect(abs <= tolerance);
}

fn testDownwardsConversions(
    float32: f32,
    uint8: u8,
    int16: i16,
    int24: i24,
    int32: i32,
) !void {
    try expectEqual(uint8, convert(u8, uint8));
    try expectEqual(uint8, convert(u8, int16));
    try expectEqual(uint8, convert(u8, int24));
    try expectEqual(uint8, convert(u8, int32));

    try expectEqual(int16, convert(i16, int16));
    try expectEqual(int16, convert(i16, int24));
    try expectEqual(int16, convert(i16, int32));

    try expectEqual(int24, convert(i24, int24));
    try expectEqual(int24, convert(i24, int32));

    try expectEqual(int32, convert(i32, int32));

    const tolerance: f32 = 0.00001;
    try expectApproxEqAbs(float32, convert(f32, uint8), tolerance * 512.0);
    try expectApproxEqAbs(float32, convert(f32, int16), tolerance * 4.0);
    try expectApproxEqAbs(float32, convert(f32, int24), tolerance * 2.0);
    try expectApproxEqAbs(float32, convert(f32, int32), tolerance);

    try expectApproxEqualInt(uint8, convert(u8, float32), 1);
    try expectApproxEqualInt(int16, convert(i16, float32), 2);
    try expectApproxEqualInt(int24, convert(i24, float32), 2);
    try expectApproxEqualInt(int32, convert(i32, float32), 200);
}

test "sanity test" {
    try testDownwardsConversions(0.0, 0x80, 0, 0, 0);
    try testDownwardsConversions(0.0122069996, 0x81, 0x18F, 0x18FFF, 0x18FFFBB);
    try testDownwardsConversions(0.00274699973, 0x80, 0x5A, 0x5A03, 0x5A0381);
    try testDownwardsConversions(-0.441255282, 0x47, -14460, -3701517, -947588300);

    var uint8: u8 = 0x81;
    try expectEqual(@as(i16, 0x100), convert(i16, uint8));
    try expectEqual(@as(i24, 0x10000), convert(i24, uint8));
    try expectEqual(@as(i32, 0x1000000), convert(i32, uint8));
    var int16: i16 = 0x18F;
    try expectEqual(@as(i24, 0x18F00), convert(i24, int16));
    try expectEqual(@as(i32, 0x18F0000), convert(i32, int16));
    var int24: i24 = 0x18FFF;
    try expectEqual(@as(i32, 0x18FFF00), convert(i32, int24));

    uint8 = 0x80;
    try expectEqual(@as(i16, 0), convert(i16, uint8));
    try expectEqual(@as(i24, 0), convert(i24, uint8));
    try expectEqual(@as(i32, 0), convert(i32, uint8));
    int16 = 0x5A;
    try expectEqual(@as(i24, 0x5A00), convert(i24, int16));
    try expectEqual(@as(i32, 0x5A0000), convert(i32, int16));
    int24 = 0x5A03;
    try expectEqual(@as(i32, 0x5A0300), convert(i32, int24));

    uint8 = 0x47;
    try expectEqual(@as(i16, -14592), convert(i16, uint8));
    try expectEqual(@as(i24, -3735552), convert(i24, uint8));
    try expectEqual(@as(i32, -956301312), convert(i32, uint8));
    int16 = -14460;
    try expectEqual(@as(i24, -3701760), convert(i24, int16));
    try expectEqual(@as(i32, -947650560), convert(i32, int16));
    int24 = -3701517;
    try expectEqual(@as(i32, -947588352), convert(i32, int24));
}
