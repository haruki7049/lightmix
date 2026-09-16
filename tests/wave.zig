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
