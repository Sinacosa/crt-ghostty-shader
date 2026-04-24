// Ghostty custom shader: subtle CRT effect for terminal content.
// Tweak the values in this section to customize the look.

const float CURVATURE = 0.025;
const float CURVATURE_COMPENSATION = 1.0;
const float SCREEN_ZOOM = 1.02;
const float CHROMATIC_ABERRATION = 2;
const float EDGE_ABERRATION = 1.75;
const float SCANLINE_STRENGTH = 0.82;
const float SCANLINE_DENSITY = 4.1;
const float BEAM_STRENGTH = 0.03;
const float BEAM_SPEED = 0.6;
const float BEAM_DENSITY = 0.35;
const float H_JITTER_STRENGTH = 1.0;
const float H_JITTER_SPEED = 30.0;
const float H_JITTER_DENSITY = 0.085;
const float VERTICAL_ROLL_STRENGTH = 0.0010;
const float VERTICAL_ROLL_SPEED = 3.0;
const float VERTICAL_ROLL_BAND_SIZE = 0.03;
const float MASK_BASE = 0.975;
const float MASK_BOOST = 1.025;
const float COLOR_FADE = 0.4;
const float CENTER_BEAM_STRENGTH = 0.08;
const float CENTER_BEAM_RADIUS = 0.42;
const float CENTER_BEAM_SOFTNESS = 2.2;
const float VIGNETTE_STRENGTH = 0.8;
const float FLICKER_STRENGTH = 0.1;
const float FLICKER_SPEED = 0.0;
const float BLOOM_STRENGTH = 0.8;
const float BLOOM_RADIUS = 2;
const float BLOOM_THRESHOLD = 0.2; 
const float BLOOM_KNEE = 0.3;
const float GHOSTING_STRENGTH = 0.1;
const float GHOSTING_DISTANCE = 10.0;
const float PERSISTENCE_STRENGTH = 0.14;
const float PERSISTENCE_DISTANCE = 3.0;
const float PERSISTENCE_SCALE = 1.008;
const vec3 PERSISTENCE_TINT = vec3(0.82, 0.98, 0.88);
const float RETENTION_STRENGTH = 0.22;
const float RETENTION_SCALE = 0.975;
const float RETENTION_BLUR = 7.0;
const float RETENTION_THRESHOLD = 0.08;
const vec3 RETENTION_TINT = vec3(0.85, 1.0, 0.88);
const float NOISE_STRENGTH = 0.0;
const float NOISE_SPEED = 0.0;
const float BASE_MIX = 0.985;
const float LIGHT_THEME_COMPENSATION = 0.85;
const float DARKENING_STRENGTH = 0.82;
const float BLACK_LEVEL_LIFT = 0.035;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float hash13(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float ign(vec2 p, float frame) {
    vec3 seed = vec3(p, frame);
    return hash13(seed + vec3(0.06711056, 0.00583715, 0.75487766));
}

float analogNoise(vec2 fragCoord, vec2 uv, float time) {
    float rate = max(NOISE_SPEED, 0.001);
    float frame = floor(time * (90.0 + rate * 9000.0));

    vec2 px = floor(fragCoord);
    float fine = ign(px, frame);
    float alt = ign(px.yx + vec2(19.0, 73.0), frame + 13.0);
    float triad = ign(floor(vec2(px.x / 3.0, px.y)) + vec2(7.0, 17.0), frame + 29.0);
    float line = ign(vec2(px.y, floor((uv.y + time * rate * 0.7) * iResolution.y * 0.5)), frame + 47.0);

    float grain = fine * 0.52 + alt * 0.23 + triad * 0.15 + line * 0.10;
    grain = grain * 2.0 - 1.0;

    float envelope = 0.85 + 0.15 * sin((uv.y + time * rate * 0.3) * iResolution.y * 0.09);
    return grain * envelope;
}

vec2 crtWarp(vec2 uv) {
    vec2 p = uv * 2.0 - 1.0;
    float r2 = dot(p, p);
    p *= 1.0 + CURVATURE * r2;

    // Scale from the worst case at the corners so the full image stays visible.
    float compensation = 1.0 / (1.0 + CURVATURE * 2.0);
    p = mix(p, p * compensation, CURVATURE_COMPENSATION);
    p *= SCREEN_ZOOM;

    return p * 0.5 + 0.5;
}

vec3 sampleScreen(vec2 uv) {
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        return iBackgroundColor;
    }
    return texture(iChannel0, uv).rgb;
}

