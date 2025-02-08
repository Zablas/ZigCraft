const std = @import("std");
const rl = @import("raylib");
const cnst = @import("constants.zig");
const phsx = @import("physics.zig");

const math = std.math;

pub fn handleInput(
    is_cursor_on: *bool,
    yaw: *f32,
    pitch: *f32,
    camera: *rl.Camera3D,
    velocity_y: *f32,
    on_ground: *bool,
    terrain: [cnst.GRID_SIZE][cnst.GRID_SIZE]u32,
) void {
    if (rl.isKeyPressed(rl.KeyboardKey.escape)) {
        is_cursor_on.* = !is_cursor_on.*;
        if (is_cursor_on.*) {
            rl.enableCursor();
        } else {
            rl.disableCursor();
        }
    }

    if (rl.isKeyPressed(rl.KeyboardKey.f11)) {
        rl.toggleFullscreen();
    }

    if (is_cursor_on.*) {
        return;
    }

    // ========== Mouse Input (Camera Rotation) ==========
    const mouse_delta = rl.getMouseDelta();
    yaw.* += mouse_delta.x * 0.1;
    pitch.* -= mouse_delta.y * 0.1;
    pitch.* = math.clamp(pitch.*, -89.0, 89.0);

    var front = rl.Vector3{
        .x = @cos(math.degreesToRadians(yaw.*)) * @cos(math.degreesToRadians(pitch.*)),
        .y = @sin(math.degreesToRadians(pitch.*)),
        .z = @sin(math.degreesToRadians(yaw.*)) * @cos(math.degreesToRadians(pitch.*)),
    };
    front = front.normalize();

    // ========== Keyboard Input (Movement) ==========
    var move_dir = rl.Vector3.zero();
    if (rl.isKeyDown(rl.KeyboardKey.w)) move_dir = move_dir.add(.{ .x = front.x, .y = 0, .z = front.z });
    if (rl.isKeyDown(rl.KeyboardKey.s)) move_dir = move_dir.subtract(.{ .x = front.x, .y = 0, .z = front.z });
    if (rl.isKeyDown(rl.KeyboardKey.a)) move_dir = move_dir.subtract(front.crossProduct(camera.up).normalize());
    if (rl.isKeyDown(rl.KeyboardKey.d)) move_dir = move_dir.add(front.crossProduct(camera.up).normalize());

    phsx.handlePhysics(on_ground, velocity_y, &move_dir, camera, terrain);

    // Update camera target
    camera.target = camera.position.add(front);
}
