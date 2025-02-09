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

    const texture_atlas = rl.loadTexture("assets/terrain.png") catch |e| {
        std.log.err("Error loading textures: {s}", .{@errorName(e)});
        return;
    };
    defer rl.unloadTexture(texture_atlas);

    const DIRT_UV = rl.Rectangle{ .x = 32, .y = 0, .width = 16, .height = 16 };
    const GRASS_TOP_UV = rl.Rectangle{ .x = 0, .y = 0, .width = 16, .height = 16 };
    const GRASS_SIDE_UV = rl.Rectangle{ .x = 48, .y = 0, .width = 16, .height = 16 };

    const grass_mesh = createTexturedCubeMesh(GRASS_TOP_UV, GRASS_SIDE_UV, DIRT_UV);
    defer rl.unloadMesh(grass_mesh);

    const dirt_mesh = createTexturedCubeMesh(DIRT_UV, DIRT_UV, DIRT_UV);
    defer rl.unloadMesh(dirt_mesh);

    const default_material = rl.loadMaterialDefault() catch |e| {
        std.log.err("Error loading default material: {s}", .{@errorName(e)});
        return;
    };
    defer rl.unloadMaterial(default_material);

    const block_material: rl.Material = blk: {
        var mat = default_material;
        mat.maps[@intFromEnum(rl.MATERIAL_MAP_DIFFUSE)].texture = texture_atlas;
        break :blk mat;
    };

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

                    const transform = rl.Matrix.translate(pos.x, pos.y, pos.z);
                    if (y == height - 1) {
                        rl.drawMesh(grass_mesh, block_material, transform);
                    } else {
                        rl.drawMesh(dirt_mesh, block_material, transform);
                    }
                    rl.drawCubeWires(pos, 1, 1, 1, rl.Color.black);
                }
            }
        }
    }
}

fn createTexturedCubeMesh(top_uv: rl.Rectangle, side_uv: rl.Rectangle, bottom_uv: rl.Rectangle) rl.Mesh {
    const TILE_SIZE = 16.0;
    const ATLAS_SIZE = 256.0;

    var mesh = rl.genMeshCube(1.0, 1.0, 1.0);

    // UV coordinates (normalized 0-1)
    const uv = [_]f32{
        // Front face (side)
        side_uv.x / ATLAS_SIZE,                 side_uv.y / ATLAS_SIZE,
        (side_uv.x + TILE_SIZE) / ATLAS_SIZE,   side_uv.y / ATLAS_SIZE,
        (side_uv.x + TILE_SIZE) / ATLAS_SIZE,   (side_uv.y + TILE_SIZE) / ATLAS_SIZE,
        side_uv.x / ATLAS_SIZE,                 (side_uv.y + TILE_SIZE) / ATLAS_SIZE,

        // Back face (side)
        side_uv.x / ATLAS_SIZE,                 side_uv.y / ATLAS_SIZE,
        (side_uv.x + TILE_SIZE) / ATLAS_SIZE,   side_uv.y / ATLAS_SIZE,
        (side_uv.x + TILE_SIZE) / ATLAS_SIZE,   (side_uv.y + TILE_SIZE) / ATLAS_SIZE,
        side_uv.x / ATLAS_SIZE,                 (side_uv.y + TILE_SIZE) / ATLAS_SIZE,

        // Top face
        top_uv.x / ATLAS_SIZE,                  top_uv.y / ATLAS_SIZE,
        (top_uv.x + TILE_SIZE) / ATLAS_SIZE,    top_uv.y / ATLAS_SIZE,
        (top_uv.x + TILE_SIZE) / ATLAS_SIZE,    (top_uv.y + TILE_SIZE) / ATLAS_SIZE,
        top_uv.x / ATLAS_SIZE,                  (top_uv.y + TILE_SIZE) / ATLAS_SIZE,

        // Bottom face
        bottom_uv.x / ATLAS_SIZE,               bottom_uv.y / ATLAS_SIZE,
        (bottom_uv.x + TILE_SIZE) / ATLAS_SIZE, bottom_uv.y / ATLAS_SIZE,
        (bottom_uv.x + TILE_SIZE) / ATLAS_SIZE, (bottom_uv.y + TILE_SIZE) / ATLAS_SIZE,
        bottom_uv.x / ATLAS_SIZE,               (bottom_uv.y + TILE_SIZE) / ATLAS_SIZE,

        // Left face (side)
        side_uv.x / ATLAS_SIZE,                 side_uv.y / ATLAS_SIZE,
        (side_uv.x + TILE_SIZE) / ATLAS_SIZE,   side_uv.y / ATLAS_SIZE,
        (side_uv.x + TILE_SIZE) / ATLAS_SIZE,   (side_uv.y + TILE_SIZE) / ATLAS_SIZE,
        side_uv.x / ATLAS_SIZE,                 (side_uv.y + TILE_SIZE) / ATLAS_SIZE,

        // Right face (side)
        side_uv.x / ATLAS_SIZE,                 side_uv.y / ATLAS_SIZE,
        (side_uv.x + TILE_SIZE) / ATLAS_SIZE,   side_uv.y / ATLAS_SIZE,
        (side_uv.x + TILE_SIZE) / ATLAS_SIZE,   (side_uv.y + TILE_SIZE) / ATLAS_SIZE,
        side_uv.x / ATLAS_SIZE,                 (side_uv.y + TILE_SIZE) / ATLAS_SIZE,
    };

    std.log.debug("UV: {any}", .{uv});

    rl.updateMeshBuffer(mesh, 1, &uv, uv.len, 0);
    rl.uploadMesh(&mesh, false);
    return mesh;
}
