const std = @import("std");
const cnst = @import("constants.zig");

pub fn generateTerrain() [cnst.GRID_SIZE][cnst.GRID_SIZE]u32 {
    var terrain: [cnst.GRID_SIZE][cnst.GRID_SIZE]u32 = undefined;
    for (&terrain, 0..) |*row, x| {
        for (row, 0..) |_, z| {
            const height = generateHeight(@as(f32, @floatFromInt(x)) * cnst.SCALE, @as(f32, @floatFromInt(z)) * cnst.SCALE);
            row[z] = height;
        }
    }
    return terrain;
}

fn noise(x: f32, y: f32) f32 {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch {
            seed = 1;
        };
        break :blk seed;
    });
    const rand = prng.random();

    const scale = rand.float(f32);
    return @sin(x * 0.1) * @cos(y * 0.1) + @sin(y * 0.05) * @cos(x * 0.05) * scale;
}

fn fractalNoise(x: f32, y: f32, octaves: u32, persistence: f32) f32 {
    var total: f32 = 0.0;
    var frequency: f32 = 1.0;
    var amplitude: f32 = 1.0;
    var max_value: f32 = 0.0;

    for (0..octaves) |_| {
        total += noise(x * frequency, y * frequency) * amplitude;
        max_value += amplitude;
        amplitude *= persistence;
        frequency *= 2.0;
    }

    return total / max_value; // Normalize to [-1, 1]
}

fn generateHeight(x: f32, y: f32) u32 {
    // Generate fractal noise and convert to a positive integer height
    const noise_value = fractalNoise(x, y, 4, 0.5);
    const scaled_height = std.math.pow(f32, @abs(noise_value), 1.2) * 10.0 + 10.0; // Offset to avoid negative heights
    return @intFromFloat(@max(scaled_height, 0.0));
}
