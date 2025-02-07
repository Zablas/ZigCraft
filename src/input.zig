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

    // ========== JUMP HANDLING (MUST COME FIRST) ==========
    if (on_ground.* and rl.isKeyPressed(rl.KeyboardKey.space)) {
        velocity_y.* = cnst.JUMP_FORCE;
        on_ground.* = false;
    }

    // ========== Horizontal Movement with Collisions ==========
    if (move_dir.length() > 0) {
        move_dir = move_dir.normalize().scale(5.0 * delta_time);

        // Apply air control reduction
        if (!on_ground.*) {
            move_dir = move_dir.scale(cnst.AIR_CONTROL);
        }

        // Split movement into components
        const original_pos = camera.position;
        var new_pos = original_pos;

        // X-axis movement with collision
        new_pos.x += move_dir.x;
        if (checkCollision(new_pos, terrain)) {
            new_pos.x = original_pos.x;
        }

        // Z-axis movement with collision
        new_pos.z += move_dir.z;
        if (checkCollision(new_pos, terrain)) {
            new_pos.z = original_pos.z;
        }

        camera.position = new_pos;
    }

    // ========== VERTICAL PHYSICS ==========
    if (!on_ground.*) {
        velocity_y.* -= cnst.GRAVITY * delta_time;
        camera.position.y += velocity_y.* * delta_time;
    }

    // ========== GROUND COLLISION ==========
    const ground_check = findHighestGround(camera.position, terrain);
    on_ground.* = false;

    // Revised ground detection with better range handling
    if (camera.position.y - cnst.PLAYER_HEIGHT <= ground_check.highest + cnst.GROUND_TOLERANCE and
        camera.position.y - cnst.PLAYER_HEIGHT >= ground_check.highest - cnst.MAX_SINK_DEPTH)
    {
        on_ground.* = true;
        velocity_y.* = 0;
        // Snap with safety margin to prevent sinking
        camera.position.y = ground_check.highest + cnst.PLAYER_HEIGHT + cnst.GROUND_SNAP_OFFSET;
    }

    // ========== ENHANCED FALLING COLLISION ==========
    if (!on_ground.* and velocity_y.* < 0) {
        // Get fresh ground data after movement
        const updated_ground = findHighestGround(camera.position, terrain);

        // Check full collision volume, not just feet
        if (camera.position.y - cnst.PLAYER_HEIGHT <= updated_ground.highest) {
            on_ground.* = true;
            velocity_y.* = 0;
            // Force precise ground alignment
            camera.position.y = updated_ground.highest + cnst.PLAYER_HEIGHT + cnst.GROUND_SNAP_OFFSET;
        }
    }

    // Update camera target
    camera.target = camera.position.add(front);
}

// Helper function: Check collision for horizontal movement
fn checkCollision(pos: rl.Vector3, terrain: [cnst.GRID_SIZE][cnst.GRID_SIZE]u32) bool {
    const player_feet = pos.y - cnst.PLAYER_HEIGHT;
    const player_top = pos.y;

    // Convert world coordinates to block grid with center alignment
    const min_x = @floor((pos.x - cnst.PLAYER_RADIUS) + cnst.BLOCK_CENTER_OFFSET);
    const max_x = @floor((pos.x + cnst.PLAYER_RADIUS) + cnst.BLOCK_CENTER_OFFSET);
    const min_z = @floor((pos.z - cnst.PLAYER_RADIUS) + cnst.BLOCK_CENTER_OFFSET);
    const max_z = @floor((pos.z + cnst.PLAYER_RADIUS) + cnst.BLOCK_CENTER_OFFSET);

    var xb = min_x;
    while (xb <= max_x) : (xb += 1) {
        var zb = min_z;
        while (zb <= max_z) : (zb += 1) {
            // Convert back to array indices
            const block_x = @as(usize, @intFromFloat(xb + cnst.BLOCK_CENTER_OFFSET));
            const block_z = @as(usize, @intFromFloat(zb + cnst.BLOCK_CENTER_OFFSET));

            if (block_x < cnst.GRID_SIZE and block_z < cnst.GRID_SIZE) {
                const block_height: f32 = @floatFromInt(terrain[block_x][block_z]);
                // Check collision in both vertical directions
                if (block_height > player_feet and block_height < player_top) {
                    return true;
                }
            }
        }
    }
    return false;
}

// Helper function: Find highest ground
fn findHighestGround(pos: rl.Vector3, terrain: [cnst.GRID_SIZE][cnst.GRID_SIZE]u32) struct { highest: f32 } {
    var highest: f32 = -math.inf(f32);

    // Expanded search area with overlap
    const min_x = @floor((pos.x - cnst.PLAYER_RADIUS) + cnst.BLOCK_CENTER_OFFSET);
    const max_x = @floor((pos.x + cnst.PLAYER_RADIUS) + cnst.BLOCK_CENTER_OFFSET);
    const min_z = @floor((pos.z - cnst.PLAYER_RADIUS) + cnst.BLOCK_CENTER_OFFSET);
    const max_z = @floor((pos.z + cnst.PLAYER_RADIUS) + cnst.BLOCK_CENTER_OFFSET);

    var xb = min_x;
    while (xb <= max_x) : (xb += 1) {
        var zb = min_z;
        while (zb <= max_z) : (zb += 1) {
            const block_x = @as(usize, @intFromFloat(xb + cnst.BLOCK_CENTER_OFFSET));
            const block_z = @as(usize, @intFromFloat(zb + cnst.BLOCK_CENTER_OFFSET));

            if (block_x < cnst.GRID_SIZE and block_z < cnst.GRID_SIZE) {
                const h: f32 = @floatFromInt(terrain[block_x][block_z]);
                if (h > highest) highest = h;
            }
        }
    }
    return .{ .highest = highest };
}
