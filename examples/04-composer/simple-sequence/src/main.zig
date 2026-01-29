//! # Simple Sequence - Using Composer
//!
//! This example introduces the Composer, which allows you to arrange multiple
//! waves in time. We'll create a simple melody by sequencing sine waves.
//!
//! ## What you'll learn:
//! - How to use the Composer API
//! - Sequencing waves with start_point
//! - Creating simple melodies
//!
//! ## The melody:
//! We'll play C-D-E-C in sequence (first 4 notes of "Frère Jacques")

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const Composer = lightmix.Composer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create composer
    var composer = Composer(f64).init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();

    // Generate notes (quarter notes at 120 BPM = 0.5 seconds each)
    const c4 = try generateNote(261.63, allocator); // C4
    defer c4.deinit();
    const d4 = try generateNote(293.66, allocator); // D4
    defer d4.deinit();
    const e4 = try generateNote(329.63, allocator); // E4
    defer e4.deinit();

    // Arrange notes in sequence
    var notes_list: std.array_list.Aligned(Composer(f64).WaveInfo, null) = .empty;
    defer notes_list.deinit(allocator);

    try notes_list.append(allocator, .{ .wave = c4, .start_point = 0 }); // 0.0s
    try notes_list.append(allocator, .{ .wave = d4, .start_point = 22050 }); // 0.5s
    try notes_list.append(allocator, .{ .wave = e4, .start_point = 44100 }); // 1.0s
    try notes_list.append(allocator, .{ .wave = c4, .start_point = 66150 }); // 1.5s

    try composer.appendSlice(notes_list.items);

    const result = try composer.finalize(.{});
    defer result.deinit();

    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    const buf = try allocator.alloc(u8, 10 * 1024 * 1024);
    defer allocator.free(buf);
    var writer = file.writer(buf);

    try result.write(&writer.interface, .{
        .allocator = allocator,
        .format_code = .pcm,
        .bits = 16,
    });

    try writer.interface.flush();

    std.debug.print("✓ Created simple melody: C-D-E-C\n", .{});
}

fn generateNote(frequency: f64, allocator: std.mem.Allocator) !Wave(f64) {
    const sample_rate: f64 = 44100.0;
    const radians_per_sec: f64 = frequency * 2.0 * std.math.pi;

    var samples: [22050]f64 = undefined;
    for (0..samples.len) |i| {
        const t = @as(f64, @floatFromInt(i)) / sample_rate;
        const envelope = 1.0 - (t / 0.5); // Simple decay
        samples[i] = 0.3 * @sin(radians_per_sec * t) * envelope;
    }

    return try Wave(f64).init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}
