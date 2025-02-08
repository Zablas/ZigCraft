const std = @import("std");
const rl = @import("raylib");

const fr = @import("frustum.zig");
const cnst = @import("constants.zig");
const trn = @import("terrain_gen.zig");
const inpt = @import("input.zig");
const ui = @import("ui.zig");

pub fn main() void {
    rl.initWindow(cnst.SCREEN_WIDTH, cnst.SCREEN_HEIGHT, "ZigCraft");
    defer rl.closeWindow();

    rl.setExitKey(rl.KeyboardKey.null);
    rl.disableCursor();

    var camera = rl.Camera3D{
        .position = rl.Vector3.init(25, 25, 25),
        .target = rl.Vector3.init(0, 0, 0),
        .up = rl.Vector3.init(0, 1, 0),
        .fovy = 45,
        .projection = rl.CameraProjection.perspective,
    };

    var velocity_y: f32 = 0.0;
    var on_ground = false;
    var yaw: f32 = -90.0;
    var pitch: f32 = 0.0;

    const terrain = trn.generateTerrain();
    var is_cursor_on = false;

    while (!rl.windowShouldClose()) {
        inpt.handleInput(&is_cursor_on, &yaw, &pitch, &camera, &velocity_y, &on_ground, terrain);

        // Get frustum once per frame
        const frustum = fr.Frustum.init(
            camera,
            @floatFromInt(rl.getScreenWidth()),
            @floatFromInt(rl.getScreenHeight()),
        );

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
        rl.beginMode3D(camera);
        defer {
            rl.endMode3D();

            // Draw FPS counter at top-left
            const fps_text = rl.textFormat("FPS: %d", .{rl.getFPS()});
            rl.drawText(fps_text, 10, 10, 20, rl.Color.red);

            ui.drawCrosshair();
        }

        // Draw the terrain
        for (terrain, 0..) |row, x| {
            for (row, 0..) |height, z| {
                // Stack blocks from Y=0 to Y=height
                for (0..height) |y| {
                    const pos = rl.Vector3.init(@floatFromInt(x), @floatFromInt(y), @floatFromInt(z));

                    // Skip rendering if block is outside the frustum
                    if (!frustum.containsCube(pos, 0.5)) continue;

                    const color = if (y == height - 1) rl.Color.green else rl.Color.brown;
                    rl.drawCube(pos, 1, 1, 1, color);
                    rl.drawCubeWires(pos, 1, 1, 1, rl.Color.black);
                }
            }
        }
    }
}
