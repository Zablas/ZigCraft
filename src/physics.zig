const std = @import("std");
const rl = @import("raylib");
const cnst = @import("constants.zig");

const math = std.math;

pub fn handlePhysics(
    on_ground: *bool,
    velocity_y: *f32,
    move_dir: *rl.Vector3,
    camera: *rl.Camera3D,
    terrain: [cnst.GRID_SIZE][cnst.GRID_SIZE]u32,
) void {
    const delta_time = rl.getFrameTime();

    // ========== JUMP HANDLING (MUST COME FIRST) ==========
    if (on_ground.* and rl.isKeyPressed(rl.KeyboardKey.space)) {
        velocity_y.* = cnst.JUMP_FORCE;
        on_ground.* = false;
    }

    // ========== Horizontal Movement with Collisions ==========
    if (move_dir.length() > 0) {
        move_dir.* = move_dir.normalize().scale(5.0 * delta_time);

        const original_pos = camera.position;
        const current_ground = findHighestGround(original_pos, terrain).highest;

        // Temporary position for collision checks
        var temp_pos = original_pos;

        // X-axis movement
        temp_pos.x += move_dir.x;
        var blocked_x = checkCollision(temp_pos, terrain);

        // Check ground height difference for X movement
        if (!blocked_x) {
            const new_ground_x = findHighestGround(temp_pos, terrain).highest;
            if (new_ground_x - current_ground > cnst.MAX_STEP_DELTA) {
                blocked_x = true;
            }
        }

        if (!blocked_x) {
            camera.position.x = temp_pos.x;
        }

        // Z-axis movement (use updated X position)
        temp_pos = camera.position;
        temp_pos.z += move_dir.z;
        var blocked_z = checkCollision(temp_pos, terrain);

        // Check ground height difference for Z movement
        if (!blocked_z) {
            const new_ground_z = findHighestGround(temp_pos, terrain).highest;
            const current_ground_z = findHighestGround(camera.position, terrain).highest;
            if (new_ground_z - current_ground_z > cnst.MAX_STEP_DELTA) {
                blocked_z = true;
            }
        }

        if (!blocked_z) {
            camera.position.z = temp_pos.z;
        }
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
}

// Helper function: Check collision for horizontal movement
fn checkCollision(pos: rl.Vector3, terrain: [cnst.GRID_SIZE][cnst.GRID_SIZE]u32) bool {
    const player_feet = pos.y - cnst.PLAYER_HEIGHT;
    const player_top = pos.y;

    // Check collision area with block center alignment
    const min_x = @floor((pos.x - cnst.PLAYER_RADIUS) + cnst.BLOCK_CENTER_OFFSET);
    const max_x = @floor((pos.x + cnst.PLAYER_RADIUS) + cnst.BLOCK_CENTER_OFFSET);
    const min_z = @floor((pos.z - cnst.PLAYER_RADIUS) + cnst.BLOCK_CENTER_OFFSET);
    const max_z = @floor((pos.z + cnst.PLAYER_RADIUS) + cnst.BLOCK_CENTER_OFFSET);

    var collision = false;

    var xb = min_x;
    while (xb <= max_x and !collision) : (xb += 1) {
        var zb = min_z;
        while (zb <= max_z and !collision) : (zb += 1) {
            const block_x: usize = @intFromFloat(xb + cnst.BLOCK_CENTER_OFFSET);
            const block_z: usize = @intFromFloat(zb + cnst.BLOCK_CENTER_OFFSET);

            if (block_x < cnst.GRID_SIZE and block_z < cnst.GRID_SIZE) {
                const block_height: f32 = @floatFromInt(terrain[block_x][block_z]);
                // Check if block intersects player's vertical space
                if (block_height > player_feet and block_height < player_top) {
                    collision = true;
                }
            }
        }
    }
    return collision;
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
            const block_x: usize = @intFromFloat(xb + cnst.BLOCK_CENTER_OFFSET);
            const block_z: usize = @intFromFloat(zb + cnst.BLOCK_CENTER_OFFSET);

            if (block_x < cnst.GRID_SIZE and block_z < cnst.GRID_SIZE) {
                const h: f32 = @floatFromInt(terrain[block_x][block_z]);
                if (h > highest) highest = h;
            }
        }
    }
    return .{ .highest = highest };
}
