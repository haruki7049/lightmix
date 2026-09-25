const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

test "read sine.wav" {
    const allocator = std.testing.allocator;
    var reader = std.Io.Reader.fixed(@embedFile("./assets/sine.wav"));

    const sine = try Wave(f64).read(.wav, allocator, &reader);
    defer sine.deinit();

    const expected_samples: []const f64 = &[_]f64{
        0,
        0.05011139255958739,
        0.1000396740623188,
        0.14960173345133823,
        0.19849238563188573,
        0.24665059358500932,
        0.293954283272805,
        0.33979308450575274,
        0.3847468489638966,
        0.42771691030610065,
        0.4693441572313608,
        0.5090182195501571,
        0.5465865047151097,
        0.5822626422925504,
        0.6153447065645314,
        0.6462599566637165,
    };
    try std.testing.expectEqualSlices(f64, expected_samples, sine.samples[0..16]);
}

test "read truncated wav stream returns error" {
    const allocator = std.testing.allocator;

    // Completely empty stream
    {
        var reader = std.Io.Reader.fixed("");
        try std.testing.expectError(error.InvalidFormat, Wave(f64).read(.wav, allocator, &reader));
    }

    // Truncated header (only 4 bytes)
    {
        var reader = std.Io.Reader.fixed("RIFF");
        try std.testing.expectError(error.InvalidFormat, Wave(f64).read(.wav, allocator, &reader));
    }

    // Truncated valid WAV file
    {
        const full_sine = @embedFile("./assets/sine.wav");
        var reader = std.Io.Reader.fixed(full_sine[0 .. full_sine.len / 2]);
        _ = Wave(f64).read(.wav, allocator, &reader) catch {
            return;
        };
        return error.ExpectedError;
    }
}

test "zero-length wave operations" {
    const allocator = std.testing.allocator;
    const empty_samples: []const f64 = &[_]f64{};

    const wave = try Wave(f64).init(empty_samples, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    // to_channels on empty wave
    const converted = try wave.to_channels(2, .{});
    defer converted.deinit();
    try std.testing.expectEqual(converted.samples.len, 0);

    // separate on empty wave should return error
    try std.testing.expectError(error.SeparatingZeroLengthWave, wave.separate(.{
        .allocator = allocator,
        .separate_point = 0,
    }));

    // fill_zero_to_end with 0, 0
    const filled = try wave.fill_zero_to_end(0, 0);
    defer filled.deinit();
    try std.testing.expectEqual(filled.samples.len, 0);
}

test "floating-point precision boundary testing for f80 and f128" {
    const allocator = std.testing.allocator;

    // f80 testing
    {
        const samples_f80: []const f80 = &[_]f80{ 0.1234567890123456789, -0.9876543210987654321 };
        const wave_f80 = try Wave(f80).init(samples_f80, allocator, .{
            .sample_rate = 48000,
            .channels = 2,
        });
        defer wave_f80.deinit();

        const cloned_f80 = try wave_f80.clone(null);
        defer cloned_f80.deinit();
        try std.testing.expectEqualSlices(f80, wave_f80.samples, cloned_f80.samples);
    }

    // f128 testing
    {
        const samples_f128: []const f128 = &[_]f128{ 0.12345678901234567890123456789, -0.98765432109876543210987654321 };
        const wave_f128 = try Wave(f128).init(samples_f128, allocator, .{
            .sample_rate = 96000,
            .channels = 2,
        });
        defer wave_f128.deinit();

        const cloned_f128 = try wave_f128.clone(null);
        defer cloned_f128.deinit();
        try std.testing.expectEqualSlices(f128, wave_f128.samples, cloned_f128.samples);
    }
}

test "read sine.wav as f32 matches f64 within f32 precision" {
    const allocator = std.testing.allocator;
    var reader32 = std.Io.Reader.fixed(@embedFile("./assets/sine.wav"));
    const sine32 = try Wave(f32).read(.wav, allocator, &reader32);
    defer sine32.deinit();
    var reader64 = std.Io.Reader.fixed(@embedFile("./assets/sine.wav"));
    const sine64 = try Wave(f64).read(.wav, allocator, &reader64);
    defer sine64.deinit();

    try std.testing.expectEqual(sine64.samples.len, sine32.samples.len);
    try std.testing.expectEqual(sine64.sample_rate, sine32.sample_rate);
    try std.testing.expectEqual(sine64.channels, sine32.channels);
    for (sine64.samples, sine32.samples) |expected, actual| {
        try std.testing.expectApproxEqAbs(@as(f32, @floatCast(expected)), actual, 1e-6);
    }
}

test "f32 samples survive a write and a read in every WAV sample format" {
    const allocator = std.testing.allocator;
    const samples = [_]f32{ 0.0, 0.25, -0.25, 0.5, -0.5, 0.999, -0.999, 0.123456 };

    // Unsigned 8-bit PCM has a step of 1/128; every other format is much finer.
    const cases = .{
        .{ 8, .pcm, 1.0 / 128.0 },
        .{ 16, .pcm, 1.0 / 32768.0 },
        .{ 24, .pcm, 1.0 / 8388608.0 },
        .{ 32, .pcm, 1e-6 },
        .{ 32, .ieee_float, 0.0 },
        .{ 64, .ieee_float, 0.0 },
    };
    inline for (cases) |case| {
        const wave = try Wave(f32).init(&samples, allocator, .{ .sample_rate = 44100, .channels = 2 });
        defer wave.deinit();

        var out: std.Io.Writer.Allocating = .init(allocator);
        defer out.deinit();
        try wave.write(.wav, &out.writer, .{ .bits = case[0], .format_code = case[1] });

        var reader = std.Io.Reader.fixed(out.written());
        const read_wave = try Wave(f32).read(.wav, allocator, &reader);
        defer read_wave.deinit();

        try std.testing.expectEqual(samples.len, read_wave.samples.len);
        try std.testing.expectEqual(@as(u32, 44100), read_wave.sample_rate);
        try std.testing.expectEqual(@as(u16, 2), read_wave.channels);
        for (samples, read_wave.samples) |expected, actual| {
            try std.testing.expectApproxEqAbs(expected, actual, case[2]);
        }
    }
}

test "f32 waves convert channels and mix like the other sample types" {
    const allocator = std.testing.allocator;
    const mono = try Wave(f32).init(&[_]f32{ 0.5, -0.25 }, allocator, .{ .sample_rate = 44100, .channels = 1 });
    defer mono.deinit();

    const stereo = try mono.to_channels(2, .{});
    defer stereo.deinit();
    try std.testing.expectEqualSlices(f32, &[_]f32{ 0.5, 0.5, -0.25, -0.25 }, stereo.samples);

    const mixed = try mono.mix(mono, .{});
    defer mixed.deinit();
    try std.testing.expectEqualSlices(f32, &[_]f32{ 1.0, -0.5 }, mixed.samples);
}
