# Technical Design Document: Project "Killer Xpress" (Web/Mobile)

This is going to a be mobile friendly version of the classic Suicide Express game from the 1980s. The game will be called Killer Xpress, it will be played on the web via HTML but make sure it works well for iPhone and Android, because we had run into issues with sounds specifically in the past.

## 1. Project Overview
* **Target Platform:** Web Browser (Mobile-optimized)
* **Orientation:** Portrait Mode ONLY
* **Engine:** Godot 4.x
* **Visual Style:** Retro Pixel Art (Low-res base resolution scaled up)
* **Core Concept:** A frantic, vertically split-screen endless/level-based runner. The player controls an armed train, managing top-down track switching on the bottom screen and side-view combat on the top screen simultaneously.
* **Control Scheme:** One-handed touch controls. 

## 2. Display & Resolution Settings (Godot Specifics)
To achieve the requested crisp pixel art style on modern mobile screens:
* **Base Resolution:** 360x640 (or 270x480 for extreme retro feel).
* **Stretch Mode:** `canvas_items` or `viewport`.
* **Aspect:** `keep_width` or `expand` (to accommodate different mobile screen heights while preserving the portrait layout).
* **Texture Filter:** `Nearest` (crucial for crisp pixel art).

## 3. Scene Architecture & Viewports
The game relies heavily on Godot's SubViewport system to render the dual perspectives. 

### Recommended Scene Tree:
```text
Main (Node)
├── Global_GameManager (Autoload/Singleton for Score/State)
├── Split_Screen_UI (CanvasLayer)
│   └── VBoxContainer (Full Rect, Vertical split)
│       ├── Top_Combat_View (SubViewportContainer - Size Flags: Expand)
│       │   └── SubViewport
│       │       └── Combat_World_Scene (2D Side/Parallax view)
│       ├── Divider (ColorRect or TextureRect for the UI bezel)
│       └── Bottom_Track_View (SubViewportContainer - Size Flags: Expand)
│           └── SubViewport
│               └── Track_World_Scene (2D Top-down view)
└── Input_Overlay (CanvasLayer - Z-Index Highest)
    ├── Swipe_Zone (Control/Panel - Bottom 60% of screen)
    └── Shoot_Button (TouchScreenButton - Right side / Top side for thumb reach)
```

## 4. Core Mechanics & Logic

### A. The Track System (Bottom Viewport)
* **Perspective:** Top-down 2D. 
* **Movement:** The train is functionally stationary on the Y-axis (or moving at a constant speed while the camera follows). The tracks and obstacles scroll downwards towards the player.
* **Track Switching:** The track is divided into discrete "lanes" (e.g., 3 or 4 parallel lines).
    * **Input Buffering (CRITICAL):** Because the game is fast, swipes must be buffered. If the player swipes left, store a `wants_to_switch_left` boolean. When the train reaches the next valid junction/switch track, execute the lane change.
    * **Collision:** Hitting a dead-end or an oncoming hazard triggers a "Crash" state, communicating with the `Global_GameManager`.

### B. The Combat System (Top Viewport)
* **Perspective:** 2D Side-scrolling or Isometric.
* **Synchronization:** The scrolling speed of the background (parallax) and the appearance of enemies must sync with the speed of the train in the bottom viewport. If the train slows down on the tracks, the top screen must reflect this.
* **Shooting:** Handled via bullet instantiation. Enemies fly in patterns.
* **Damage:** The train has a unified health pool. Taking damage from an alien (top screen) or grazing an obstacle (bottom screen) reduces the same global health bar.

## 5. One-Handed Control Scheme Setup
Since the game must be playable with one hand in portrait mode, thumb ergonomics are paramount.

* **Swipe Zone (Left/Right):** Map an invisible `Control` node over the bottom half of the screen. Track `InputEventScreenTouch` (pressed vs. released) and `InputEventScreenDrag` to calculate a horizontal vector. If `drag_vector.x < -threshold`, trigger left lane switch.
* **Shooting Zone (Tap):** Place an invisible or semi-transparent floating button on the right edge of the screen, extending slightly up into the top viewport area so the thumb can naturally reach up to tap/hold it without obscuring the bottom track view.

### Godot Swipe Detection Pseudo-code:
```gdscript
var swipe_start = Vector2.ZERO
var minimum_drag = 20 # pixels

func _input(event):
    if event is InputEventScreenTouch:
        if event.pressed:
            swipe_start = event.position
        else:
            var swipe_end = event.position
            var swipe_dir = swipe_end - swipe_start
            if swipe_dir.length() > minimum_drag:
                if abs(swipe_dir.x) > abs(swipe_dir.y):
                    if swipe_dir.x > 0:
                        move_train_right()
                    else:
                        move_train_left()
```

## 6. Implementation Phases

**Phase 1: Project Skeleton & Viewports**
* Set up the base resolution and Nearest filtering.
* Construct the `VBoxContainer` with two `SubViewport` nodes.
* Add dummy sprites (simple colored squares) to both viewports to verify they render correctly.

**Phase 2: Locomotion & Grid**
* Build the bottom top-down view.
* Implement a scrolling rail system.
* Implement the swipe detection logic and map it to lane switching. 
* *Deliverable:* A colored square moving endlessly forward, dodging basic box obstacles by swiping.

**Phase 3: Top Screen & Synchronization**
* Build the top side-view.
* Sync the top view's background scrolling speed to the bottom view's train speed.
* Implement the shooting button and basic projectile logic.

**Phase 4: Game Loop & Polish**
* Add enemy spawning in the top view.
* Add health, score tracking, and a Game Over state.
* Prepare the project to have final pixel-art assets dragged and dropped onto the placeholder nodes.

## 7. Asset Integration Guidelines (For Later)
* Keep all sprites on a consistent Pixel Per Unit (PPU) grid.
* Use `Sprite2D` nodes, and ensure their texture filtering remains set to inherited (which should inherit `Nearest` from project settings).
* Design tracks as TileMaps (Godot 4 `TileMapLayer`) to easily paint complex rail networks and junctions.
