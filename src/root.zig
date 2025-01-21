const std = @import("std");
const testing = std.testing;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "builder" {
    _ = Builder.init(.{});
}

test "wave" {
    _ = Wave.init(.{});
    _ = Wave.init(.{}).data;
    _ = Wave.init(.{}).apply();
    _ = Wave.init(.{}).apply().data;
}

pub const Builder = struct {
    wave: Wave = Wave.init(.{}),

    const initOption = struct { };

    fn init(option: initOption) Builder {
        _ = option;

        return Builder{};
    }
};

const Wave = struct {
    data: []f32 = &[_]f32{},

    const initOption = struct { };

    fn init(option: initOption) Wave {
        _ = option;

        return Wave{};
    }

    fn apply(self: Wave) Wave {
        return self;
    }
};
