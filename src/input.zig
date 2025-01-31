const std = @import("std");
const rl = @import("raylib");
const cnst = @import("constants.zig");

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

    const delta_time = rl.getFrameTime();

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
    if (rl.isKeyDown(rl.KeyboardKey.w)) move_dir = move_dir.add(front);
    if (rl.isKeyDown(rl.KeyboardKey.s)) move_dir = move_dir.subtract(front);
    if (rl.isKeyDown(rl.KeyboardKey.a)) move_dir = move_dir.subtract(front.crossProduct(camera.up).normalize());
    if (rl.isKeyDown(rl.KeyboardKey.d)) move_dir = move_dir.add(front.crossProduct(camera.up).normalize());

    // Horizontal movement
    if (move_dir.length() > 0) {
        move_dir = move_dir.normalize().scale(5.0 * delta_time);
        camera.position = camera.position.add(move_dir);
    }

    // ========== Jumping & Gravity ==========
    velocity_y.* -= cnst.GRAVITY * delta_time;
    camera.position.y += velocity_y.* * delta_time;

    // ========== Ground Collision ==========
    const block_x: usize = @intFromFloat(@floor(camera.position.x));
    const block_z: usize = @intFromFloat(@floor(camera.position.z));
    on_ground.* = false;

    if (block_x >= 0 and block_x < cnst.GRID_SIZE and block_z >= 0 and block_z < cnst.GRID_SIZE) {
        const terrain_height = terrain[block_x][block_z];
        const ground_y = @as(f32, @floatFromInt(terrain_height)) - 0.1;

        if (camera.position.y - cnst.PLAYER_HEIGHT <= ground_y) {
            on_ground.* = true;
            velocity_y.* = 0;
            camera.position.y = ground_y + cnst.PLAYER_HEIGHT;
        }
    }

    // Jump input
    if (on_ground.* and rl.isKeyPressed(rl.KeyboardKey.space)) {
        velocity_y.* = cnst.JUMP_FORCE;
    }

    // Update camera target
    camera.target = camera.position.add(front);
}
