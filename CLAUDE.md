# Project: FlappyBird2026

## What This Project Does

A remake of the mobile game "Flappy Bird" from 2013.
Making use of modern tech stacks, aimed for crossplatform release.
The goal is a remake which is as close 1:1 to the original.

## Directory Layout

```
assets/gfx/        → contains the atlas with all images used in the game
assets/sounds/     → audio files used in the game
```

## Essential Commands

```bash
# Lint (must pass before committing)
gdlint .
gdformat --check .
```

## Project-Specific Rules

The project structure consists of a single main scene that contains the game world and UI,
following Godot’s recommendation of a Main → World → GUI split.

Main.tscn:

- Node (root): Node (or Node2D if preferred) – Main
  - Node2D – World
  - CanvasLayer – GUI

Main.gd handles starting/restarting the game and switching between menus/gameplay.

World is a separate scene instanced under Main, containing the bird, pipe spawner,
ground and background.

World.tscn (root: Node2D – World):

- ParallaxBackground
  - ParallaxLayer
    - Sprite2D – Background (from atlas)
- Node2D – GameLayer (everything that moves)
  - Bird (separate scene instance)
  - Node2D – PipeSpawner
  - Node2D – Pipes (container node that holds all active pipe pairs)
  - Node2D – GroundScroller
- Node2D – GameplayLogic

World.gd responsibilities:

- Start/stop timers in PipeSpawner, reset positions, track score.
- Emit signals like game_over and score_changed that Main/GUI can listen to.

Bird.tscn (root: CharacterBody2D or Area2D – Bird):

- Sprite2D – uses bird frames from the atlas
  (or AnimatedSprite2D for flapping animation).
- CollisionShape2D – rectangle or capsule.
- AudioStreamPlayer – flap sound.

Bird.gd:

- Exports gravity, flap impulse, max fall speed.
- In _physics_process, gravity and flap on tap/press.
- Emits hit signal when colliding with pipes or ground.

Pipes (obstacles) scene:

Each pipe pair should be one reusable scene that the spawner instantiates.

PipePair.tscn (root: Node2D – PipePair):

- StaticBody2D – TopPipe
  - Sprite2D
  - CollisionShape2D
- StaticBody2D – BottomPipe
  - Sprite2D
  - CollisionShape2D
- Area2D – ScoreZone
  - CollisionShape2D (thin vertical rectangle where the bird passes)
- A Timer or movement in script to scroll left.

PipePair.gd:

- Moves itself left each frame and frees itself when off‑screen.
- Emits passed when the bird hits ScoreZone once (increment score).

Pipe spawner:

Keep spawning logic separate from the pipes.

In World.tscn under GameLayer:

- Node2D – PipeSpawner
  - Timer – SpawnTimer

PipeSpawner.gd:

- Export PackedScene for PipePair, spawn interval, vertical gap, and height range.
- On SpawnTimer.timeout, instance PipePair, randomize Y position within range, and add as child of Pipes.

Ground / floor:

Scrolling ground that also acts as a collider.

Ground.tscn:

- StaticBody2D – Ground
  - Sprite2D (tiled/looped from atlas)
  - CollisionShape2D
- Ground.gd: Move texture UV or cycle two sprites to create infinite scrolling.

GroundScroller in World contains one or two Ground instances and moves them left to reuse.

GUI / HUD scene:

Keep UI in a CanvasLayer so it stays fixed on screen.

GUI.tscn (root: CanvasLayer – GUI):

- Control – HUD
  - Label – ScoreLabel
- Control – Menu
  - Label – TitleLabel
  - Button – PlayButton
- Control – GameOverPanel
  - Label – FinalScoreLabel
  - Button – RetryButton

GUI.gd:

- Receives signals score_changed and game_over from World and updates or shows the relevant UI.
- Emits start_game, retry, pause, etc., upward to Main.

Signal wiring:

Use signals to keep scenes decoupled, as Godot’s best practices recommend.

Typical connections:

- Bird.hit → World.on_bird_hit (stop game, emit game_over).
- PipePair.passed → World.on_pipe_passed → increment score and emit score_changed.
- GUI.start_game / GUI.retry → Main → reset or reload World.
- World.game_over → GUI.show_game_over.

## Skills Available

- `codebase-navigator` — use when first exploring this repo
- `code-quality` — use before committing any changes

## See Also

@README.md
