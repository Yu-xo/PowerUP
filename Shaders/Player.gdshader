shader_type canvas_item;

uniform vec2 velocity = vec2(0.0, 0.0);
uniform float trail_length : hint_range(0.0, 2.0) = 0.9;
uniform float distortion_amount : hint_range(0.0, 1.0) = 0.12;
uniform float wobble_speed : hint_range(0.0, 20.0) = 10.0;
uniform float wobble_strength : hint_range(0.0, 0.5) = 0.04;

uniform float bloom_strength : hint_range(0.0, 4.0) = 1.4;
uniform float pulse_strength : hint_range(0.0, 3.0) = 1.2;

// NEW — Outline settings
uniform float outline_size : hint_range(0.0, 4.0) = 1.4;
uniform float outline_intensity : hint_range(0.0, 4.0) = 1.2;


void fragment() {
    vec2 uv = UV;

    float speed = length(velocity);
    float energy = clamp(speed / 600.0, 0.0, 1.0);
    vec2 dir = normalize(velocity + vec2(0.0001));


    // -----------------------------------
    // 1. TRAIL SMEAR (safe)
    // -----------------------------------
    float smear = speed * trail_length * 0.0008;
    uv -= dir * smear;


    // -----------------------------------
    // 2. SAFE DISTORTION
    // -----------------------------------
    float wobble = sin(TIME * wobble_speed + uv.y * 15.0) * wobble_strength;
    uv.x += wobble * speed * 0.0008 * distortion_amount;

    uv = clamp(uv, vec2(0.0), vec2(1.0));


    // MAIN SAMPLE
    vec4 col = texture(TEXTURE, uv);


    // -----------------------------------
    // 3. OUTLINE (white)
    // -----------------------------------
    float px = outline_size / float(textureSize(TEXTURE, 0).x); // 1 px in UV
    float py = outline_size / float(textureSize(TEXTURE, 0).y);

    float outline =
        texture(TEXTURE, uv + vec2(px, 0.0)).a +
        texture(TEXTURE, uv + vec2(-px, 0.0)).a +
        texture(TEXTURE, uv + vec2(0.0, py)).a +
        texture(TEXTURE, uv + vec2(0.0, -py)).a;

    outline = step(0.1, outline) * (1.0 - col.a); // Only draw outside edges

    vec3 outline_color = vec3(1.0) * outline * outline_intensity;


    // -----------------------------------
    // 4. BLOOM BOOSTER (speed-based)
    // -----------------------------------
    col.rgb += col.rgb * bloom_strength * energy * 100.0;


    // -----------------------------------
    // 5. DASH ENERGY PULSE (glow flash)
    // -----------------------------------
    float pulse = abs(sin(TIME * 18.0)) * pulse_strength * energy * 0.35;
    col.rgb += pulse;


    // -----------------------------------
    // 6. ADD OUTLINE + OUTLINE GLOW
    // -----------------------------------
    vec3 glow = outline_color * (energy * 1.25 + pulse * 0.8);
    col.rgb += glow;


    COLOR = col;
}