float edgeFactor(vec2 uv) {
    vec2 p = abs(uv * 2.0 - 1.0);
    float edge = max(p.x, p.y);
    return smoothstep(0.45, 1.0, edge);
}

vec3 brightPass(vec3 color) {
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float bright = smoothstep(BLOOM_THRESHOLD, BLOOM_THRESHOLD + BLOOM_KNEE, luma);
    return color * bright;
}

vec3 sampleBloom(vec2 uv, vec2 texel) {
    vec2 offset = texel * BLOOM_RADIUS;

    vec3 sum = brightPass(sampleScreen(uv)) * 0.227027;
    sum += brightPass(sampleScreen(uv + vec2(offset.x, 0.0))) * 0.1945946;
    sum += brightPass(sampleScreen(uv - vec2(offset.x, 0.0))) * 0.1945946;
    sum += brightPass(sampleScreen(uv + vec2(0.0, offset.y))) * 0.1216216;
    sum += brightPass(sampleScreen(uv - vec2(0.0, offset.y))) * 0.1216216;
    sum += brightPass(sampleScreen(uv + offset)) * 0.0702703;
    sum += brightPass(sampleScreen(uv - offset)) * 0.0702703;

    return sum;
}

vec3 sampleGhosting(vec2 uv, vec2 texel) {
    vec2 offset = vec2(GHOSTING_DISTANCE * texel.x, 0.0);
    vec3 smear = sampleScreen(uv - offset) * 0.55;
    smear += sampleScreen(uv - offset * 2.0) * 0.3;
    smear += sampleScreen(uv - offset * 3.0) * 0.15;
    return brightPass(smear);
}

vec3 samplePersistence(vec2 uv, vec2 texel) {
    vec2 baseUv = (uv - vec2(0.5)) * PERSISTENCE_SCALE + vec2(0.5);
    vec2 offset = vec2(PERSISTENCE_DISTANCE * texel.x, texel.y * 0.4);

    vec3 trail = brightPass(sampleScreen(baseUv - offset)) * 0.42;
    trail += brightPass(sampleScreen(baseUv - offset * 1.8)) * 0.27;
    trail += brightPass(sampleScreen(baseUv - offset * 2.8)) * 0.16;
    trail += brightPass(sampleScreen(baseUv + vec2(0.0, texel.y * 1.5))) * 0.08;

    vec3 current = brightPass(sampleScreen(uv));
    trail = max(trail - current * 0.35, vec3(0.0));

    float trailLuma = dot(trail, vec3(0.2126, 0.7152, 0.0722));
    float trailMask = smoothstep(0.03, 0.45, trailLuma);
    return trail * PERSISTENCE_TINT * trailMask;
}

