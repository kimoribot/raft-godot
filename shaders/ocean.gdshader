shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled;

uniform vec3 albedo : source_color = vec3(0.02, 0.15, 0.35);
uniform vec3 foam_color : source_color = vec3(0.9, 0.95, 1.0);
uniform vec3 deep_color : source_color = vec3(0.0, 0.05, 0.15);
uniform vec3 shallow_color : source_color = vec3(0.1, 0.4, 0.5);

uniform float wave_speed : hint_range(0.0, 2.0) = 0.5;
uniform float wave_height : hint_range(0.0, 3.0) = 1.5;
uniform float wave_frequency : hint_range(0.01, 2.0) = 0.1;
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.6;
uniform float foam_amount : hint_range(0.0, 1.0) = 0.5;
uniform float storm_intensity : hint_range(0.0, 2.0) = 0.0;

uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float roughness : hint_range(0.0, 1.0) = 0.15;
uniform float specular : hint_range(0.0, 1.0) = 0.5;

varying vec3 world_pos;
varying vec3 vertex_normal;
varying float wave_height_out;

// Simplex noise functions
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289(((x * 34.0) + 1.0) * x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float snoise(vec3 v) {
    const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
    
    vec3 i = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);
    
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);
    
    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy;
    vec3 x3 = x0 - D.yyy;
    
    i = mod289(i);
    vec4 p = permute(permute(permute(
        i.z + vec4(0.0, i1.z, i2.z, 1.0))
        + i.y + vec4(0.0, i1.y, i2.y, 1.0))
        + i.x + vec4(0.0, i1.x, i2.x, 1.0));
    
    float n_ = 0.142857142857;
    vec3 ns = n_ * D.wyz - D.xzx;
    
    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
    
    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);
    
    vec4 x = x_ * ns.x + ns.yyyy;
    vec4 y = y_ * ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);
    
    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);
    
    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));
    
    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
    
    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);
    
    vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;
    
    vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

// Fractal Brownian Motion for more natural waves
float fbm(vec3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for(int i = 0; i < 5; i++) {
        value += amplitude * snoise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return value;
}

// Gerstner wave function for realistic ocean waves
vec3 gerstner_wave(vec2 pos, float time, vec2 direction, float steepness, float wavelength) {
    float k = 2.0 * 3.14159 / wavelength;
    float c = sqrt(9.8 / k);
    float f = k * (dot(direction, pos) - c * time);
    float a = steepness / k;
    
    return vec3(
        direction.x * (a * cos(f)),
        a * sin(f),
        direction.y * (a * cos(f))
    );
}

void vertex() {
    float time = TIME * wave_speed;
    vec3 pos = VERTEX;
    
    // Apply multiple Gerstner waves for realistic motion
    vec3 wave1 = gerstner_wave(pos.xz, time, normalize(vec2(1.0, 0.0)), 0.25 * (1.0 + storm_intensity * 0.5), 60.0);
    vec3 wave2 = gerstner_wave(pos.xz, time, normalize(vec2(1.0, 0.6)), 0.2 * (1.0 + storm_intensity * 0.5), 31.0);
    vec3 wave3 = gerstner_wave(pos.xz, time, normalize(vec2(1.0, -0.4)), 0.15 * (1.0 + storm_intensity * 0.5), 18.0);
    vec3 wave4 = gerstner_wave(pos.xz, time, normalize(vec2(0.7, 1.0)), 0.1 * (1.0 + storm_intensity * 0.5), 10.0);
    
    vec3 total_wave = (wave1 + wave2 + wave3 + wave4) * wave_height;
    
    // Add FBM for detail
    float detail = fbm(vec3(pos.xz * wave_frequency * 2.0, time * 0.5)) * wave_height * 0.3;
    
    pos += total_wave;
    pos.y += detail;
    
    // Calculate normal from wave derivatives
    float eps = 0.1;
    vec3 wave_x = gerstner_wave(pos.xz + vec2(eps, 0.0), time, normalize(vec2(1.0, 0.0)), 0.25, 60.0);
    vec3 wave_z = gerstner_wave(pos.xz + vec2(0.0, eps), time, normalize(vec2(0.0, 1.0)), 0.25, 60.0);
    
    vec3 tangent = normalize(vec3(eps, (wave_x.y - wave1.y) * wave_height, 0.0));
    vec3 bitangent = normalize(vec3(0.0, (wave_z.y - wave1.y) * wave_height, eps));
    vertex_normal = normalize(cross(bitangent, tangent));
    
    VERTEX = pos;
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    wave_height_out = pos.y / (wave_height * 2.0);
}

void fragment() {
    float time = TIME * wave_speed;
    
    // Use the calculated vertex normal
    vec3 normal = normalize(vertex_normal);
    
    // Add normal map detail
    float normal_detail = snoise(vec3(world_pos.xz * 0.5, time * 0.3)) * 0.1;
    normal = normalize(normal + vec3(normal_detail, 0.0, normal_detail));
    
    // View direction
    vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
    
    // Fresnel effect
    float fresnel = pow(1.0 - max(dot(view_dir, normal), 0.0), 4.0);
    fresnel = clamp(fresnel, 0.0, 1.0);
    
    // Water color based on depth/angle
    vec3 water_color = mix(deep_color, shallow_color, fresnel * 0.5);
    water_color = mix(water_color, albedo, 0.4);
    
    // Sky reflection
    vec3 reflect_dir = reflect(-view_dir, normal);
    float sky_gradient = smoothstep(-0.2, 0.8, reflect_dir.y);
    vec3 sky_color = mix(vec3(0.1, 0.15, 0.25), vec3(0.4, 0.6, 0.9), sky_gradient);
    
    // Add sun reflection
    vec3 sun_dir = normalize(vec3(0.5, 0.8, 0.3));
    vec3 half_dir = normalize(sun_dir + view_dir);
    float sun_spec = pow(max(dot(normal, half_dir), 0.0), 256.0);
    vec3 sun_color = vec3(1.0, 0.95, 0.8) * sun_spec * 2.0;
    
    water_color = mix(water_color, sky_color, fresnel * 0.7);
    water_color += sun_color;
    
    // Foam on wave peaks
    float foam = smoothstep(foam_threshold - 0.2, foam_threshold + 0.3, wave_height_out);
    foam += snoise(vec3(world_pos.xz * 3.0 + time, 0.0)) * 0.15;
    foam = clamp(foam, 0.0, 1.0) * foam_amount;
    
    // Extra foam in storms
    if(storm_intensity > 0.0) {
        float storm_foam = snoise(vec3(world_pos.xz * 5.0 + time * 2.0, 0.0)) * 0.5 + 0.5;
        foam = max(foam, storm_foam * storm_intensity * 0.3);
    }
    
    water_color = mix(water_color, foam_color, foam);
    
    ALBEDO = water_color;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    SPECULAR = specular;
    
    // Slight transparency
    ALPHA = 0.95;
}
