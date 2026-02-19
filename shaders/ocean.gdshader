shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled;

uniform vec3 albedo : source_color = vec3(0.02, 0.15, 0.35);
uniform vec3 foam_color : source_color = vec3(0.9, 0.95, 1.0);
uniform vec3 deep_color : source_color = vec3(0.0, 0.05, 0.15);
uniform vec3 shallow_color : source_color = vec3(0.1, 0.4, 0.5);

uniform float wave_speed : hint_range(0.0, 2.0) = 0.5;
uniform float wave_height : hint_range(0.0, 2.0) = 0.5;
uniform float wave_frequency : hint_range(0.1, 5.0) = 1.0;
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.7;
uniform float foam_amount : hint_range(0.0, 1.0) = 0.4;

uniform float refraction_strength : hint_range(0.0, 0.3) = 0.1;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float specular : hint_range(0.0, 1.0) = 0.5;

varying vec3 vertex_position;
varying vec3 world_position;
varying float wave_height_val;
varying vec2 screen_uv;

// Simplex noise functions for wave generation
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289(((x * 34.0) + 1.0) * x); }

float snoise(vec2 v) {
    const vec4 C = vec4(0.211324865405187, 0.366025403784439,
                        -0.577350269189626, 0.024390243902439);
    vec2 i  = floor(v + dot(v, C.yy));
    vec2 x0 = v - i + dot(i, C.xx);
    vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod289(i);
    vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
    vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m = m * m;
    m = m * m;
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
    vec3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

float get_wave_height(vec2 pos, float time) {
    float height = 0.0;
    height += snoise(pos * wave_frequency * 0.5 + time * wave_speed * 0.3) * wave_height;
    height += snoise(pos * wave_frequency * 1.0 + time * wave_speed * 0.5) * wave_height * 0.5;
    height += snoise(pos * wave_frequency * 2.0 + time * wave_speed * 0.7) * wave_height * 0.25;
    return height;
}

vec3 calculate_normal(vec2 pos, float time) {
    float eps = 0.1;
    float h = get_wave_height(pos, time);
    float h_x = get_wave_height(pos + vec2(eps, 0.0), time);
    float h_z = get_wave_height(pos + vec2(0.0, eps), time);
    
    vec3 dx = vec3(eps, h_x - h, 0.0);
    vec3 dz = vec3(0.0, h_z - h, eps);
    
    return normalize(cross(dz, dx));
}

void vertex() {
    vec2 pos = VERTEX.xz * 0.1;
    float time = TIME;
    
    float height = get_wave_height(pos, time);
    VERTEX.y += height;
    
    wave_height_val = height / wave_height;
    vertex_position = VERTEX;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 pos = world_position.xz * 0.1;
    float time = TIME;
    
    // Calculate dynamic normal
    vec3 normal = calculate_normal(pos, time);
    
    // Depth-based color
    float depth = texture(depth_texture, SCREEN_UV).r;
    vec3 view_space_pos = vec3(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0);
    float linear_depth = -view_space_pos.z;
    float depth_factor = clamp(linear_depth * 0.1, 0.0, 1.0);
    
    vec3 water_color = mix(shallow_color, deep_color, depth_factor);
    water_color = mix(water_color, albedo, 0.5);
    
    // Fresnel effect for reflection approximation
    vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_position);
    float fresnel = pow(1.0 - max(dot(view_dir, normal), 0.0), 3.0);
    fresnel = clamp(fresnel, 0.0, 1.0);
    
    // Sky reflection approximation
    vec3 sky_color = mix(vec3(0.4, 0.6, 0.9), vec3(0.1, 0.2, 0.4), 1.0 - view_dir.y);
    water_color = mix(water_color, sky_color, fresnel * 0.6);
    
    // Foam at wave peaks
    float foam = smoothstep(foam_threshold, foam_threshold + 0.2, wave_height_val);
    foam += snoise(pos * 8.0 + time * 0.5) * 0.1;
    foam = clamp(foam, 0.0, 1.0) * foam_amount;
    
    // Combine colors
    vec3 final_color = mix(water_color, foam_color, foam);
    
    // Specular highlights (sun reflection)
    vec3 light_dir = normalize(vec3(0.5, 0.8, 0.3));
    vec3 half_dir = normalize(light_dir + view_dir);
    float spec = pow(max(dot(normal, half_dir), 0.0), 128.0);
    final_color += vec3(1.0, 0.95, 0.8) * spec * 0.8;
    
    ALBEDO = final_color;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    SPECULAR = specular;
    
    // Refraction
    vec2 refract_uv = SCREEN_UV + normal.xz * refraction_strength * 0.05;
    vec3 refract_color = texture(screen_texture, refract_uv).rgb;
    
    // Blend refraction based on fresnel
    vec3 final_with_refraction = mix(refract_color, final_color, 0.7 + fresnel * 0.3);
    ALBEDO = final_with_refraction;
    
    // Transparency
    ALPHA = 0.92;
}
