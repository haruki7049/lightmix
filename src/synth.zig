//! Synth

const std = @import("std");
const build_options = @import("build_options");

const testing = std.testing;

const Self = @This();
const Wave = @import("./wave.zig");

attack: []const f32,
decay: []const f32,
sustain: []const f32,
release: []const f32,

allocator: std.mem.Allocator,

sample_rate: usize,
channels: usize,
bits: usize,

pub const initOptions = struct {
    attack: []const f32,
    decay: []const f32,
    sustain: []const f32,
    release: []const f32,

    sample_rate: usize,
    channels: usize,
    bits: usize,
};

pub fn init(allocator: std.mem.Allocator, options: initOptions) Self {
    const owned_attack = allocator.alloc(f32, options.attack.len) catch @panic("Out of memory");
    @memcpy(owned_attack, options.attack);

    const owned_decay = allocator.alloc(f32, options.decay.len) catch @panic("Out of memory");
    @memcpy(owned_decay, options.decay);

    const owned_sustain = allocator.alloc(f32, options.sustain.len) catch @panic("Out of memory");
    @memcpy(owned_sustain, options.sustain);

    const owned_release = allocator.alloc(f32, options.release.len) catch @panic("Out of memory");
    @memcpy(owned_release, options.release);

    return Self{
        .attack = owned_attack,
        .decay = owned_decay,
        .sustain = owned_sustain,
        .release = owned_release,

        .allocator = allocator,

        .sample_rate = options.sample_rate,
        .channels = options.channels,
        .bits = options.bits,
    };
}

pub fn deinit(self: Self) void {
    self.allocator.free(self.attack);
    self.allocator.free(self.decay);
    self.allocator.free(self.sustain);
    self.allocator.free(self.release);
}

const Part = enum {
    attack,
    decay,
    sustain,
    release,
};

pub fn filter(self: Self, filter_fn: fn (self: Self) anyerror!Self) Self {
    const result: Self = filter_fn(self) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Error happend in filter function...");
    };

    return result;
}

pub fn finalize(self: Self) Wave {
    const data = std.mem.concat(self.allocator, f32, &[_][]const f32{ self.attack, self.decay, self.sustain, self.release }) catch @panic("Out of memory");
    defer self.allocator.free(data);

    return Wave.init(data, self.allocator, .{
        .sample_rate = self.sample_rate,
        .channels = self.channels,
        .bits = self.bits,
    });
}

test "init & deinit" {
    const allocator = testing.allocator;
    const empty_synth = Self.init(allocator, .{
        .attack = &[_]f32{},
        .decay = &[_]f32{},
        .sustain = &[_]f32{},
        .release = &[_]f32{},

        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer empty_synth.deinit();
}

test "init -> filter -> deinit" {
    const allocator = testing.allocator;
    const empty_synth = Self.init(allocator, .{
        .attack = &[_]f32{},
        .decay = &[_]f32{},
        .sustain = &[_]f32{},
        .release = &[_]f32{},

        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer empty_synth.deinit();

    const result: Self = empty_synth.filter(filter_fn_for_test);
    defer result.deinit();

    for (0..result.release.len) |i| {
        try testing.expectApproxEqAbs(result.release[i], 0.0, 0.001);
    }
}

fn filter_fn_for_test(self: Self) !Self {
    const release: []const f32 = &[_]f32{ 0.0, 0.0, 0.0 };
    const owned_release = try self.allocator.alloc(f32, release.len);
    @memcpy(owned_release, release);

    return Self{
        .attack = &[_]f32{},
        .decay = &[_]f32{},
        .sustain = &[_]f32{},
        .release = owned_release,

        .allocator = self.allocator,

        .sample_rate = self.sample_rate,
        .channels = self.channels,
        .bits = self.bits,
    };
}

test "init -> finalize -> deinit" {
    const allocator = testing.allocator;
    const synth = Self.init(allocator, .{
        .attack = &[_]f32{},
        .decay = &[_]f32{ 0.1 },
        .sustain = &[_]f32{},
        .release = &[_]f32{ 1.0 },

        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer synth.deinit();

    const result: Wave = synth.finalize();
    defer result.deinit();

    try testing.expectApproxEqAbs(result.data[0], 0.1, 0.001);
    try testing.expectApproxEqAbs(result.data[1], 1.0, 0.001);
}
