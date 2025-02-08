const rl = @import("raylib");
const cnst = @import("constants.zig");

pub fn drawCrosshair() void {
    const screen_center_x = @as(f32, @floatFromInt(rl.getScreenWidth())) / 2.0;
    const screen_center_y = @as(f32, @floatFromInt(rl.getScreenHeight())) / 2.0;

    // Horizontal line
    rl.drawRectangle(
        @intFromFloat(screen_center_x - cnst.CROSSHAIR_SIZE / 2.0),
        @intFromFloat(screen_center_y - cnst.CROSSHAIR_THICKNESS / 2.0),
        @intFromFloat(cnst.CROSSHAIR_SIZE),
        @intFromFloat(cnst.CROSSHAIR_THICKNESS),
        cnst.CROSSHAIR_COLOR,
    );

    // Vertical line
    rl.drawRectangle(
        @intFromFloat(screen_center_x - cnst.CROSSHAIR_THICKNESS / 2.0),
        @intFromFloat(screen_center_y - cnst.CROSSHAIR_SIZE / 2.0),
        @intFromFloat(cnst.CROSSHAIR_THICKNESS),
        @intFromFloat(cnst.CROSSHAIR_SIZE),
        cnst.CROSSHAIR_COLOR,
    );
}
