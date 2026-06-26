package main

import rl "vendor:raylib"
import "core:math"
import "core:math/noise"
import "core:math/rand"



ANT_COUNT :: 100
MAP_DIMENSIONS : [2]int : {16, 9} // the size of the map. Each integer has its own cell that stores different data
WINDOW_DIMENSIONS : [2]i32 : {1920, 1080}
CAMERA_ZOOM : f32 : 120
PHEROMONE_FRAME_LIFETIME : u64 : 600 // for how long a pheromone lasts for before disappearing
PHEROMONE_SPAWN_FREQUENCY : u16 : 120 // how many frames until a pheromone is spawned by an ant



Ant :: struct {
    pos: rl.Vector2,
    direction: rl.Vector2,
    velocity: f32,
    angular_velocity: f32,

    frames_until_pheromone_spawn: u16,

    walkspeed_multiplier: f32,
    turning_noise_seed: i64,
}



TileData :: struct {
    pheromones_made_when_scavenging: [dynamic]Pheromone
}



Pheromone :: struct {
    pos: rl.Vector2,
    dicipate_frame: u64 // what the runtime_frames variable has to be at until the pheromone gets deleted
}



camera := rl.Camera2D{
    {f32(WINDOW_DIMENSIONS.x) * 0.5, f32(WINDOW_DIMENSIONS.y) * 0.5},
    {f32(MAP_DIMENSIONS.x) * 0.5, f32(MAP_DIMENSIONS.y) * 0.5},
    0,
    CAMERA_ZOOM,
}
tiles: [MAP_DIMENSIONS.x][MAP_DIMENSIONS.y]TileData
runtime_duration: f64 // how long the program has been running for in seconds
runtime_frames: u64 // how long the program has been running for in frames
ants: [ANT_COUNT]Ant

main :: proc() {

    rl.InitWindow(WINDOW_DIMENSIONS.x, WINDOW_DIMENSIONS.y, "ant simulator")
    rl.ToggleFullscreen()
    rl.SetExitKey(.KEY_NULL)
    rl.SetTargetFPS(60)

    // initialize tiles
    for x in 0..<MAP_DIMENSIONS.x {
        for y in 0..<MAP_DIMENSIONS.y {

            pheromones_made_when_scavenging := make([dynamic]Pheromone)
            defer delete(pheromones_made_when_scavenging)

            tiles[x][y] = TileData {
                pheromones_made_when_scavenging,
            }
        }
    }

    // initialize ants
    for i in 0..<ANT_COUNT {

        ants[i] = Ant{
            {f32(MAP_DIMENSIONS.x) * 0.5, f32(MAP_DIMENSIONS.y) * 0.5},
            RotateVector2({1, 0}, rand.float32_range(0, math.TAU)),
            0,
            0,

            u16(rand.int31() % i32(PHEROMONE_SPAWN_FREQUENCY)),

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
        ant.pos += ant.direction * ant.velocity * ant.walkspeed_multiplier

        ant.velocity += 0.0001
        ant.velocity = min(ant.velocity, 0.015)

        ant.direction = RotateVector2(ant.direction, ant.angular_velocity)

        ant.angular_velocity = noise.noise_2d(ant.turning_noise_seed, {runtime_duration * 0.2, 0}) * 0.01

        // temporary logic for making them not go out of bounds
        if ant.pos.x < 0.01 {
            ant.pos.x = 0.01
            ant.direction *= -1
        }
        if ant.pos.x > f32(MAP_DIMENSIONS.x) - 0.01 {
            ant.pos.x = f32(MAP_DIMENSIONS.x) - 0.01
            ant.direction *= -1
        }
        if ant.pos.y < 0.01 {
            ant.pos.y = 0.01
            ant.direction *= -1
        }
        if ant.pos.y > f32(MAP_DIMENSIONS.y) - 0.01 {
            ant.pos.y = f32(MAP_DIMENSIONS.y) - 0.01
            ant.direction *= -1
        }

        ant.frames_until_pheromone_spawn -= 1
        if ant.frames_until_pheromone_spawn <= 0 {
            ant.frames_until_pheromone_spawn = PHEROMONE_SPAWN_FREQUENCY
            SpawnPheromone(ant.pos)
        }
    }


    // loop through each tile
    for x in 0..<MAP_DIMENSIONS.x {
        for y in 0..<MAP_DIMENSIONS.y {

            for &pheromone, i in tiles[x][y].pheromones_made_when_scavenging {

                // deleting items from the array can cause index to go out of bounds. This prevents that from happening
                if i >= len(tiles[x][y].pheromones_made_when_scavenging) do break

                if runtime_frames > pheromone.dicipate_frame {
                    // I think an unordered remove makes it possible that some pheromones that should be removed are skipped, but they will be deleted next frame so it's fine
                    unordered_remove(&tiles[x][y].pheromones_made_when_scavenging, i)
                }
            }
        }
    }

    runtime_duration += f64(rl.GetFrameTime())
    runtime_frames += 1
}



Draw :: proc() {
    rl.BeginDrawing()
    rl.ClearBackground({20, 15, 15, 255}) // set background to this

    rl.BeginMode2D(camera)
    {
        // loop through each tile
        for x in 0..<MAP_DIMENSIONS.x {
            for y in 0..<MAP_DIMENSIONS.y {

                for &pheromone in tiles[x][y].pheromones_made_when_scavenging {
                    rl.DrawRectangleV(pheromone.pos, {1/CAMERA_ZOOM, 1/CAMERA_ZOOM}, {255, 0, 0, 255}) // wacky thing done here instead of DrawPixel as the drawn pixels become huge due to the camera zoom
                }
            }
        }

        // draw each ant
        for &ant in ants {
            rl.DrawCircleV(ant.pos, 0.03, {100, 50, 200, 255})
        }
    }
    rl.EndMode2D()

    rl.EndDrawing()
}



SpawnPheromone :: proc(pos: rl.Vector2) {
    append(&tiles[int(pos.x)][int(pos.y)].pheromones_made_when_scavenging, Pheromone{
        pos,
        runtime_frames + PHEROMONE_FRAME_LIFETIME,
    })
}



RotateVector2 :: proc (vec: rl.Vector2, angle: f32) -> rl.Vector2 {

    sin_angle := math.sin_f32(angle)
    cos_angle := math.cos_f32(angle)

    return rl.Vector2{vec.x * cos_angle - vec.y * sin_angle, vec.x * sin_angle + vec.y * cos_angle}
}
