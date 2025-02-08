const rl = @import("raylib");

// Terrain constants
pub const GRID_SIZE = 50;
pub const SCALE = 0.5; // Smaller scale for smoother terrain

// Window constants
pub const SCREEN_WIDTH = 1280;
pub const SCREEN_HEIGHT = 720;

// Physics and collision constants
pub const PLAYER_HEIGHT = 1.8;
pub const PLAYER_RADIUS = 0.3; // Half of player width
pub const GRAVITY = 26;
pub const JUMP_FORCE = 9.0;
pub const GROUND_TOLERANCE = 0.05;
pub const BLOCK_CENTER_OFFSET = 0.5; // Blocks are centered at integer coordinates
pub const MAX_SINK_DEPTH = 0.2; // Allow snapping even if slightly sunk
pub const GROUND_SNAP_OFFSET = 0.01; // Safety margin above ground
pub const MAX_STEP_DELTA = 1.6; // Maximum vertical difference allowed when moving

// UI
pub const CROSSHAIR_SIZE = 10.0;
pub const CROSSHAIR_THICKNESS = 2.0;
pub const CROSSHAIR_COLOR = rl.Color.light_gray;
