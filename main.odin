package main

import rl "vendor:raylib"
import "core:math"
import "core:math/noise"
import "core:math/rand"



ANT_COUNT :: 100



Ant :: struct {
    pos: rl.Vector2,
    angle: f32,
    velocity: f32,
    angular_velocity: f32,

    walk_speed_multiplier: f32,
    turning_noise_seed: i64,
}



runtime_length: f64
ants: [ANT_COUNT]Ant

main :: proc() {

    rl.InitWindow(1920, 1080, "ant simulator")
    rl.ToggleFullscreen()
    rl.SetExitKey(.KEY_NULL)
    rl.SetTargetFPS(60)
    rl.DisableCursor()

    // initialize ants
    for i in 0..<ANT_COUNT {
        ants[i] = Ant{
            {1920/2, 1080/2}, // NOTE! MAKE THESE INTO WORLD_SPACE COORDINATES LATER INSTEAD OF SCEREN_SPACE, WHERE YOU ALSO USE A CAMERA!
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

        ant.velocity += 0.01
        ant.velocity = min(ant.velocity, 1.5)

        ant.angle += ant.angular_velocity

        ant.angular_velocity = noise.noise_2d(ant.turning_noise_seed, {runtime_length * 0.2, 0}) * 0.01
    }

    runtime_length += f64(rl.GetFrameTime())
}



Draw :: proc() {
    rl.BeginDrawing()
    rl.ClearBackground({20, 15, 15, 255}) // set background to this

    for &ant in ants {
        rl.DrawCircleV(ant.pos, 10, {255, 20, 20, 255})
    }

    rl.EndDrawing()
}
