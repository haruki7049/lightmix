const std = @import("std");
const testing = std.testing;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "builder" {
    _ = Builder.init();
    _ = Wave.init();
}

pub const Builder = struct {
    wave: Wave,

    fn init() Builder {
        return Builder{
            .wave = Wave.init(),
        };
    }
};

const Wave = struct {
    data: []f32,

    fn init() Wave {
        return Wave{
            .data = &[_]f32{},
        };
    }
};
