package main

import rl "vendor:raylib"
import "core:math"



RotateV2 :: proc (vec: rl.Vector2, angle: f32) -> rl.Vector2 {

    if angle == 0 do return vec

    sin_angle := math.sin_f32(angle)
    cos_angle := math.cos_f32(angle)

    return rl.Vector2{vec.x * cos_angle - vec.y * sin_angle, vec.x * sin_angle + vec.y * cos_angle}
}



DotProductV2 :: proc(a, b: rl.Vector2) -> f32 {
    return a.x*b.x + a.y*b.y
}



MagnitudeV2 :: proc(a: rl.Vector2) -> f32 {
    return math.sqrt(a.x*a.x + a.y*a.y)
}



NormalizedV2 :: proc(a: rl.Vector2) -> rl.Vector2 {
    return a / MagnitudeV2(a)
}
