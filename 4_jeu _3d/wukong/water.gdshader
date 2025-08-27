shader_type canvas_item;

// We'll use a screen texture to render what is underwater
uniform sampler2D screen_texture: hint_screen_texture;
// A noise texture will be used to apply the distortion effect
uniform sampler2D noise_texture: filter_nearest, repeat_enable;

// Speed of the water waves
uniform vec2 speed = vec2(0.5,0.2);
// Strength of the wave effect
uniform float wave_strength = 0.1;
// Strength of the distortion effect
uniform float distortion = 0.09;


// Called for every vertex the material is visible on.
void vertex() {
	// Move the water slightly up and down
	VERTEX. y += sin(TIME);
}

// Called for every pixel the material is visible on.
void fragment() {
	// Get a noise value in the [-1, 1] range
	vec2 noise = 2.0 * texture(noise_texture, UV).rg - vec2(1.0);
	// Sample the water texture
	COLOR = texture(TEXTURE, UV + noise * wave_strength);
	// Multiply the color with the screen texture
	COLOR *= texture(screen_texture, SCREEN_UV + noise * distortion);
}
