const std = @import("std");
const rl = @import("raylib");
const fr = @import("frustum.zig");

const math = std.math;

const GRID_SIZE = 50;
const SCALE = 0.5; // Smaller scale for smoother terrain
const SCREEN_WIDTH = 1280;
const SCREEN_HEIGHT = 720;
const PLAYER_HEIGHT = 1.8;
const GRAVITY = 9.8;
const JUMP_FORCE = 7.0;

pub fn main() void {
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "ZigCraft");
    defer rl.closeWindow();

    rl.setTargetFPS(60);
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

    const terrain = generateTerrain();
    var is_cursor_on = false;

    while (!rl.windowShouldClose()) {
        handleInput(&is_cursor_on, &yaw, &pitch, &camera, &velocity_y, &on_ground, terrain);

        // Extract frustum planes once per frame
        const frustum = fr.extractFrustum(
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
        }

        // Draw the terrain
        for (terrain, 0..) |row, x| {
            for (row, 0..) |height, z| {
                // Stack blocks from Y=0 to Y=height
                for (0..height) |y| {
                    const pos = rl.Vector3.init(@floatFromInt(x), @floatFromInt(y), @floatFromInt(z));

                    // Skip rendering if block is outside the frustum
                    if (!fr.isCubeInFrustum(frustum, pos)) continue;

                    const color = if (y == height - 1) rl.Color.green else rl.Color.brown;
                    rl.drawCube(pos, 1, 1, 1, color);
                    rl.drawCubeWires(pos, 1, 1, 1, rl.Color.black);
                }
            }
        }
    }
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

fn generateTerrain() [GRID_SIZE][GRID_SIZE]u32 {
    var terrain: [GRID_SIZE][GRID_SIZE]u32 = undefined;
    for (&terrain, 0..) |*row, x| {
        for (row, 0..) |_, z| {
            const height = generateHeight(@as(f32, @floatFromInt(x)) * SCALE, @as(f32, @floatFromInt(z)) * SCALE);
            row[z] = height;
        }
    }
    return terrain;
}

fn handleInput(
    is_cursor_on: *bool,
    yaw: *f32,
    pitch: *f32,
    camera: *rl.Camera3D,
    velocity_y: *f32,
    on_ground: *bool,
    terrain: [GRID_SIZE][GRID_SIZE]u32,
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
    velocity_y.* -= GRAVITY * delta_time;
    camera.position.y += velocity_y.* * delta_time;

    // ========== Ground Collision ==========
    const block_x: usize = @intFromFloat(@floor(camera.position.x));
    const block_z: usize = @intFromFloat(@floor(camera.position.z));
    on_ground.* = false;

    if (block_x >= 0 and block_x < GRID_SIZE and block_z >= 0 and block_z < GRID_SIZE) {
        const terrain_height = terrain[block_x][block_z];
        const ground_y = @as(f32, @floatFromInt(terrain_height)) - 0.1;

        if (camera.position.y - PLAYER_HEIGHT <= ground_y) {
            on_ground.* = true;
            velocity_y.* = 0;
            camera.position.y = ground_y + PLAYER_HEIGHT;
        }
    }

    // Jump input
    if (on_ground.* and rl.isKeyPressed(rl.KeyboardKey.space)) {
        velocity_y.* = JUMP_FORCE;
    }

    // Update camera target
    camera.target = camera.position.add(front);
}
