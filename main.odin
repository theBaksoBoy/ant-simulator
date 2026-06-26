package main

import rl "vendor:raylib"
import "core:math"
import "core:math/noise"
import "core:math/rand"



ANT_COUNT :: 100
MAP_DIMENSIONS : rl.Vector2 : {16, 9}
WINDOW_DIMENSIONS : [2]i32 : {1920, 1080}



Ant :: struct {
    pos: rl.Vector2,
    angle: f32,
    velocity: f32,
    angular_velocity: f32,

    walk_speed_multiplier: f32,
    turning_noise_seed: i64,
}



camera := rl.Camera2D{
    {f32(WINDOW_DIMENSIONS.x) * 0.5, f32(WINDOW_DIMENSIONS.y) * 0.5},
    MAP_DIMENSIONS * 0.5,
    0,
    115,
}
runtime_length: f64
ants: [ANT_COUNT]Ant

main :: proc() {

    rl.InitWindow(WINDOW_DIMENSIONS.x, WINDOW_DIMENSIONS.y, "ant simulator")
    rl.ToggleFullscreen()
    rl.SetExitKey(.KEY_NULL)
    rl.SetTargetFPS(60)
    rl.DisableCursor()

    // initialize ants
    for i in 0..<ANT_COUNT {

        ants[i] = Ant{
            MAP_DIMENSIONS * 0.5,
            rand.float32_range(0, math.TAU),
            0,
            0,
            rand.float32_range(0.8, 1.2),
            rand.int63(),
        }
    }

    for !rl.WindowShouldClose() {
        Update()
        Draw()
    }
    rl.CloseWindow()
}



Update :: proc() {

    for &ant in ants {
        ant.pos.x += math.cos(ant.angle) * ant.velocity * ant.walk_speed_multiplier
        ant.pos.y += math.sin(ant.angle) * ant.velocity * ant.walk_speed_multiplier

        ant.velocity += 0.0001
        ant.velocity = min(ant.velocity, 0.015)

        ant.angle += ant.angular_velocity

        ant.angular_velocity = noise.noise_2d(ant.turning_noise_seed, {runtime_length * 0.2, 0}) * 0.01
    }

    runtime_length += f64(rl.GetFrameTime())
}



Draw :: proc() {
    rl.BeginDrawing()
    rl.ClearBackground({20, 15, 15, 255}) // set background to this

    rl.BeginMode2D(camera)
    {
        for &ant in ants {
            rl.DrawCircleV(ant.pos, 0.1, {255, 20, 20, 255})
        }
    }
    rl.EndMode2D()

    rl.EndDrawing()
}
