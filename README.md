# Killer Xpress

A frantic vertically split-screen runner. Defend the train from below, destroy aliens from above.

Based on the classic Suicide Express game from the 1980s.

Play: https://mehesz.net/games/killer-xpress`

## How to Play

1. Open the project in Godot 4.4+
2. Press Play (F5)
3. **Bottom screen:** Swipe left/right to queue lane changes at junctions
4. **Top screen:** Tap/hold to shoot aliens flying in from the right
5. Survive as long as possible — speed increases over time!

## Controls

| Platform | Move | Shoot |
|----------|------|-------|
| Mobile | Swipe left/right on bottom half | Tap/hold on top half |
| Desktop | Left/Right arrow keys | Space bar |

## 5-Lane Junction System

The track has 5 parallel monorail lanes. The train **cannot** switch lanes freely — it must use **junctions** (crossover points) that scroll down the track.

- **Swipe left** queues a left turn signal — the train will switch left at the next junction that allows it
- **Swipe right** queues a right turn signal
- **No swipe** = the train continues straight
- Junctions show a **green indicator** showing where the train will go next
- If a junction has no straight path (left+right only), the train picks randomly

Junction types per lane:
- Edge lanes (1 and 5) can only turn inward
- Center lanes can turn left, right, both, or go straight
- Crossover tracks are drawn as diagonal connections between lanes

## Architecture

```
scenes/
├── title_screen.tscn     # Start menu
├── settings_screen.tscn  # Volume controls
├── main.tscn             # Split-screen game
├── game_over.tscn        # Score display + retry
├── combat_world.tscn     # Top viewport (side-scrolling aliens)
├── track_world.tscn      # Bottom viewport (5-lane monorail)
└── obstacle.tscn         # Track obstacle

scripts/
├── game_manager.gd       # Autoload: score, health, speed, game state
├── audio_manager.gd      # Autoload: music/SFX with volume settings
├── main.gd               # Viewport setup, HUD, input routing
├── combat_world.gd       # Enemy spawning, shooting, parallax (5 depth lanes)
├── track_world.gd        # 5-lane junction routing, input buffering, obstacles
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

v0.2 — 5-lane junction system with input buffering and turn indicators
