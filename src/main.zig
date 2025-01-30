const std = @import("std");
const rl = @import("raylib");

const GRID_SIZE = 50;

pub fn main() !void {
    rl.initWindow(1280, 720, "ZigCraft");
    defer rl.closeWindow();

    rl.setTargetFPS(60);
    rl.setExitKey(rl.KeyboardKey.null);
    rl.disableCursor();

    var camera = rl.Camera3D{
        .position = rl.Vector3.init(10, 10, 10),
        .target = rl.Vector3.init(0, 0, 0),
        .up = rl.Vector3.init(0, 1, 0),
        .fovy = 45,
        .projection = rl.CameraProjection.perspective,
    };

    const terrain = try generateTerrain();
    var is_cursor_on = false;

    while (!rl.windowShouldClose()) {
        if (!is_cursor_on) {
            rl.updateCamera(&camera, rl.CameraMode.first_person);
        }

        if (rl.isKeyPressed(rl.KeyboardKey.escape)) {
            is_cursor_on = !is_cursor_on;
            if (is_cursor_on) {
                rl.enableCursor();
            } else {
                rl.disableCursor();
            }
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.ray_white);
        rl.beginMode3D(camera);
        defer rl.endMode3D();

        for (terrain, 0..) |row, x| {
            for (row, 0..) |height, y| {
                const pos = rl.Vector3.init(@floatFromInt(x), height, @floatFromInt(y));
                rl.drawCube(pos, 1, 1, 1, rl.Color.green);
                rl.drawCubeWires(pos, 1, 1, 1, rl.Color.black);
            }
        }
    }
}

fn perlinNoise(x: f32, y: f32) !f32 {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    const scale = rand.float(f32);
    return @sin(x) * @cos(y) * scale;
}

fn generateTerrain() ![GRID_SIZE][GRID_SIZE]f32 {
    var terrain: [GRID_SIZE][GRID_SIZE]f32 = undefined;
    for (terrain, 0..) |row, x| {
        for (row, 0..) |_, y| {
            const height = try perlinNoise(@floatFromInt(x), @floatFromInt(y));
            terrain[x][y] = height;
        }
    }
    return terrain;
}
