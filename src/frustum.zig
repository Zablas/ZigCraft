const rl = @import("raylib");

pub const Plane = struct {
    normal: rl.Vector3,
    distance: f32,
};

pub const Frustum = struct {
    planes: [6]Plane = [_]Plane{undefined} ** 6,
};

pub fn extractFrustum(camera: rl.Camera3D, screen_width: f32, screen_height: f32) Frustum {
    // Get view and projection matrices
    const view = rl.getCameraMatrix(camera);
    const aspect = screen_width / screen_height;
    const projection = rl.Matrix.perspective(camera.fovy, aspect, 0.01, 1000.0);
    const view_proj = view.multiply(projection);

    var frustum = Frustum{};

    // Left plane (column-major order)
    frustum.planes[0] = Plane{
        .normal = .{ .x = view_proj.m3 + view_proj.m0, .y = view_proj.m7 + view_proj.m4, .z = view_proj.m11 + view_proj.m8 },
        .distance = view_proj.m15 + view_proj.m12,
    };
    // Right plane
    frustum.planes[1] = Plane{
        .normal = .{ .x = view_proj.m3 - view_proj.m0, .y = view_proj.m7 - view_proj.m4, .z = view_proj.m11 - view_proj.m8 },
        .distance = view_proj.m15 - view_proj.m12,
    };
    // Bottom plane
    frustum.planes[2] = Plane{
        .normal = .{ .x = view_proj.m3 + view_proj.m1, .y = view_proj.m7 + view_proj.m5, .z = view_proj.m11 + view_proj.m9 },
        .distance = view_proj.m15 + view_proj.m13,
    };
    // Top plane
    frustum.planes[3] = Plane{
        .normal = .{ .x = view_proj.m3 - view_proj.m1, .y = view_proj.m7 - view_proj.m5, .z = view_proj.m11 - view_proj.m9 },
        .distance = view_proj.m15 - view_proj.m13,
    };
    // Near plane
    frustum.planes[4] = Plane{
        .normal = .{ .x = view_proj.m3 + view_proj.m2, .y = view_proj.m7 + view_proj.m6, .z = view_proj.m11 + view_proj.m10 },
        .distance = view_proj.m15 + view_proj.m14,
    };
    // Far plane
    frustum.planes[5] = Plane{
        .normal = .{ .x = view_proj.m3 - view_proj.m2, .y = view_proj.m7 - view_proj.m6, .z = view_proj.m11 - view_proj.m10 },
        .distance = view_proj.m15 - view_proj.m14,
    };

    // Normalize planes
    for (&frustum.planes) |*plane| {
        const length = @sqrt(plane.normal.x * plane.normal.x +
            plane.normal.y * plane.normal.y +
            plane.normal.z * plane.normal.z);
        plane.normal.x /= length;
        plane.normal.y /= length;
        plane.normal.z /= length;
        plane.distance /= length;
    }

    return frustum;
}

pub fn isCubeInFrustum(frustum: Frustum, pos: rl.Vector3) bool {
    const cube_half_size = 0.5; // For 1x1x1 cubes
    const cube_max = rl.Vector3{
        .x = pos.x + cube_half_size,
        .y = pos.y + cube_half_size,
        .z = pos.z + cube_half_size,
    };

    for (frustum.planes) |plane| {
        const dist = plane.normal.x * cube_max.x + plane.normal.y * cube_max.y + plane.normal.z * cube_max.z + plane.distance;
        if (dist < 0) return false; // Cube is outside the plane
    }
    return true;
}
