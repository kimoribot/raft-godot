shader_type spatial;
render_mode cull_disabled, unshaded;

uniform float time_of_day : hint_range(0.0, 24.0) = 12.0;
uniform float day_duration : hint_range(1.0, 120.0) = 60.0;

uniform vec3 day_top_color : source_color = vec3(0.25, 0.55, 0.9);
uniform vec3 day_bottom_color : source_color = vec3(0.6, 0.8, 1.0);
uniform vec3 sunset_top_color : source_color = vec3(0.4, 0.2, 0.3);
uniform vec3 sunset_bottom_color : source_color = vec3(1.0, 0.5, 0.2);
uniform vec3 night_top_color : source_color = vec3(0.02, 0.03, 0.1);
uniform vec3 night_bottom_color : source_color = vec3(0.05, 0.08, 0.15);

uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3 moon_color : source_color = vec3(0.7, 0.75, 0.9);
uniform float sun_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float moon_intensity : hint_range(0.0, 2.0) = 0.8;

uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shadow_color : source_color = vec3(0.4, 0.45, 0.55);
uniform float cloud_density : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_speed : hint_range(0.0, 1.0) = 0.1;

uniform float star_intensity : hint_range(0.0, 1.0) = 0.8;
uniform float star_size : hint_range(0.5, 3.0) = 1.5;

varying vec3 world_position;
varying vec3 vertex_normal;

const float PI = 3.14159265359;

// Hash function for stars
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// Get sun/moon position based on time of day
vec3 get_sun_moon_position(float tod) {
    float angle = (tod - 6.0) / 12.0 * PI; // 6:00 sunrise, 18:00 sunset
    float y = sin(angle);
    float x = cos(angle);
    return normalize(vec3(x, y, 0.3));
}

// Calculate day/night blend factor
float get_day_factor(float tod) {
    // Smooth transition around sunrise (6) and sunset (18)
    float sunrise = 6.0;
    float sunset = 18.0;
    
    if (tod < sunrise) return 0.0;
    if (tod > sunset) return 0.0;
    
    // Morning transition: 5-7
    if (tod < sunrise + 1.0) {
        return (tod - sunrise);
    }
    // Evening transition: 17-19
    if (tod > sunset - 1.0) {
        return 1.0 - (tod - (sunset - 1.0));
    }
    
    return 1.0;
}

// Sunset factor (1.0 at sunset)
float get_sunset_factor(float tod) {
    float sunset = 18.0;
    float dist = abs(tod - sunset);
    return exp(-dist * dist * 0.1);
}

// Stars
float stars(vec2 uv, float intensity) {
    vec2 grid_uv = uv * 200.0;
    vec2 grid_id = floor(grid_uv);
    vec2 grid_fract = fract(grid_uv);
    
    float brightness = hash(grid_id);
    if (brightness > 0.98) {
        vec2 center = vec2(hash(grid_id + 0.1), hash(grid_id + 0.2));
        float dist = length(grid_fract - center);
        float star = smoothstep(0.1 * star_size, 0.0, dist);
        return star * intensity * brightness;
    }
    return 0.0;
}

// Cloud layer
float clouds(vec2 uv, float time) {
    vec2 cloud_uv = uv * 3.0 + vec2(time * cloud_speed, 0.0);
    float cloud = fbm(cloud_uv);
    cloud = smoothstep(0.4 - cloud_density * 0.3, 0.6 + cloud_density * 0.3, cloud);
    return cloud;
}

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vertex_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_position);
    
    // Sky gradient based on view direction (yaw)
    float elevation = view_dir.y;
    float yaw = atan(view_dir.x, view_dir.z);
    
    // Vertical gradient
    float gradient_factor = smoothstep(-0.2, 0.8, elevation);
    
    // Time-based factors
    float day_factor = get_day_factor(time_of_day);
    float sunset_factor = get_sunset_factor(time_of_day);
    float night_factor = 1.0 - day_factor;
    
    // Base sky colors
    vec3 day_color = mix(day_bottom_color, day_top_color, gradient_factor);
    vec3 sunset_color = mix(sunset_bottom_color, sunset_top_color, gradient_factor);
    vec3 night_color = mix(night_bottom_color, night_top_color, gradient_factor);
    
    // Blend based on time
    vec3 sky_color = day_color;
    sky_color = mix(sky_color, sunset_color, sunset_factor);
    sky_color = mix(sky_color, night_color, night_factor * 0.7);
    
    // Sun/Moon rendering
    vec3 sun_moon_pos = get_sun_moon_position(time_of_day);
    float sun_moon_dot = dot(view_dir, sun_moon_pos);
    
    // Sun
    float sun_core = smoothstep(0.9995, 0.9999, sun_moon_dot);
    float sun_glow = pow(max(sun_moon_dot, 0.0), 8.0);
    vec3 sun_contrib = sun_color * (sun_core + sun_glow * 0.3) * sun_intensity * day_factor;
    
    // Moon
    float moon_core = smoothstep(0.998, 0.9995, sun_moon_dot);
    float moon_glow = pow(max(sun_moon_dot, 0.0), 16.0);
    vec3 moon_contrib = moon_color * (moon_core + moon_glow * 0.2) * moon_intensity * night_factor;
    
    // Stars (only visible at night)
    float star_visible = night_factor * (1.0 - sunset_factor * 0.5);
    vec2 star_uv = vec2(yaw / PI * 0.5 + 0.5, elevation);
    float star_field = stars(star_uv, star_visible * star_intensity);
    
    // Clouds
    vec2 cloud_uv = vec2(yaw / PI * 0.5 + 0.5, gradient_factor);
    float cloud_layer = clouds(cloud_uv, TIME * day_duration * 0.01);
    
    // Cloud lighting
    float sun_elev = sun_moon_pos.y;
    float cloud_light = smoothstep(-0.1, 0.5, sun_elev);
    vec3 cloud_color_lit = mix(cloud_shadow_color, cloud_color, cloud_light);
    
    // Blend clouds with sky
    float cloud_alpha = cloud_layer * cloud_density;
    sky_color = mix(sky_color, cloud_color_lit, cloud_alpha);
    
    // Combine all elements
    vec3 final_color = sky_color + sun_contrib + moon_contrib;
    final_color += vec3(star_field);
    
    // Add atmospheric scattering near horizon
    float horizon_glow = exp(-abs(elevation) * 5.0);
    vec3 horizon_color = sunset_factor > 0.1 ? 
        mix(vec3(1.0, 0.6, 0.3), vec3(0.1, 0.15, 0.3), night_factor) : 
        vec3(0.1, 0.15, 0.3);
    final_color += horizon_color * horizon_glow * 0.3;
    
    ALBEDO = final_color;
    ALPHA = 1.0;
}
