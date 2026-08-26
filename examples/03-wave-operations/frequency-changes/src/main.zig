//! # Frequency Changes - Pitch Shifting
//!
//! This example demonstrates techniques for changing the pitch of audio:
//! - Doubling frequency (one octave up)
//! - Halving frequency (one octave down)
//!
//! ## What you'll learn:
//! - How frequency relates to pitch
//! - Simple pitch shifting techniques
//! - Octave relationships in music

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    // Generate original 440Hz sine wave (A4)
    const original = try generateSineWave(440.0, allocator);
    defer original.deinit();

    // One octave higher (880Hz - A5)
    const octave_up = try generateSineWave(880.0, allocator);
    defer octave_up.deinit();

    // One octave lower (220Hz - A3)
    const octave_down = try generateSineWave(220.0, allocator);
    defer octave_down.deinit();

    try saveWave(io, original, "a4_original.wav", allocator);
    try saveWave(io, octave_up, "a5_octave_up.wav", allocator);
    try saveWave(io, octave_down, "a3_octave_down.wav", allocator);

    std.debug.print("✓ Generated frequency variations:\n", .{});
    std.debug.print("  a4_original.wav - 440 Hz (A4)\n", .{});
    std.debug.print("  a5_octave_up.wav - 880 Hz (A5, +1 octave)\n", .{});
    std.debug.print("  a3_octave_down.wav - 220 Hz (A3, -1 octave)\n", .{});
}

fn generateSineWave(frequency: f64, allocator: std.mem.Allocator) !Wave(f64) {
    const sample_rate: f64 = 44100.0;
    const radians_per_sec: f64 = frequency * 2.0 * std.math.pi;

    var samples: [44100]f64 = undefined;
    for (0..samples.len) |i| {
        const t = @as(f64, @floatFromInt(i)) / sample_rate;
        samples[i] = 0.5 * @sin(radians_per_sec * t);
    }

    return try Wave(f64).init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}

fn saveWave(io: std.Io, wave: Wave(f64), filename: []const u8, allocator: std.mem.Allocator) !void {
    const file = try std.Io.Dir.cwd().createFile(io, filename, .{});
    defer file.close(io);
    const buf = try allocator.alloc(u8, 10 * 1024 * 1024);
    defer allocator.free(buf);
    var writer = file.writer(io, buf);

    try wave.write(.wav, &writer.interface, .{
        .format_code = .pcm,
        .bits = 16,
    });

    try writer.interface.flush();
}