vec3 sampleRetention(vec2 uv, vec2 texel) {
    vec2 retentionUv = (uv - vec2(0.5)) * RETENTION_SCALE + vec2(0.5);
    vec2 offset = texel * RETENTION_BLUR;

    vec3 retained = brightPass(sampleScreen(retentionUv)) * 0.24;
    retained += brightPass(sampleScreen(retentionUv + vec2(offset.x, 0.0))) * 0.17;
    retained += brightPass(sampleScreen(retentionUv - vec2(offset.x, 0.0))) * 0.17;
    retained += brightPass(sampleScreen(retentionUv + vec2(0.0, offset.y))) * 0.12;
    retained += brightPass(sampleScreen(retentionUv - vec2(0.0, offset.y))) * 0.12;
    retained += brightPass(sampleScreen(retentionUv + offset)) * 0.09;
    retained += brightPass(sampleScreen(retentionUv - offset)) * 0.09;

    float retainedLuma = dot(retained, vec3(0.2126, 0.7152, 0.0722));
    float retainedMask = smoothstep(RETENTION_THRESHOLD, 1.0, retainedLuma);
    return retained * RETENTION_TINT * retainedMask;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 warpedUv = crtWarp(uv);

    vec2 texel = 1.0 / iResolution.xy;

    float lineNoise = hash(vec2(floor(fragCoord.y) * H_JITTER_DENSITY, floor(iTime * H_JITTER_SPEED)));
    float lineJitter = (lineNoise - 0.5) * 2.0 * H_JITTER_STRENGTH * texel.x;
    float rollCenter = fract(iTime * VERTICAL_ROLL_SPEED);
    float rollDist = abs(warpedUv.y - rollCenter);
    rollDist = min(rollDist, 1.0 - rollDist);
    float rollBand = smoothstep(VERTICAL_ROLL_BAND_SIZE, 0.0, rollDist);
    float backgroundLuma = dot(iBackgroundColor, vec3(0.299, 0.587, 0.114));
    float lightTheme = smoothstep(0.6, 0.95, backgroundLuma) * LIGHT_THEME_COMPENSATION;
    warpedUv.x += lineJitter * (0.35 + rollBand);
    warpedUv.y = fract(warpedUv.y + VERTICAL_ROLL_STRENGTH * rollBand);
    warpedUv = clamp(warpedUv, texel, vec2(1.0) - texel);

    float edge = edgeFactor(uv);

    // Tiny RGB separation keeps the effect visible without hurting legibility.
    float aberration = CHROMATIC_ABERRATION * mix(1.0, EDGE_ABERRATION, edge);
    vec2 rgbOffset = vec2(aberration * texel.x, 0.0);
    vec3 color;
    color.r = sampleScreen(warpedUv + rgbOffset).r;
    color.g = sampleScreen(warpedUv).g;
    color.b = sampleScreen(warpedUv - rgbOffset).b;
    vec3 bloom = sampleBloom(warpedUv, texel);
    vec3 ghosting = sampleGhosting(warpedUv, texel);
    vec3 persistence = samplePersistence(warpedUv, texel);
    vec3 retention = sampleRetention(warpedUv, texel);
    vec3 originalColor = color;

    float darkenAmount = 1.0 - 0.65 * lightTheme;
    float effectAmount = 1.0 - 0.45 * lightTheme;

    float scan = (1.0 - SCANLINE_STRENGTH) + SCANLINE_STRENGTH * sin(warpedUv.y * iResolution.y * SCANLINE_DENSITY);
    float beam = (1.0 - BEAM_STRENGTH) + BEAM_STRENGTH * sin((warpedUv.y + iTime * BEAM_SPEED) * iResolution.y * BEAM_DENSITY);
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(color, vec3(luma), COLOR_FADE * effectAmount);

    float maskPhase = fract(fragCoord.x / 3.0);
    vec3 mask = vec3(MASK_BASE);
    if (maskPhase < 0.3333333) {
        mask.r = MASK_BOOST;
    } else if (maskPhase < 0.6666667) {
        mask.g = MASK_BOOST;
    } else {
        mask.b = MASK_BOOST;
    }

    vec2 centered = uv * (1.0 - uv.yx);
    float vignette = pow(max(centered.x * centered.y * 18.0, 0.0), VIGNETTE_STRENGTH);
    vec2 centerDelta = uv - vec2(0.5);
    float centerBeam = 1.0 + CENTER_BEAM_STRENGTH * pow(
        max(0.0, 1.0 - length(centerDelta) / CENTER_BEAM_RADIUS),
        CENTER_BEAM_SOFTNESS
    );
    float flicker = (1.0 - FLICKER_STRENGTH) + FLICKER_STRENGTH * sin(iTime * FLICKER_SPEED);
    float noise = analogNoise(fragCoord, uv, iTime) * NOISE_STRENGTH;

    color *= mix(1.0, scan * beam * vignette * flicker, darkenAmount * DARKENING_STRENGTH) * mix(vec3(1.0), mask, effectAmount) * centerBeam;
    color += bloom * (BLOOM_STRENGTH * effectAmount);
    color += ghosting * (GHOSTING_STRENGTH * effectAmount);
    color += persistence * (PERSISTENCE_STRENGTH * effectAmount);
    color += retention * (RETENTION_STRENGTH * effectAmount);
    color += noise * effectAmount;
    color = max(color, iBackgroundColor * BLACK_LEVEL_LIFT);
    color = mix(color, originalColor, 0.35 * lightTheme);
    color = mix(iBackgroundColor, color, BASE_MIX);
    color = clamp(color, 0.0, 1.0);

    fragColor = vec4(color, 1.0);
}
