const std = @import("std");
const testing = std.testing;
const Wave = @import("./root.zig").Wave;

/// Composer type function: Creates a Composer type for the specified sample type.
///
/// Composer allows sequencing and overlaying multiple Wave instances in time to create
/// complex audio arrangements.
///
/// ## Type Parameter
/// - `T`: The sample data type (typically f64, f80, or f128 for floating-point audio)
///
/// ## Usage
/// ```zig
/// const Composer = lightmix.Composer;
/// const composer = Composer(f64).init(allocator, .{
///     .sample_rate = 44100,
///     .channels = 1,
/// });
/// defer composer.deinit();
///
/// // Append waves at specific time points
/// var composed = try composer.append(.{ .wave = wave1, .start_point = 0 });
/// defer composed.deinit();
/// composed = try composed.append(.{ .wave = wave2, .start_point = 22050 });
///
/// // Finalize to create the mixed result
/// const result = try composed.finalize(.{});
/// defer result.deinit();
/// ```
pub fn inner(comptime T: type) type {
    return struct {
        info: []const WaveInfo,
        allocator: std.mem.Allocator,
        sample_rate: u32,
        channels: u16,

        const Self = @This();

        /// Information about a wave to be placed at a specific time point.
        pub const WaveInfo = struct {
            wave: Wave(T),
            start_point: usize,

            fn to_wave(self: WaveInfo, allocator: std.mem.Allocator) std.mem.Allocator.Error!Wave(T) {
                var padding_samples: []T = try allocator.alloc(T, self.start_point);
                defer allocator.free(padding_samples);

                for (0..padding_samples.len) |i| {
                    padding_samples[i] = 0.0;
                }

                const slices: []const []const T = &[_][]const T{ padding_samples, self.wave.samples };
                const samples = try std.mem.concat(allocator, T, slices);

                const result: Wave(T) = try Wave(T).init(samples, allocator, .{
                    .sample_rate = self.wave.sample_rate,
                    .channels = self.wave.channels,
                });

                return result;
            }
        };

        /// Options for initializing a Composer instance.
        pub const InitOptions = struct {
            sample_rate: u32,
            channels: u16,
        };

        /// Creates a new empty Composer instance.
        ///
        /// ## Parameters
        /// - `allocator`: Memory allocator for internal allocations
        /// - `options`: Initialization options (sample rate and channel count)
        ///
        /// ## Returns
        /// A new Composer instance with no waves
        pub fn init(
            allocator: std.mem.Allocator,
            options: InitOptions,
        ) Self {
            return Self{
                .allocator = allocator,
                .info = &[_]WaveInfo{},

                .sample_rate = options.sample_rate,
                .channels = options.channels,
            };
        }

        /// Frees the memory allocated for the composer's internal data.
        ///
        /// Note: This does not free the individual Wave instances stored in WaveInfo.
        /// Those must be freed separately by the caller.
        pub fn deinit(self: Self) void {
            self.allocator.free(self.info);
        }

        /// Creates a new Composer instance initialized with the provided wave information.
        ///
        /// ## Parameters
        /// - `info`: Slice of WaveInfo structures describing waves and their start points
        /// - `allocator`: Memory allocator for internal allocations
        /// - `options`: Initialization options (sample rate and channel count)
        ///
        /// ## Returns
        /// A new Composer instance containing the provided waves
        ///
        /// ## Errors
        /// Returns `std.mem.Allocator.Error` if memory allocation fails
        pub fn init_with(
            info: []const WaveInfo,
            allocator: std.mem.Allocator,
            options: InitOptions,
        ) std.mem.Allocator.Error!Self {
            var list: std.array_list.Aligned(WaveInfo, null) = .empty;
            try list.appendSlice(allocator, info);

            return Self{
                .allocator = allocator,
                .info = try list.toOwnedSlice(allocator),

                .sample_rate = options.sample_rate,
                .channels = options.channels,
            };
        }

        /// Appends a single wave to the composition.
        ///
        /// Returns a new Composer instance with the added wave. The original
        /// Composer is consumed and should not be used after this call.
        ///
        /// ## Parameters
        /// - `self`: The composer to add to
        /// - `waveinfo`: Information about the wave and when it should start
        ///
        /// ## Returns
        /// A new Composer instance with the wave added
        ///
        /// ## Errors
        /// Returns `std.mem.Allocator.Error` if memory allocation fails
        pub fn append(self: Self, waveinfo: WaveInfo) std.mem.Allocator.Error!Self {
            var d: std.array_list.Aligned(WaveInfo, null) = .empty;
            try d.appendSlice(self.allocator, self.info);
            try d.append(self.allocator, waveinfo);

            const result: []const WaveInfo = try d.toOwnedSlice(self.allocator);

            return Self{
                .allocator = self.allocator,
                .info = result,

                .sample_rate = self.sample_rate,
                .channels = self.channels,
            };
        }

        /// Appends multiple waves to the composition.
        ///
        /// Returns a new Composer instance with the added waves. The original
        /// Composer is consumed and should not be used after this call.
        ///
        /// ## Parameters
        /// - `self`: The composer to add to
        /// - `append_list`: Slice of WaveInfo structures to append
        ///
        /// ## Returns
        /// A new Composer instance with all the waves added
        ///
        /// ## Errors
        /// Returns `std.mem.Allocator.Error` if memory allocation fails
        pub fn appendSlice(self: Self, append_list: []const WaveInfo) std.mem.Allocator.Error!Self {
            var d: std.array_list.Aligned(WaveInfo, null) = .empty;
            try d.appendSlice(self.allocator, self.info);
            try d.appendSlice(self.allocator, append_list);

            const result: []const WaveInfo = try d.toOwnedSlice(self.allocator);

            return Self{
                .allocator = self.allocator,
                .info = result,

                .sample_rate = self.sample_rate,
                .channels = self.channels,
            };
        }

        /// Finalizes the composition by mixing all waves together.
        ///
        /// This creates a single Wave by:
        /// 1. Calculating the total length needed
        /// 2. Padding each wave to align with its start_point
        /// 3. Mixing all waves together using the provided mixer function
        ///
        /// ## Parameters
        /// - `self`: The composer containing all the waves to mix
        /// - `options`: Mixing options (includes the mixer function)
        ///
        /// ## Returns
        /// A new Wave containing the final mixed composition
        ///
        /// ## Errors
        /// Returns `std.mem.Allocator.Error` if memory allocation fails
        pub fn finalize(self: Self, options: Wave(T).mixOptions) std.mem.Allocator.Error!Wave(T) {
            var end_point: usize = 0;

            // Calculate the length for emitted wave
            for (self.info) |waveinfo| {
                const ep = waveinfo.start_point + waveinfo.wave.samples.len;

                if (end_point < ep)
                    end_point = ep;
            }

            var padded_waveinfo_list: std.array_list.Aligned(WaveInfo, null) = .empty;
            defer padded_waveinfo_list.deinit(self.allocator);

            // Filter each WaveInfo to append padding both of start and last
            for (self.info) |waveinfo| {
                const padded_at_start: []const T = try padding_for_start(waveinfo.wave.samples, waveinfo.start_point, self.allocator);
                defer self.allocator.free(padded_at_start);

                const padded_at_start_and_last: []const T = try padding_for_last(padded_at_start, end_point, self.allocator);
                defer self.allocator.free(padded_at_start_and_last);

                const wave = try Wave(T).init(padded_at_start_and_last, self.allocator, .{
                    .sample_rate = self.sample_rate,
                    .channels = self.channels,
                });

                const wi: WaveInfo = WaveInfo{
                    .wave = wave,
                    .start_point = waveinfo.start_point,
                };

                try padded_waveinfo_list.append(self.allocator, wi);
            }

            const padded_waveinfo_slice: []const WaveInfo = try padded_waveinfo_list.toOwnedSlice(self.allocator);
            defer self.allocator.free(padded_waveinfo_slice);

            const empty_samples: []const T = try generate_soundless_samples(end_point, self.allocator);
            defer self.allocator.free(empty_samples);

            var result = try Wave(T).init(empty_samples, self.allocator, .{
                .sample_rate = self.sample_rate,
                .channels = self.channels,
            });

            for (padded_waveinfo_slice) |waveinfo| {
                const wave = try result.mix(waveinfo.wave, options);
                result.deinit();
                waveinfo.wave.deinit();
                result = wave;
            }

            return result;
        }

        fn padding_for_start(samples: []const T, start_point: usize, allocator: std.mem.Allocator) std.mem.Allocator.Error![]const T {
            const padding_length: usize = start_point;
            var padding: std.array_list.Aligned(T, null) = .empty;
            defer padding.deinit(allocator);

            // Append padding
            for (0..padding_length) |_|
                try padding.append(allocator, 0.0);

            // Append samples slice
            try padding.appendSlice(allocator, samples);

            const result: []const T = try padding.toOwnedSlice(allocator);

            return result;
        }

        fn padding_for_last(samples: []const T, end_point: usize, allocator: std.mem.Allocator) std.mem.Allocator.Error![]const T {
            std.debug.assert(samples.len <= end_point);

            const padding_length: usize = end_point - samples.len;
            var padding: std.array_list.Aligned(T, null) = .empty;
            defer padding.deinit(allocator);

            // Append samples slice
            try padding.appendSlice(allocator, samples);

            // Append padding
            for (0..padding_length) |_|
                try padding.append(allocator, 0.0);

            const result: []const T = try padding.toOwnedSlice(allocator);

            return result;
        }

        fn generate_soundless_samples(length: usize, allocator: std.mem.Allocator) std.mem.Allocator.Error![]const T {
            var list: std.array_list.Aligned(T, null) = .empty;
            defer list.deinit(allocator);

            // Append empty wave
            for (0..length) |_|
                try list.append(allocator, 0.0);

            const result: []const T = try list.toOwnedSlice(allocator);

            return result;
        }

        test "padding_for_start" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{ 1.0, 1.0 };
            const start_point: usize = 10;

            const result: []const T = try padding_for_start(samples, start_point, allocator);
            defer allocator.free(result);

            try testing.expectEqual(samples.len + start_point, result.len);

            const expected: []const T = &[_]T{ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0 };
            for (0..result.len) |i| {
                try testing.expectApproxEqAbs(expected[i], result[i], 0.001);
            }
        }

        test "init & deinit" {
            const allocator = testing.allocator;
            const composer = Self.init(allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer composer.deinit();
        }

        test "init_with & deinit" {
            const allocator = testing.allocator;
            var reader = std.Io.Reader.fixed(@embedFile("./assets/sine.wav"));

            const wave = try Wave(T).read(allocator, &reader);
            defer wave.deinit();

            const info: []const WaveInfo = &[_]WaveInfo{ .{ .wave = wave, .start_point = 0 }, .{ .wave = wave, .start_point = 0 } };

            const composer = try Self.init_with(info, allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer composer.deinit();
        }

        test "append" {
            const allocator = testing.allocator;
            const composer = Self.init(allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer composer.deinit();

            var reader = std.Io.Reader.fixed(@embedFile("./assets/sine.wav"));

            const wave = try Wave(T).read(allocator, &reader);
            defer wave.deinit();

            const appended_composer = try composer.append(.{ .wave = wave, .start_point = 0 });
            defer appended_composer.deinit();

            try testing.expectEqualSlices(WaveInfo, appended_composer.info, &[_]WaveInfo{.{ .wave = wave, .start_point = 0 }});
        }

        test "appendSlice" {
            const allocator = testing.allocator;
            const composer = Self.init(allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer composer.deinit();

            var reader = std.Io.Reader.fixed(@embedFile("./assets/sine.wav"));

            const wave = try Wave(T).read(allocator, &reader);
            defer wave.deinit();

            var append_list: std.array_list.Aligned(WaveInfo, null) = .empty;
            defer append_list.deinit(allocator);
            try append_list.append(allocator, .{ .wave = wave, .start_point = 0 });
            try append_list.append(allocator, .{ .wave = wave, .start_point = 0 });

            const appended_composer = try composer.appendSlice(append_list.items);
            defer appended_composer.deinit();

            try testing.expectEqualSlices(WaveInfo, appended_composer.info, &[_]WaveInfo{ .{ .wave = wave, .start_point = 0 }, .{ .wave = wave, .start_point = 0 } });
        }

        test "finalize" {
            const allocator = testing.allocator;
            const composer = Self.init(allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer composer.deinit();

            var samples: []T = try allocator.alloc(T, 44100);
            defer allocator.free(samples);

            for (0..samples.len) |i| {
                samples[i] = 1.0;
            }

            const wave = try Wave(T).init(samples, allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer wave.deinit();

            var append_list: std.array_list.Aligned(WaveInfo, null) = .empty;
            defer append_list.deinit(allocator);
            try append_list.append(allocator, .{ .wave = wave, .start_point = 0 });
            try append_list.append(allocator, .{ .wave = wave, .start_point = 44100 });

            const appended_composer = try composer.appendSlice(append_list.items);
            defer appended_composer.deinit();

            const result = try appended_composer.finalize(.{});
            defer result.deinit();

            try testing.expectEqual(result.samples.len, 88200);

            try testing.expectEqual(result.sample_rate, 44100);
            try testing.expectEqual(result.channels, 1);
        }
    };
}

test "Run tests for each samples' type" {
    _ = inner(f128);
    _ = inner(f80);
    _ = inner(f64);
    // _ = inner(f32); zigggwavvv 0.2.1 cannot use f32 as samples' type
}
