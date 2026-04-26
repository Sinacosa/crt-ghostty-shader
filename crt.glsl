// Ghostty custom shader: light CRT effect for terminal content.
// Designed to preserve brightness while adding gentle glass, scanline, and phosphor texture.

const float CURVATURE = 0.024;
const float SCREEN_ZOOM = 1.018;
const float CHROMATIC_ABERRATION = 1.55;
const float SCANLINE_STRENGTH = 0.16;
const float SCANLINE_DENSITY = 2.35;
const float SCANLINE_SPEED = 48.0;
const float HORIZONTAL_LINE_STRENGTH = 0.18;
const float HORIZONTAL_LINE_SPACING = 22.0;
const float HORIZONTAL_LINE_WIDTH = 0.42;
const float HORIZONTAL_LINE_SOFTNESS = 0.06;
const float BEAM_STRENGTH = 0.035;
const float BEAM_SPEED = 0.7;
const float BEAM_DENSITY = 0.38;
const float PHOSPHOR_STRENGTH = 0.065;
const float GLOW_STRENGTH = 0.42;
const float GLOW_RADIUS = 3.0;
const float BURN_STRENGTH = 0.42;
const float BURN_THRESHOLD = 0.18;
const float BURN_SOFTNESS = 0.42;
const vec3 BURN_COLOR = vec3(1.0, 0.38, 0.08);
const float BLOOM_STRENGTH = 0.52;
const vec3 BLOOM_COLOR_BALANCE = vec3(1.0, 0.68, 1.0);
const float BLOOM_RADIUS = 10.0;
const float BLOOM_THRESHOLD = 0.16;
const float BLOOM_SOFTNESS = 0.38;
const float JITTER_STRENGTH = 2.05;
const float JITTER_SPEED = 30.0;
const float JITTER_DENSITY = 0.12;
const float JITTER_VERTICAL_SPEED = 22.0;
const float JITTER_DRIFT_STRENGTH = 0.34;
const float JITTER_BURST_STRENGTH = 1.75;
const float JITTER_BURST_SPEED = 1.15;
const float ROLL_STRENGTH = 0.00055;
const float ROLL_SPEED = 2.2;
const float ROLL_BAND_SIZE = 0.035;
const float GLASS_HIGHLIGHT = 0.04;
const float RADIAL_REFLECTION_STRENGTH = 0.13;
const float RADIAL_REFLECTION_RADIUS = 0.92;
const float RADIAL_REFLECTION_SOFTNESS = 1.85;
const vec3 RADIAL_REFLECTION_COLOR = vec3(0.95, 0.86, 1.0);
const float VIGNETTE_STRENGTH = 0.48;
const float BARREL_EDGE_DARKENING = 0.13;
const float BARREL_EDGE_SOFTNESS = 1.55;
const float NOISE_STRENGTH = 0.025;
const float NOISE_SPEED = 0.45;
const float NOISE_SCALE = 2.25;
const float FLICKER_STRENGTH = 0.0;
const float FLICKER_SPEED = 0.0;
const float COLOR_WARMTH = 0.045;
const vec3 CRT_TINT = vec3(1.08, 0.68, 1.28);
const float CRT_TINT_STRENGTH = 0.18;
const float BASE_MIX = 0.97;
const float CONTRAST_BOOST = 1.035;

vec2 crtWarp(vec2 uv) {
    vec2 p = uv * 2.0 - 1.0;
    float r2 = dot(p, p);
    p *= 1.0 + CURVATURE * r2;

    float compensation = 1.0 / (1.0 + CURVATURE * 2.0);
    p *= compensation * SCREEN_ZOOM;

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
    return smoothstep(0.52, 1.0, max(p.x, p.y));
}

vec3 sampleGlow(vec2 uv, vec2 texel) {
    vec2 offset = texel * GLOW_RADIUS;
    vec3 glow = sampleScreen(uv) * 0.34;
    glow += sampleScreen(uv + vec2(offset.x, 0.0)) * 0.16;
    glow += sampleScreen(uv - vec2(offset.x, 0.0)) * 0.16;
    glow += sampleScreen(uv + vec2(0.0, offset.y)) * 0.12;
    glow += sampleScreen(uv - vec2(0.0, offset.y)) * 0.12;
    glow += sampleScreen(uv + offset) * 0.05;
    glow += sampleScreen(uv - offset) * 0.05;
    return glow;
}

vec3 brightPass(vec3 color) {
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float bright = smoothstep(BLOOM_THRESHOLD, BLOOM_THRESHOLD + BLOOM_SOFTNESS, luma);
    return color * bright * BLOOM_COLOR_BALANCE;
}

