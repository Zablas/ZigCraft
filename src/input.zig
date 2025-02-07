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
    if (rl.isKeyDown(rl.KeyboardKey.w)) move_dir = move_dir.add(.{ .x = front.x, .y = 0, .z = front.z });
    if (rl.isKeyDown(rl.KeyboardKey.s)) move_dir = move_dir.subtract(.{ .x = front.x, .y = 0, .z = front.z });
    if (rl.isKeyDown(rl.KeyboardKey.a)) move_dir = move_dir.subtract(front.crossProduct(camera.up).normalize());
    if (rl.isKeyDown(rl.KeyboardKey.d)) move_dir = move_dir.add(front.crossProduct(camera.up).normalize());

    // ========== Horizontal Movement with Collisions ==========
    if (move_dir.length() > 0) {
        move_dir = move_dir.normalize().scale(5.0 * delta_time);

        const original_pos = camera.position;
        const player_feet_y = original_pos.y - cnst.PLAYER_HEIGHT + 0.1; // +0.1 for FP epsilon

        // X-axis movement check
        const new_x = original_pos.x + move_dir.x;
        var blocked_x = false;

        const x_edge = if (move_dir.x > 0) new_x + cnst.PLAYER_RADIUS else new_x - cnst.PLAYER_RADIUS;

        const x_block: usize = @intFromFloat(@floor(x_edge + 0.5));
        const z_start = @floor(original_pos.z - cnst.PLAYER_RADIUS + 0.5);
        const z_end = @floor(original_pos.z + cnst.PLAYER_RADIUS + 0.5);

        // Check all relevant Z positions
        var zb = z_start;
        while (zb <= z_end and !blocked_x) : (zb += 1) {
            if (x_block >= 0 and x_block < cnst.GRID_SIZE and zb >= 0 and zb < cnst.GRID_SIZE) {
                const terrain_height: f32 = @floatFromInt(terrain[@as(usize, x_block)][@as(usize, @intFromFloat(zb))]);
                // Block if terrain is higher than step height allows
                if (terrain_height > player_feet_y + cnst.STEP_HEIGHT) {
                    blocked_x = true;
                }
            }
        }

        // Apply X movement if not blocked
        if (!blocked_x) {
            camera.position.x = new_x;
        }

        // Z-axis movement check (using updated X position)
        const new_z = camera.position.z + move_dir.z;
        var blocked_z = false;

        const z_edge = if (move_dir.z > 0) new_z + cnst.PLAYER_RADIUS else new_z - cnst.PLAYER_RADIUS;

        const z_block: usize = @intFromFloat(@floor(z_edge + 0.5));
        const x_start = @floor(camera.position.x - cnst.PLAYER_RADIUS + 0.5);
        const x_end = @floor(camera.position.x + cnst.PLAYER_RADIUS + 0.5);

        // Check all relevant X positions
        var xb = x_start;
        while (xb <= x_end and !blocked_z) : (xb += 1) {
            if (xb >= 0 and xb < cnst.GRID_SIZE and z_block >= 0 and z_block < cnst.GRID_SIZE) {
                const terrain_height: f32 = @floatFromInt(terrain[@as(usize, @intFromFloat(xb))][@as(usize, z_block)]);
                // Block if terrain is higher than step height allows
                if (terrain_height > player_feet_y + cnst.STEP_HEIGHT) {
                    blocked_z = true;
                }
            }
        }

        if (!blocked_z) {
            camera.position.z = new_z;
        }
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
        const ground_y = @as(f32, @floatFromInt(terrain_height));
        const player_feet = camera.position.y - cnst.PLAYER_HEIGHT;

        // Allow stepping up/down within STEP_HEIGHT
        if (player_feet <= ground_y + cnst.STEP_HEIGHT and player_feet >= ground_y - 0.1) { // Allow small downward steps
            on_ground.* = true;
            velocity_y.* = 0;
            // Snap to ground if within step range
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
