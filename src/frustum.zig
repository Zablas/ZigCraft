const rl = @import("raylib");

pub const Plane = struct {
    normal: rl.Vector3,
    distance: f32,
};

pub const Frustum = struct {
    planes: [6]rl.Vector4 = [_]rl.Vector4{undefined} ** 6,

    pub fn init(camera: rl.Camera3D, screen_width: f32, screen_height: f32) Frustum {
        const view = rl.getCameraMatrix(camera);
        const aspect = screen_width / screen_height;
        const projection = rl.Matrix.perspective(camera.fovy, aspect, 0.01, 1000.0);
        const mat = view.multiply(projection);
        var frustum = Frustum{};

        // Extract planes (column-major order)
        // Left plane
        frustum.planes[0] = .{
            .x = mat.m3 + mat.m0,
            .y = mat.m7 + mat.m4,
            .z = mat.m11 + mat.m8,
            .w = mat.m15 + mat.m12,
        };
        // Right plane
        frustum.planes[1] = .{
            .x = mat.m3 - mat.m0,
            .y = mat.m7 - mat.m4,
            .z = mat.m11 - mat.m8,
            .w = mat.m15 - mat.m12,
        };
        // Bottom plane
        frustum.planes[2] = .{
            .x = mat.m3 + mat.m1,
            .y = mat.m7 + mat.m5,
            .z = mat.m11 + mat.m9,
            .w = mat.m15 + mat.m13,
        };
        // Top plane
        frustum.planes[3] = .{
            .x = mat.m3 - mat.m1,
            .y = mat.m7 - mat.m5,
            .z = mat.m11 - mat.m9,
            .w = mat.m15 - mat.m13,
        };
        // Near plane
        frustum.planes[4] = .{
            .x = mat.m3 + mat.m2,
            .y = mat.m7 + mat.m6,
            .z = mat.m11 + mat.m10,
            .w = mat.m15 + mat.m14,
        };
        // Far plane
        frustum.planes[5] = .{
            .x = mat.m3 - mat.m2,
            .y = mat.m7 - mat.m6,
            .z = mat.m11 - mat.m10,
            .w = mat.m15 - mat.m14,
        };

        // Normalize planes
        for (&frustum.planes) |*plane| {
            const length = @sqrt(plane.x * plane.x + plane.y * plane.y + plane.z * plane.z);
            plane.x /= length;
            plane.y /= length;
            plane.z /= length;
            plane.w /= length;
        }

        return frustum;
    }

    pub fn containsCube(self: Frustum, center: rl.Vector3, half_size: f32) bool {
        const min = rl.Vector3{
            .x = center.x - half_size,
            .y = center.y - half_size,
            .z = center.z - half_size,
        };
        const max = rl.Vector3{
            .x = center.x + half_size,
            .y = center.y + half_size,
            .z = center.z + half_size,
        };

        for (self.planes) |plane| {
            // Find farthest point from plane
            const x = if (plane.x > 0) max.x else min.x;
            const y = if (plane.y > 0) max.y else min.y;
            const z = if (plane.z > 0) max.z else min.z;

            // Calculate distance
            const distance = plane.x * x + plane.y * y + plane.z * z + plane.w;
            if (distance < 0) return false;
        }
        return true;
    }
};
