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
/// var composer = Composer(f64).init(allocator, .{
///     .sample_rate = 44100,
///     .channels = 1,
/// });
/// defer composer.deinit();
///
/// // Append waves at specific time points
/// try composer.append(.{ .wave = wave1, .start_point = 0 });
/// try composer.append(.{ .wave = wave2, .start_point = 22050 });
///
/// // Finalize to create the mixed result
/// const result = try composer.finalize(.{});
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
                const padding_samples: []T = try allocator.alloc(T, self.start_point);
                defer allocator.free(padding_samples);
                @memset(padding_samples, 0.0);

                const slices: []const []const T = &[_][]const T{ padding_samples, self.wave.samples };
                const samples = try std.mem.concat(allocator, T, slices);
                defer allocator.free(samples);

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
        pub fn init_with(
            info: []const WaveInfo,
            allocator: std.mem.Allocator,
            options: InitOptions,
        ) (Wave(T).MixErrors || std.mem.Allocator.Error)!Self {
            for (info) |waveinfo| {
                if (waveinfo.wave.sample_rate != options.sample_rate or waveinfo.wave.channels != options.channels) {
                    return error.MismatchedWaveProperties;
                }
                if (waveinfo.start_point % options.channels != 0) {
                    return error.UnalignedChannelOffset;
                }
            }

            var list: std.array_list.Aligned(WaveInfo, null) = .empty;
            try list.appendSlice(allocator, info);

            return Self{
                .allocator = allocator,
                .info = try list.toOwnedSlice(allocator),

                .sample_rate = options.sample_rate,
                .channels = options.channels,
            };
        }

        /// Appends a single wave to the composition. This method modifies the composer in-place.
        ///
        /// ## Parameters
        /// - `self`: Pointer to the composer to modify (will be updated in-place)
        /// - `waveinfo`: Information about the wave and when it should start
        ///
        /// ## Memory Management
        /// The old internal array is freed, and a new one is allocated with the
        /// appended wave. The composer pointer is updated to reference the new data.
        ///
        /// ## Example
        /// ```
        /// var composer: Composer(f64) = Composer(f64).init(allocator, .{
        ///     .sample_rate = 44100,
        ///     .channels = 1,
        /// });
        /// defer composer.deinit();
        ///
        /// // Append modifies composer in-place
        /// try composer.append(.{ .wave = wave1, .start_point = 0 });
        /// try composer.append(.{ .wave = wave2, .start_point = 44100 });
        /// ```
        pub fn append(self: *Self, waveinfo: WaveInfo) (Wave(T).MixErrors || std.mem.Allocator.Error)!void {
            if (waveinfo.wave.sample_rate != self.sample_rate or waveinfo.wave.channels != self.channels) {
                return error.MismatchedWaveProperties;
            }
            if (waveinfo.start_point % self.channels != 0) {
                return error.UnalignedChannelOffset;
            }

            var d: std.array_list.Aligned(WaveInfo, null) = .empty;
            try d.appendSlice(self.allocator, self.info);
            try d.append(self.allocator, waveinfo);

            const result: Self = Self{
                .allocator = self.allocator,
                .info = try d.toOwnedSlice(self.allocator),

                .sample_rate = self.sample_rate,
                .channels = self.channels,
            };

            self.deinit(); // Free the old one now
            self.* = result; // Then copy the new one (result variable)
        }

        /// Appends multiple waves to the composition. This method modifies the composer in-place.
        ///
        /// ## Parameters
        /// - `self`: Pointer to the composer to modify (will be updated in-place)
        /// - `append_list`: Slice of WaveInfo structures to append
        ///
        /// ## Memory Management
        /// The old internal array is freed, and a new one is allocated with the
        /// appended wave. The composer pointer is updated to reference the new data.
        pub fn appendSlice(self: *Self, append_list: []const WaveInfo) (Wave(T).MixErrors || std.mem.Allocator.Error)!void {
            for (append_list) |waveinfo| {
                if (waveinfo.wave.sample_rate != self.sample_rate or waveinfo.wave.channels != self.channels) {
                    return error.MismatchedWaveProperties;
                }
                if (waveinfo.start_point % self.channels != 0) {
                    return error.UnalignedChannelOffset;
                }
            }

            var d: std.array_list.Aligned(WaveInfo, null) = .empty;
            try d.appendSlice(self.allocator, self.info);
            try d.appendSlice(self.allocator, append_list);

            const result: Self = Self{
                .allocator = self.allocator,
                .info = try d.toOwnedSlice(self.allocator),

                .sample_rate = self.sample_rate,
                .channels = self.channels,
            };

            self.deinit();
            self.* = result;
        }

        /// Options for converting channel count and panning when appending waves.
        pub const ConvertOptions = struct {
            /// Pan position when upmixing mono to stereo (-1.0 (hard left) to 1.0 (hard right)).
            pan: f32 = 0.0,
        };

        /// Appends a wave to the composition, automatically upmixing or downmixing channel count
        /// if `waveinfo.wave.channels != self.channels`.
        ///
        /// Returns the newly allocated converted `Wave(T)` instance. The caller owns the returned Wave
        /// and is responsible for calling `deinit()` on it after finalizing the composition.
        ///
        /// ## Parameters
        /// - `self`: Pointer to the composer to modify
        /// - `waveinfo`: Information about the wave and start point
        /// - `options`: Channel conversion options (e.g. pan positioning)
        ///
        /// ## Returns
        /// The converted `Wave(T)` instance matching `self.channels`.
        pub fn append_converted(
            self: *Self,
            waveinfo: WaveInfo,
            options: ConvertOptions,
        ) (Wave(T).MixErrors || std.mem.Allocator.Error)!Wave(T) {
            if (waveinfo.wave.sample_rate != self.sample_rate) {
                return error.MismatchedWaveProperties;
            }

            const converted_wave = try waveinfo.wave.to_channels(self.channels, .{ .pan = options.pan });
            errdefer converted_wave.deinit();

            try self.append(.{
                .wave = converted_wave,
                .start_point = waveinfo.start_point,
            });

            return converted_wave;
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
        /// ## Performance Notes
        /// Memory usage is proportional to the total composition length (`total_length * sample_size`).
        /// The destination buffer is allocated once, and component waves are mixed directly into
        /// position without temporary intermediate buffers.
        ///
        /// ## Errors
        /// - `MismatchedWaveProperties`: If component waves have different sample rates or channel counts
        /// - `OutOfMemory`: Allocator error when memory allocation fails
        pub fn finalize(self: Self, options: Wave(T).mixOptions) (Wave(T).MixErrors || std.mem.Allocator.Error)!Wave(T) {
            if (self.info.len == 0) {
                return Wave(T).init(&.{}, self.allocator, .{
                    .sample_rate = self.sample_rate,
                    .channels = self.channels,
                });
            }

            var end_point: usize = 0;

            // Calculate the length for emitted wave and validate component properties
            for (self.info) |waveinfo| {
                if (waveinfo.wave.sample_rate != self.sample_rate or waveinfo.wave.channels != self.channels) {
                    return error.MismatchedWaveProperties;
                }
                if (waveinfo.start_point % self.channels != 0) {
                    return error.UnalignedChannelOffset;
                }
                const ep = std.math.add(usize, waveinfo.start_point, waveinfo.wave.samples.len) catch return error.Overflow;

                if (end_point < ep)
                    end_point = ep;
            }

            const result_samples = try self.allocator.alloc(T, end_point);
            errdefer self.allocator.free(result_samples);
            @memset(result_samples, 0.0);

            for (self.info) |waveinfo| {
                for (waveinfo.wave.samples, 0..) |src_sample, i| {
                    const idx = waveinfo.start_point + i;
                    result_samples[idx] = options.mixer(result_samples[idx], src_sample);
                }
            }

            return Wave(T){
                .samples = result_samples,
                .allocator = self.allocator,
                .sample_rate = self.sample_rate,
                .channels = self.channels,
            };
        }

        /// Mixer function type for blending two overlapping samples.
        pub const MixerFn = *const fn (T, T) T;

        /// Options for stream rendering using `render_stream`.
        pub const StreamOptions = struct {
            /// Mixer function to blend overlapping samples.
            mixer: *const fn (T, T) T = Wave(T).saturating_mixing_expression,
            /// Block size in samples (default: 4096 samples).
            block_size: usize = 4096,
        };

        /// Iterator that renders the composition in fixed-size blocks to minimize peak memory consumption.
        pub const BlockIterator = struct {
            composer: Self,
            options: StreamOptions,
            current_offset: usize,
            total_samples: usize,
            block_buffer: []T,

            pub fn init(composer: Self, options: StreamOptions) (Wave(T).MixErrors || std.mem.Allocator.Error)!BlockIterator {
                var total_samples: usize = 0;
                for (composer.info) |waveinfo| {
                    if (waveinfo.wave.sample_rate != composer.sample_rate or waveinfo.wave.channels != composer.channels) {
                        return error.MismatchedWaveProperties;
                    }
                    if (waveinfo.start_point % composer.channels != 0) {
                        return error.UnalignedChannelOffset;
                    }
                    const ep = std.math.add(usize, waveinfo.start_point, waveinfo.wave.samples.len) catch return error.Overflow;
                    if (total_samples < ep) {
                        total_samples = ep;
                    }
                }

                const bs = if (options.block_size == 0) 4096 else options.block_size;
                if (bs % composer.channels != 0) {
                    return error.UnalignedChannelOffset;
                }
                const buf = try composer.allocator.alloc(T, bs);
                errdefer composer.allocator.free(buf);

                return BlockIterator{
                    .composer = composer,
                    .options = .{ .mixer = options.mixer, .block_size = bs },
                    .current_offset = 0,
                    .total_samples = total_samples,
                    .block_buffer = buf,
                };
            }

            pub fn deinit(self: BlockIterator) void {
                self.composer.allocator.free(self.block_buffer);
            }

            /// Renders and returns the next block of samples.
            ///
            /// Returns `null` when rendering reaches the end of the composition.
            pub fn next(self: *BlockIterator) ?[]const T {
                if (self.current_offset >= self.total_samples) {
                    return null;
                }

                const remaining = self.total_samples - self.current_offset;
                const chunk_len = @min(remaining, self.options.block_size);
                const chunk_samples = self.block_buffer[0..chunk_len];
                @memset(chunk_samples, 0.0);

                const block_start = self.current_offset;
                const block_end = block_start + chunk_len;

                for (self.composer.info) |waveinfo| {
                    const wave_start = waveinfo.start_point;
                    const wave_end = wave_start + waveinfo.wave.samples.len;

                    if (wave_end <= block_start or wave_start >= block_end) {
                        continue;
                    }

                    const overlap_start = @max(wave_start, block_start);
                    const overlap_end = @min(wave_end, block_end);

                    const wave_offset = overlap_start - wave_start;
                    const block_offset = overlap_start - block_start;
                    const count = overlap_end - overlap_start;

                    for (0..count) |i| {
                        const src_sample = waveinfo.wave.samples[wave_offset + i];
                        const dst_idx = block_offset + i;
                        chunk_samples[dst_idx] = self.options.mixer(chunk_samples[dst_idx], src_sample);
                    }
                }

                self.current_offset += chunk_len;
                return chunk_samples;
            }
        };

        /// Creates a block-based rendering iterator for memory-efficient streaming.
        ///
        /// ## Parameters
        /// - `self`: The composer instance
        /// - `options`: Streaming options (mixer function, block_size)
        ///
        /// ## Returns
        /// A `BlockIterator` for chunked rendering
        pub fn render_stream(self: Self, options: StreamOptions) (Wave(T).MixErrors || std.mem.Allocator.Error)!BlockIterator {
            return BlockIterator.init(self, options);
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

            const wave = try Wave(T).read(.wav, allocator, &reader);
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
            var reader = std.Io.Reader.fixed(@embedFile("./assets/sine.wav"));
            var composer = Self.init(allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer composer.deinit();

            const wave = try Wave(T).read(.wav, allocator, &reader);
            defer wave.deinit();

            try composer.append(.{ .wave = wave, .start_point = 0 });

            try testing.expectEqualSlices(WaveInfo, composer.info, &[_]WaveInfo{.{ .wave = wave, .start_point = 0 }});
        }

        test "appendSlice" {
            const allocator = testing.allocator;
            var composer = Self.init(allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer composer.deinit();

            var reader = std.Io.Reader.fixed(@embedFile("./assets/sine.wav"));

            const wave = try Wave(T).read(.wav, allocator, &reader);
            defer wave.deinit();

            var append_list: std.array_list.Aligned(WaveInfo, null) = .empty;
            defer append_list.deinit(allocator);
            try append_list.append(allocator, .{ .wave = wave, .start_point = 0 });
            try append_list.append(allocator, .{ .wave = wave, .start_point = 0 });
            try composer.appendSlice(append_list.items);

            try testing.expectEqualSlices(WaveInfo, composer.info, &[_]WaveInfo{ .{ .wave = wave, .start_point = 0 }, .{ .wave = wave, .start_point = 0 } });
        }

        test "finalize" {
            const allocator = testing.allocator;
            var composer = Self.init(allocator, .{
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
            try composer.appendSlice(append_list.items);

            const result = try composer.finalize(.{});
            defer result.deinit();

            try testing.expectEqual(result.samples.len, 88200);

            try testing.expectEqual(result.sample_rate, 44100);
            try testing.expectEqual(result.channels, 1);
        }

        test "MismatchedWaveProperties error handling in Composer" {
            const allocator = testing.allocator;
            var composer = Self.init(allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer composer.deinit();

            const samples = [_]T{ 0.1, 0.2, 0.3 };
            const diff_rate_wave = try Wave(T).init(&samples, allocator, .{
                .sample_rate = 48000,
                .channels = 1,
            });
            defer diff_rate_wave.deinit();

            try testing.expectError(error.MismatchedWaveProperties, composer.append(.{ .wave = diff_rate_wave, .start_point = 0 }));

            const diff_info: []const WaveInfo = &[_]WaveInfo{.{ .wave = diff_rate_wave, .start_point = 0 }};
            try testing.expectError(error.MismatchedWaveProperties, Self.init_with(diff_info, allocator, .{ .sample_rate = 44100, .channels = 1 }));
        }

        test "append returns MismatchedWaveProperties for mismatched sample rates" {
            const allocator = testing.allocator;
            var composer = Self.init(allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer composer.deinit();

            const samples = [_]T{ 0.1, 0.2, 0.3 };
            const wave_48k = try Wave(T).init(&samples, allocator, .{
                .sample_rate = 48000,
                .channels = 1,
            });
            defer wave_48k.deinit();

            // Mismatched sample rate on append
            try testing.expectError(error.MismatchedWaveProperties, composer.append(.{ .wave = wave_48k, .start_point = 0 }));

            // Mismatched sample rate on append_converted
            try testing.expectError(error.MismatchedWaveProperties, composer.append_converted(.{ .wave = wave_48k, .start_point = 0 }, .{}));

            const wave_stereo_44k = try Wave(T).init(&samples, allocator, .{
                .sample_rate = 44100,
                .channels = 2,
            });
            defer wave_stereo_44k.deinit();

            // Mismatched channels on direct append without append_converted
            try testing.expectError(error.MismatchedWaveProperties, composer.append(.{ .wave = wave_stereo_44k, .start_point = 0 }));
        }

        test "finalize with staggered overlapping waves" {
            const allocator = testing.allocator;
            var composer = Self.init(allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer composer.deinit();

            const samples1 = [_]T{ 0.5, 0.5, 0.5 };
            const wave1 = try Wave(T).init(&samples1, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave1.deinit();

            const samples2 = [_]T{ 0.3, 0.3, 0.3 };
            const wave2 = try Wave(T).init(&samples2, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave2.deinit();

            // wave1 starts at index 0 (spans 0..2)
            // wave2 starts at index 1 (spans 1..3)
            try composer.append(.{ .wave = wave1, .start_point = 0 });
            try composer.append(.{ .wave = wave2, .start_point = 1 });

            const result = try composer.finalize(.{});
            defer result.deinit();

            try testing.expectEqual(result.samples.len, 4);
            try testing.expectApproxEqAbs(result.samples[0], 0.5, 0.00001);
            try testing.expectApproxEqAbs(result.samples[1], 0.8, 0.00001);
            try testing.expectApproxEqAbs(result.samples[2], 0.8, 0.00001);
            try testing.expectApproxEqAbs(result.samples[3], 0.3, 0.00001);
        }

        test "render_stream produces identical output to finalize in blocks" {
            const allocator = testing.allocator;
            var composer = Self.init(allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer composer.deinit();

            const samples1 = [_]T{ 0.1, 0.2, 0.3, 0.4, 0.5 };
            const wave1 = try Wave(T).init(&samples1, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave1.deinit();

            const samples2 = [_]T{ 0.5, 0.4, 0.3 };
            const wave2 = try Wave(T).init(&samples2, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave2.deinit();

            try composer.append(.{ .wave = wave1, .start_point = 0 });
            try composer.append(.{ .wave = wave2, .start_point = 2 });

            const finalized = try composer.finalize(.{});
            defer finalized.deinit();

            var iterator = try composer.render_stream(.{ .block_size = 2 });
            defer iterator.deinit();

            var streamed_samples: std.array_list.Aligned(T, null) = .empty;
            defer streamed_samples.deinit(allocator);

            while (iterator.next()) |block| {
                try streamed_samples.appendSlice(allocator, block);
            }

            try testing.expectEqual(finalized.samples.len, streamed_samples.items.len);
            for (finalized.samples, streamed_samples.items) |expected, actual| {
                try testing.expectApproxEqAbs(expected, actual, 0.00001);
            }
        }

        test "render_stream with block_size larger than composition length" {
            const allocator = testing.allocator;
            var composer = Self.init(allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer composer.deinit();

            const samples = [_]T{ 0.1, 0.2, 0.3 };
            const wave = try Wave(T).init(&samples, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave.deinit();
            try composer.append(.{ .wave = wave, .start_point = 0 });

            var iterator = try composer.render_stream(.{ .block_size = 10 });
            defer iterator.deinit();

            const block1 = iterator.next();
            try testing.expect(block1 != null);
            try testing.expectEqual(block1.?.len, 3);
            for (samples, block1.?) |expected, actual| {
                try testing.expectApproxEqAbs(expected, actual, 0.00001);
            }

            try testing.expectEqual(iterator.next(), null);
        }

        test "render_stream with unaligned block_size" {
            const allocator = testing.allocator;
            var composer = Self.init(allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer composer.deinit();

            const samples = [_]T{ 0.1, 0.2, 0.3, 0.4, 0.5 };
            const wave = try Wave(T).init(&samples, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave.deinit();
            try composer.append(.{ .wave = wave, .start_point = 0 });

            var iterator = try composer.render_stream(.{ .block_size = 2 });
            defer iterator.deinit();

            const b1 = iterator.next();
            try testing.expect(b1 != null);
            try testing.expectEqual(b1.?.len, 2);

            const b2 = iterator.next();
            try testing.expect(b2 != null);
            try testing.expectEqual(b2.?.len, 2);

            const b3 = iterator.next();
            try testing.expect(b3 != null);
            try testing.expectEqual(b3.?.len, 1);
            try testing.expectApproxEqAbs(b3.?[0], 0.5, 0.00001);

            try testing.expectEqual(iterator.next(), null);
        }

        test "render_stream on empty composer" {
            const allocator = testing.allocator;
            var composer = Self.init(allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer composer.deinit();

            var iterator = try composer.render_stream(.{ .block_size = 4 });
            defer iterator.deinit();

            try testing.expectEqual(iterator.next(), null);
        }

        test "render_stream with unaligned block_size returns UnalignedChannelOffset" {
            const allocator = testing.allocator;
            var composer = Self.init(allocator, .{ .sample_rate = 44100, .channels = 2 });
            defer composer.deinit();

            const samples = [_]T{ 0.1, 0.2, 0.3, 0.4 };
            const wave = try Wave(T).init(&samples, allocator, .{ .sample_rate = 44100, .channels = 2 });
            defer wave.deinit();
            try composer.append(.{ .wave = wave, .start_point = 0 });

            try testing.expectError(error.UnalignedChannelOffset, composer.render_stream(.{ .block_size = 3 }));
        }

        test "finalize and render_stream return Overflow on sample end_point overflow" {
            const allocator = testing.allocator;
            var composer = Self.init(allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer composer.deinit();

            const samples = [_]T{ 0.1, 0.2 };
            const wave = try Wave(T).init(&samples, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave.deinit();

            try composer.append(.{ .wave = wave, .start_point = std.math.maxInt(usize) - 1 });

            try testing.expectError(error.Overflow, composer.finalize(.{}));
            try testing.expectError(error.Overflow, composer.render_stream(.{}));
        }

        test "append_converted upmixes mono wave to stereo composer with panning" {
            const allocator = testing.allocator;
            var composer = Self.init(allocator, .{
                .sample_rate = 44100,
                .channels = 2,
            });
            defer composer.deinit();

            const mono_samples = [_]T{ 0.8, 0.4 };
            const mono_wave = try Wave(T).init(&mono_samples, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer mono_wave.deinit();

            const converted = try composer.append_converted(.{ .wave = mono_wave, .start_point = 0 }, .{ .pan = -0.5 });
            defer converted.deinit();

            const result = try composer.finalize(.{});
            defer result.deinit();

            try testing.expectEqual(result.channels, 2);
            try testing.expectEqual(result.samples.len, 4);

            try testing.expectApproxEqAbs(result.samples[0], 0.8, 0.00001);
            try testing.expectApproxEqAbs(result.samples[1], 0.4, 0.00001);
            try testing.expectApproxEqAbs(result.samples[2], 0.4, 0.00001);
            try testing.expectApproxEqAbs(result.samples[3], 0.2, 0.00001);
        }

        test "append_converted downmixes stereo wave to mono composer" {
            const allocator = testing.allocator;
            var composer = Self.init(allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer composer.deinit();

            const stereo_samples = [_]T{ 1.0, 0.6, 0.4, 0.2 };
            const stereo_wave = try Wave(T).init(&stereo_samples, allocator, .{ .sample_rate = 44100, .channels = 2 });
            defer stereo_wave.deinit();

            const converted = try composer.append_converted(.{ .wave = stereo_wave, .start_point = 0 }, .{});
            defer converted.deinit();

            const result = try composer.finalize(.{});
            defer result.deinit();

            try testing.expectEqual(result.channels, 1);
            try testing.expectEqual(result.samples.len, 2);

            try testing.expectApproxEqAbs(result.samples[0], 0.8, 0.00001);
            try testing.expectApproxEqAbs(result.samples[1], 0.3, 0.00001);
        }

        test "finalize with staggered 2-channel interleaved stereo waveforms" {
            const allocator = testing.allocator;
            var composer = Self.init(allocator, .{
                .sample_rate = 44100,
                .channels = 2,
            });
            defer composer.deinit();

            // wave1: 2 stereo frames -> [L=0.2, R=0.4, L=0.6, R=0.8]
            const samples1 = [_]T{ 0.2, 0.4, 0.6, 0.8 };
            const wave1 = try Wave(T).init(&samples1, allocator, .{ .sample_rate = 44100, .channels = 2 });
            defer wave1.deinit();

            // wave2: 2 stereo frames -> [L=0.1, R=0.3, L=0.5, R=0.7]
            const samples2 = [_]T{ 0.1, 0.3, 0.5, 0.7 };
            const wave2 = try Wave(T).init(&samples2, allocator, .{ .sample_rate = 44100, .channels = 2 });
            defer wave2.deinit();

            // wave1 starts at sample index 0
            // wave2 starts at sample index 2 (offset by 1 stereo frame)
            try composer.append(.{ .wave = wave1, .start_point = 0 });
            try composer.append(.{ .wave = wave2, .start_point = 2 });

            const result = try composer.finalize(.{});
            defer result.deinit();

            try testing.expectEqual(result.channels, 2);
            try testing.expectEqual(result.samples.len, 6);

            // Frame 0 (non-overlap): wave1
            try testing.expectApproxEqAbs(result.samples[0], 0.2, 0.00001);
            try testing.expectApproxEqAbs(result.samples[1], 0.4, 0.00001);

            // Frame 1 (overlap): wave1 + wave2
            try testing.expectApproxEqAbs(result.samples[2], 0.7, 0.00001);
            try testing.expectApproxEqAbs(result.samples[3], 1.1, 0.00001);

            // Frame 2 (non-overlap): wave2
            try testing.expectApproxEqAbs(result.samples[4], 0.5, 0.00001);
            try testing.expectApproxEqAbs(result.samples[5], 0.7, 0.00001);
        }

        test "WaveInfo.to_wave converts wave with padding without memory leaks" {
            const allocator = testing.allocator;
            const original_samples = [_]T{ 1.0, 2.0 };
            const wave = try Wave(T).init(&original_samples, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave.deinit();

            const info = WaveInfo{ .wave = wave, .start_point = 3 };
            const padded_wave = try info.to_wave(allocator);
            defer padded_wave.deinit();

            try testing.expectEqual(padded_wave.samples.len, 5);
            try testing.expectEqual(padded_wave.samples[0], 0.0);
            try testing.expectEqual(padded_wave.samples[1], 0.0);
            try testing.expectEqual(padded_wave.samples[2], 0.0);
            try testing.expectEqual(padded_wave.samples[3], 1.0);
            try testing.expectEqual(padded_wave.samples[4], 2.0);
        }
    };
}

test "Run tests for each samples' type" {
    _ = inner(f128);
    _ = inner(f80);
    _ = inner(f64);
    // _ = inner(f32); zigggwavvv 0.2.1 cannot use f32 as samples' type
}
