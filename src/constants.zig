// Terrain constants
pub const GRID_SIZE = 50;
pub const SCALE = 0.5; // Smaller scale for smoother terrain

// Window constants
pub const SCREEN_WIDTH = 1280;
pub const SCREEN_HEIGHT = 720;

// Physics and collision constants
pub const PLAYER_HEIGHT = 1.8;
pub const PLAYER_RADIUS = 0.3; // Half of player width
pub const STEP_HEIGHT = 0.6; // Maximum step height without jumping
pub const GRAVITY = 26;
pub const JUMP_FORCE = 9.0;
pub const GROUND_TOLERANCE = 0.05;
pub const AIR_CONTROL = 0.35; // Reduced control while airborne
