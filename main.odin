package main

import rl "vendor:raylib"
import "core:math"
import "core:math/noise"
import "core:math/rand"



ANT_COUNT :: 100
RANDOM_TURN_STRENGTH :: 0.02
MAP_DIMENSIONS : [2]int : {16, 9} // the size of the map. Each integer has its own cell that stores different data
WINDOW_DIMENSIONS : [2]i32 : {1920, 1080}
CAMERA_ZOOM : f32 : 120
PHEROMONE_FRAME_LIFETIME : u64 : 600 // for how long a pheromone lasts for before disappearing
PHEROMONE_SPAWN_FREQUENCY : u16 : 120 // how many frames until a pheromone is spawned by an ant
TARGET_TURN_STRENGTH : f32 : 0.1 // how agressively ants will turn when they see targets like the food source or home
FOOD_SOURCE_RADIUS : f32 : 0.2
HOME_RADIUS : f32 : 0.2



Ant :: struct {
    pos: rl.Vector2,
    direction: rl.Vector2,
    velocity: f32,
    angular_velocity: f32,
    holding_food: bool,

    frames_until_pheromone_spawn: u16,

    walkspeed_multiplier: f32,
    turning_noise_seed: i64,
}

TileData :: struct {
    pheromones_made_when_scavenging: [dynamic]Pheromone,
    food_sources: [dynamic]FoodSource,
    homes: [dynamic]Home,
}

Pheromone :: struct {
    pos: rl.Vector2,
    dicipate_frame: u64 // what the runtime_frames variable has to be at until the pheromone gets deleted
}

FoodSource :: struct {
    pos: rl.Vector2,
    food_left: int
}

Home :: struct {
    pos: rl.Vector2,
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
            food_sources := make([dynamic]FoodSource)
            defer delete(food_sources)
            homes := make([dynamic]Home)
            defer delete(homes)

            tiles[x][y] = TileData {
                pheromones_made_when_scavenging,
                food_sources,
                homes,
            }
        }
    }

    // temp hard-coded food source spawning
    append(&tiles[14][2].food_sources, FoodSource{
        {14.5, 2.5},
        200,
    })
    // temp hard-coded home spawning
    append(&tiles[8][4].homes, Home{
        {8, 4.5},
    })

    // initialize ants
    for i in 0..<ANT_COUNT {

        ants[i] = Ant{
            {f32(MAP_DIMENSIONS.x) * 0.5, f32(MAP_DIMENSIONS.y) * 0.5},
            RotateV2({1, 0}, rand.float32_range(0, math.TAU)),
            0,
            0,
            false,

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

        ant.angular_velocity = 0

        LoopThroughTilesInAntRange(&ant)
        ant.angular_velocity += noise.noise_2d(ant.turning_noise_seed, {runtime_duration * 0.2, 0}) * RANDOM_TURN_STRENGTH

        ant.pos += ant.direction * ant.velocity * ant.walkspeed_multiplier

        ant.velocity += 0.0001
        ant.velocity = min(ant.velocity, 0.015)

        ant.direction = RotateV2(ant.direction, ant.angular_velocity)


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

                for &food_source in tiles[x][y].food_sources {
                    rl.DrawCircleV(food_source.pos, FOOD_SOURCE_RADIUS, {0, 255, 0, 255})
                }

                for &home in tiles[x][y].homes {
                    rl.DrawCircleV(home.pos, HOME_RADIUS, {255, 255, 0, 255})
                }
            }
        }

        // draw each ant
        for &ant in ants {
            ant_color: rl.Color = {100, 50, 200, 255}
            if ant.holding_food do ant_color = {50, 200, 100, 255}
            rl.DrawCircleV(ant.pos, 0.03, ant_color)
        }
    }
    rl.EndMode2D()

    rl.EndDrawing()
}



SpawnPheromone :: proc(pos: rl.Vector2) {

    // don't spawn a pheromone if it is out of bounds
    if int(pos.x) < 0 || int(pos.x) >= MAP_DIMENSIONS.x || int(pos.y) < 0 || int(pos.y) >= MAP_DIMENSIONS.y do return

    append(&tiles[int(pos.x)][int(pos.y)].pheromones_made_when_scavenging, Pheromone{
        pos,
        runtime_frames + PHEROMONE_FRAME_LIFETIME,
    })
}



LoopThroughTilesInAntRange :: proc(ant: ^Ant) {

    turn_amount_decided := false

    // loop through the indices of all tiles that are possible for the ant to see with its detection radius
    // (loops through all tiles in a 3x3 grid centered on the ant)
    for tile_x in max(int(ant.pos.x)-1, 0) ..< min(int(ant.pos.x)+2, MAP_DIMENSIONS.x) {
        for tile_y in max(int(ant.pos.y)-1, 0) ..< min(int(ant.pos.y)+2, MAP_DIMENSIONS.y) {

            // only turns if a turn hasn't been decided yet. It done so that when iterating through the next tiles, that they don't overwrite the turn with a lower priority target
            if !turn_amount_decided {
                ant.angular_velocity, turn_amount_decided = GetAntTurnAmount(ant, tile_x, tile_y)
            }

            // get food when touching food source, and leave food when touching home
            if !ant.holding_food {
                for &food_source, i in tiles[tile_x][tile_y].food_sources {
                    delta: rl.Vector2 = food_source.pos - ant.pos
                    if delta.x * delta.x + delta.y * delta.y < FOOD_SOURCE_RADIUS * FOOD_SOURCE_RADIUS {
                        ant.holding_food = true
                        food_source.food_left -= 1
                        if food_source.food_left <= 0 {
                            unordered_remove(&tiles[tile_x][tile_y].food_sources, i)
                        }
                    }
                }
            } else {
                // steer towards home if it is holding food
                for &home in tiles[tile_x][tile_y].homes {
                    delta: rl.Vector2 = home.pos - ant.pos
                    if delta.x * delta.x + delta.y * delta.y < HOME_RADIUS * HOME_RADIUS {
                        ant.holding_food = false
                    }
                }
            }



        }
    }
}


GetAntTurnAmount :: proc(ant: ^Ant, tile_x, tile_y: int) -> (turn_amount: f32, turn_decided: bool) {

    // steer towards food sources if it doesn't hold any food
    if !ant.holding_food {

        for &food_source in tiles[tile_x][tile_y].food_sources {
            if IsPosInLineOfSight(food_source.pos, ant.pos, ant.direction) {

                target_direction := NormalizedV2(food_source.pos - ant.pos)
                return DotProductV2({ant.direction.y, -ant.direction.x}, target_direction) * -TARGET_TURN_STRENGTH, true
            }
        }
    } else {
        // steer towards home if it is holding food
        for &home in tiles[tile_x][tile_y].homes {
            if IsPosInLineOfSight(home.pos, ant.pos, ant.direction) {

                target_direction := NormalizedV2(home.pos - ant.pos)
                return DotProductV2({ant.direction.y, -ant.direction.x}, target_direction) * -TARGET_TURN_STRENGTH, true
            }
        }
    }

    return 0, false
}



// checks if the specified position is able to be seen by an ant
IsPosInLineOfSight :: proc(pos, ant_pos, ant_direction: rl.Vector2) -> bool {

    // check if point is closer than the ant's detection radius of 1
    delta: rl.Vector2 = pos - ant_pos
    if delta.x * delta.x + delta.y * delta.y > 1 do return false

    // checks if point is within it's field of view using the dot product. A dot product of 0.7 is roughly equivalent to an FOV of 80
    if DotProductV2(ant_direction, NormalizedV2(delta)) < 0.7 do return false

    return true
}