vec3 sampleBloom(vec2 uv, vec2 texel) {
    vec2 offset = texel * BLOOM_RADIUS;

    vec3 bloom = brightPass(sampleScreen(uv)) * 0.22;
    bloom += brightPass(sampleScreen(uv + vec2(offset.x, 0.0))) * 0.16;
    bloom += brightPass(sampleScreen(uv - vec2(offset.x, 0.0))) * 0.16;
    bloom += brightPass(sampleScreen(uv + vec2(0.0, offset.y))) * 0.13;
    bloom += brightPass(sampleScreen(uv - vec2(0.0, offset.y))) * 0.13;
    bloom += brightPass(sampleScreen(uv + offset)) * 0.08;
    bloom += brightPass(sampleScreen(uv - offset)) * 0.08;
    bloom += brightPass(sampleScreen(uv + vec2(offset.x, -offset.y))) * 0.02;
    bloom += brightPass(sampleScreen(uv + vec2(-offset.x, offset.y))) * 0.02;

    return bloom;
}

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float hash13(vec3 p) {
    return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

float analogNoise(vec2 fragCoord, vec2 uv, vec2 resolution, float time) {
    float rate = max(NOISE_SPEED, 0.001);
    float frame = floor(time * (50.0 + rate * 360.0));

    vec2 drift = vec2(
        sin(time * (15.8 + rate * 10.0)),
        cos(time * (12.4 + rate * 8.0))
    ) * NOISE_SCALE * 10.0;
    vec2 p = fragCoord + drift + vec2(frame * 1.29, frame * -1.91);
    vec2 rp = vec2(p.x * 0.866 - p.y * 0.5, p.x * 0.5 + p.y * 0.866);

    vec2 cellA = floor(p / NOISE_SCALE);
    vec2 cellB = floor((rp + vec2(37.0, 91.0)) / (NOISE_SCALE * 1.73));
    vec2 cellC = floor((p + rp * 0.41 + vec2(113.0, 29.0)) / (NOISE_SCALE * 3.9));

    float fine = hash13(vec3(cellA, frame));
    float rotated = hash13(vec3(cellB, frame + 19.0));
    float coarse = hash13(vec3(cellC, frame + 47.0));
    float line = hash13(vec3(floor(uv.y * resolution.y / (NOISE_SCALE * 1.6)) + frame * 0.37, frame + 83.0, frame + 11.0));

    float grain = fine * 0.46 + rotated * 0.27 + coarse * 0.17 + line * 0.10;
    grain = grain * 2.0 - 1.0;

    float envelope = 0.90 + 0.10 * sin((uv.y * resolution.y * 0.067) + time * rate * 4.9);
    return grain * envelope;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 resolution = iResolution.xy;
    vec2 uv = fragCoord / resolution;

    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(iBackgroundColor, 1.0);
        return;
    }

    vec2 warpedUv = crtWarp(uv);
    vec2 texel = 1.0 / resolution;
    float edge = edgeFactor(uv);
    vec2 contentCoord = uv * resolution;

    float jitterY = contentCoord.y + iTime * JITTER_VERTICAL_SPEED;
    float row = floor(jitterY);
    float fastFrame = floor(iTime * JITTER_SPEED);
    float slowFrame = floor(iTime * JITTER_BURST_SPEED);
    float lineNoise = hash(vec2(row * JITTER_DENSITY, fastFrame));
    float lineNoiseNext = hash(vec2((row + 1.0) * JITTER_DENSITY, fastFrame + 17.0));
    float fineJitter = mix(lineNoise, lineNoiseNext, 0.35) * 2.0 - 1.0;
    float waveY = uv.y * resolution.y + iTime * JITTER_VERTICAL_SPEED;
    float waveJitter = sin(waveY * 0.068 + iTime * 10.5)
        + 0.5 * sin(waveY * 0.019 - iTime * 5.2);
    waveJitter *= 0.5;
    float burstCenter = hash(vec2(slowFrame, 41.7));
    float burstWidth = mix(0.014, 0.065, hash(vec2(slowFrame, 93.2)));
    float burstY = fract(uv.y + iTime * JITTER_VERTICAL_SPEED / resolution.y);
    float burstDist = abs(burstY - burstCenter);
    burstDist = min(burstDist, 1.0 - burstDist);
    float burstBand = smoothstep(burstWidth, 0.0, burstDist);
    float burstDirection = hash(vec2(slowFrame, 12.4)) < 0.5 ? -1.0 : 1.0;
    float burstFlicker = 0.35 + 0.65 * hash(vec2(row * 0.19, fastFrame + slowFrame * 3.0));
    float lineJitter = (fineJitter + waveJitter * JITTER_DRIFT_STRENGTH
        + burstDirection * burstBand * burstFlicker * JITTER_BURST_STRENGTH)
        * JITTER_STRENGTH * texel.x;
    float rollCenter = fract(iTime * ROLL_SPEED);
    float rollDist = abs(warpedUv.y - rollCenter);
    rollDist = min(rollDist, 1.0 - rollDist);
    float rollBand = smoothstep(ROLL_BAND_SIZE, 0.0, rollDist);
    warpedUv.x += lineJitter * mix(0.55, 1.25, edge) * (1.0 + rollBand * 0.45);
    warpedUv.y = fract(warpedUv.y + ROLL_STRENGTH * rollBand);
    warpedUv = clamp(warpedUv, texel, vec2(1.0) - texel);

    vec2 rgbOffset = vec2(CHROMATIC_ABERRATION * mix(0.55, 1.35, edge) * texel.x, 0.0);
    vec3 color;
    color.r = sampleScreen(warpedUv + rgbOffset).r;
    color.g = sampleScreen(warpedUv).g;
    color.b = sampleScreen(warpedUv - rgbOffset).b;

    vec3 originalColor = color;

    float scanlineY = warpedUv.y * resolution.y - iTime * SCANLINE_SPEED;
    float scan = 1.0 - SCANLINE_STRENGTH * (0.5 + 0.5 * sin(scanlineY * SCANLINE_DENSITY));
    float linePhase = fract(scanlineY / HORIZONTAL_LINE_SPACING);
    float lineDistance = abs(linePhase - 0.5);
    float horizontalLine = 1.0 - smoothstep(
        HORIZONTAL_LINE_WIDTH,
        HORIZONTAL_LINE_WIDTH + HORIZONTAL_LINE_SOFTNESS,
        lineDistance
    );
    float horizontalRaster = 1.0 - HORIZONTAL_LINE_STRENGTH * horizontalLine;
    float beam = 1.0 - BEAM_STRENGTH * (0.5 + 0.5 * sin((warpedUv.y + iTime * BEAM_SPEED) * resolution.y * BEAM_DENSITY));
    float flicker = 1.0 + FLICKER_STRENGTH * sin(iTime * FLICKER_SPEED);

    float phosphorPhase = fract(contentCoord.x / 3.0);
    vec3 phosphor = vec3(1.0 - PHOSPHOR_STRENGTH);
    if (phosphorPhase < 0.3333333) {
        phosphor.r += PHOSPHOR_STRENGTH * 1.6;
    } else if (phosphorPhase < 0.6666667) {
        phosphor.g += PHOSPHOR_STRENGTH * 1.45;
    } else {
        phosphor.b += PHOSPHOR_STRENGTH * 1.5;
    }

    vec2 centered = uv * (1.0 - uv.yx);
    float vignette = mix(1.0 - VIGNETTE_STRENGTH, 1.0, pow(max(centered.x * centered.y * 18.0, 0.0), 0.45));

    float highlight = smoothstep(0.78, 0.08, abs(uv.x - 0.30) + abs(uv.y - 0.14) * 1.7);
    vec3 glass = vec3(0.82, 0.95, 1.0) * highlight * GLASS_HIGHLIGHT;
    float radialReflection = pow(
        max(0.0, 1.0 - length(uv - vec2(0.5)) / RADIAL_REFLECTION_RADIUS),
        RADIAL_REFLECTION_SOFTNESS
    );
    vec3 reflection = RADIAL_REFLECTION_COLOR * radialReflection * RADIAL_REFLECTION_STRENGTH;
    vec3 glow = sampleGlow(warpedUv, texel) * GLOW_STRENGTH;
    vec3 bloom = sampleBloom(warpedUv, texel) * BLOOM_STRENGTH;
    float burnLuma = dot(glow + bloom + color * 0.35, vec3(0.2126, 0.7152, 0.0722));
    float burnMask = smoothstep(BURN_THRESHOLD, BURN_THRESHOLD + BURN_SOFTNESS, burnLuma);
    vec3 burn = BURN_COLOR * burnMask * BURN_STRENGTH;

    vec2 barrelDelta = warpedUv * 2.0 - 1.0;
    float barrelEdge = smoothstep(0.45, 1.15, dot(barrelDelta, barrelDelta));
    float barrelShade = 1.0 - BARREL_EDGE_DARKENING * pow(barrelEdge, BARREL_EDGE_SOFTNESS);
    float noise = analogNoise(contentCoord, uv, resolution, iTime) * NOISE_STRENGTH;

    color *= scan * horizontalRaster * beam * flicker * phosphor * vignette * barrelShade;
    color = mix(color, color * BURN_COLOR, burnMask * BURN_STRENGTH * 0.45);
    color += glow + bloom + glass + reflection + burn + noise;
    color = mix(color, color * vec3(1.0 + COLOR_WARMTH, 1.0 + COLOR_WARMTH * 0.45, 1.0 - COLOR_WARMTH), 0.5);
    color = mix(color, color * CRT_TINT, CRT_TINT_STRENGTH);
    color = iBackgroundColor + (color - iBackgroundColor) * CONTRAST_BOOST;
    color = mix(originalColor, color, BASE_MIX);
    color = clamp(color, 0.0, 1.0);

    fragColor = vec4(color, 1.0);
}
