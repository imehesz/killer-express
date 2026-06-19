# Killer Xpress

A frantic vertically split-screen runner. Defend the train from below, destroy aliens from above.

Based on the classic Suicide Express game from the 1980s.

## How to Play

1. Open the project in Godot 4.4+
2. Press Play (F5)
3. **Bottom screen:** Swipe left/right to dodge obstacles on the track
4. **Top screen:** Tap/hold to shoot aliens flying in from the right
5. Survive as long as possible — speed increases over time!

## Controls

| Platform | Move | Shoot |
|----------|------|-------|
| Mobile | Swipe left/right on bottom half | Tap/hold on top half |
| Desktop | Left/Right arrow keys | Space bar |

## Architecture

```
scenes/
├── title_screen.tscn     # Start menu
├── settings_screen.tscn  # Volume controls
├── main.tscn             # Split-screen game
├── game_over.tscn        # Score display + retry
├── combat_world.tscn     # Top viewport (side-scrolling aliens)
├── track_world.tscn      # Bottom viewport (3-lane track)
└── obstacle.tscn         # Track obstacle

scripts/
├── game_manager.gd       # Autoload: score, health, speed, game state
├── audio_manager.gd      # Autoload: music/SFX with volume settings
├── main.gd               # Viewport setup, HUD, input routing
├── combat_world.gd       # Enemy spawning, shooting, parallax
├── track_world.gd        # Lane switching, obstacle avoidance
├── title_screen.gd       # Menu navigation
├── settings_screen.gd    # Volume sliders
├── game_over.gd          # Final score + retry
└── obstacle.gd           # Obstacle entity

web_template/
└── index.html            # Custom HTML shell for mobile audio fix
```

## Mobile Audio Fix

This project includes a custom HTML shell that fixes the AudioContext
suspension issue on iOS/Android browsers. The fix has two parts:

1. "TAP TO PLAY" overlay prevents engine start before user interaction
2. Persistent click/touch handler resumes AudioContext after WASM loads

## Web Export

1. Project > Export > Add "Web" preset
2. Set Custom HTML Shell to `res://web_template/index.html`
3. Export and serve with any HTTP server

## Settings

The Settings screen allows adjusting:
- Music volume (0-100%)
- SFX volume (0-100%)

Settings are saved to `user://settings.cfg` and persist between sessions.

## Version

v0.1 — Initial prototype with placeholder pixel art
