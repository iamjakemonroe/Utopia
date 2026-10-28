// A pool cue, drawn lying along x in the rectangle it's painted into: the
// tip at x = 0, the butt at x = uSize.x, centred on y = 0 (the rectangle
// runs from -uSize.y/2 to uSize.y/2 across, with room around the cue for
// an animated cue's glow). A tapered, lit cylinder: the blue tip, the
// ferrule, the maple shaft, the joint ring, then the cue's own design
// (uStyle, CueLook in lib/features/pool/domain/pool_cues.dart), moving
// with uTime when it's animated, brighter the higher its level (uLevel,
// 0 to 1). lib/features/pool/presentation/pool_cue_art.dart sets it up.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;    // the cue's length, and the rectangle's height
uniform float uThick;  // the butt's radius
uniform float uTime;   // seconds
uniform float uStyle;  // CueLook's index
uniform float uLevel;  // 0 at level 1, 1 at the cue's top level
uniform float uPx;     // one device pixel, in the rectangle's units

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 3; i++) {
    v += a * noise(p);
    p = p * 2.03 + vec2(1.7, 9.2);
    a *= 0.5;
  }
  return v;
}

vec3 hue(float h) {
  return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

// A thin bright line where |d| is small, with a soft glow round it.
float glowLine(float d, float width, float spread) {
  return smoothstep(width, 0.0, abs(d)) + exp(-abs(d) / spread) * 0.35;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float L = uSize.x;
  float u = p.x / L;              // 0 at the tip, 1 at the butt
  float y = p.y;
  float t = uTime;
  int style = int(uStyle + 0.5);
  bool animated = style >= 4;

  // The cue's radius along it: slim at the tip, thick at the butt, the
  // butt's end rounded.
  float R = uThick;
  float r = R * (0.34 + 0.66 * pow(clamp(u, 0.0, 1.0), 0.85));
  float endRound = smoothstep(1.0, 0.985, u);
  r *= mix(0.55, 1.0, endRound);
  float inside = smoothstep(r + uPx, r - uPx, abs(y)) * step(0.0, u) * step(u, 1.0);

  // An animated cue's aura, outside it, growing with its level.
  float aura = 0.0;
  if (animated) {
    float d = max(abs(y) - r, 0.0) / R;
    float along = smoothstep(0.0, 0.08, u) * smoothstep(1.02, 0.95, u);
    aura = exp(-d * 3.2) * (0.18 + 0.32 * uLevel) * along * (0.85 + 0.15 * sin(t * 2.4));
  }

  // Across the cylinder: -1 at the top edge, 1 at the bottom; the surface
  // facing us and the light from the top left.
  float v = clamp(y / max(r, 1e-4), -1.0, 1.0);
  float nz = sqrt(max(1.0 - v * v, 0.0));
  vec3 n = vec3(0.0, v, nz);
  vec3 light = normalize(vec3(-0.3, -0.62, 0.72));
  float diffuse = 0.42 + 0.58 * max(dot(n, light), 0.0);
  float spec = pow(max(dot(n, normalize(light + vec3(0.0, 0.0, 1.0))), 0.0), 38.0);
  float x = p.x / R;              // along, in butt radii (patterns' scale)

  vec3 c;
  float glow = 0.0;               // extra light the design gives off
  vec3 glowColor = vec3(1.0);

  // Tip, ferrule, shaft, joint: the same on every cue.
  // Kept as separate branches, not else-ifs: a long chain nests deeper
  // than the web's shader compiler takes.
  c = vec3(0.23, 0.45, 0.86);
  if (u >= 0.012 && u < 0.036) {
    c = vec3(0.96, 0.94, 0.88);
  }
  if (u >= 0.036 && u < 0.5) {
    float grain = noise(vec2(x * 0.45, v * 3.0)) * 0.06;
    c = vec3(0.92, 0.82, 0.62) - grain;
    if (animated) {
      // A thin line of the design's light runs up the shaft.
      float line = glowLine(v - 0.15, 0.08, 0.25) * smoothstep(0.08, 0.5, u);
      glow += line * 0.35;
    }
  }
  if (u >= 0.5 && u < 0.524) {
    float band = 0.5 + 0.5 * sin(x * 14.0);
    c = mix(vec3(0.85, 0.68, 0.28), vec3(1.0, 0.9, 0.55), band);
  }
  if (u >= 0.524) {
    // The design, from the joint to the butt.
    float w = (u - 0.524) / 0.476;  // 0 at the joint, 1 at the butt
    if (style == 0) {
      // Classic: midnight, two gold rings, a black wrap.
      c = vec3(0.1, 0.13, 0.26);
      if (w > 0.55 && w < 0.85) c = vec3(0.06, 0.06, 0.07) + noise(vec2(x * 4.0, v * 9.0)) * 0.05;
      if (abs(w - 0.18) < 0.012 || abs(w - 0.55) < 0.01 || abs(w - 0.86) < 0.01) c = vec3(0.95, 0.76, 0.3);
    }
    if (style == 1) {
      // Old Oak: walnut grain and brass rings.
      float grain = sin(x * 1.3 + fbm(vec2(x * 0.3, v * 2.5)) * 6.0);
      c = mix(vec3(0.3, 0.17, 0.08), vec3(0.52, 0.32, 0.16), 0.5 + 0.5 * grain);
      if (abs(w - 0.02) < 0.012 || abs(w - 0.6) < 0.014 || abs(w - 0.9) < 0.012) c = vec3(0.86, 0.66, 0.3);
    }
    if (style == 2) {
      // Carbon Strike: a carbon weave and a red stripe.
      vec2 q = vec2(x * 1.6, v * 3.0);
      float weave = step(0.5, fract((q.x + q.y) * 0.5)) * 0.5 + step(0.5, fract((q.x - q.y) * 0.5)) * 0.5;
      c = mix(vec3(0.08, 0.09, 0.1), vec3(0.2, 0.22, 0.25), weave);
      if (abs(w - 0.42) < 0.04) c = vec3(0.9, 0.18, 0.16);
      if (abs(w - 0.36) < 0.006 || abs(w - 0.48) < 0.006) c = vec3(0.85, 0.85, 0.9);
    }
    if (style == 3) {
      // Ivory Royale: ebony with ivory points.
      c = vec3(0.07, 0.05, 0.05);
      float point = 1.0 - w / 0.42;
      if (point > 0.0) {
        float a = min(abs(v), abs(abs(v) - 0.95));
        if (a < point * 0.42) c = vec3(0.95, 0.92, 0.84);
      }
      if (abs(w - 0.5) < 0.012 || abs(w - 0.9) < 0.012) c = vec3(0.92, 0.88, 0.8);
    }
    if (style == 4) {
      // Neon Pulse: pink and cyan lines that breathe.
      c = vec3(0.04, 0.03, 0.09);
      float pulse = 0.7 + 0.3 * sin(t * 3.2);
      float s1 = fract(x * 0.12 + v * 0.22 - t * 0.35);
      float s2 = fract(x * 0.12 - v * 0.22 - t * 0.35 + 0.5);
      vec3 pink = vec3(1.0, 0.25, 0.85);
      vec3 cyan = vec3(0.17, 0.96, 1.0);
      c += pink * glowLine(s1 - 0.5, 0.05, 0.08) * pulse;
      c += cyan * glowLine(s2 - 0.5, 0.05, 0.08) * pulse;
      glow += 0.5 * pulse;
      glowColor = mix(pink, cyan, 0.5 + 0.5 * sin(t * 1.6));
    }
    if (style == 5) {
      // Frostbite: ice that creeps and sparkles.
      vec2 cell = floor(vec2(x * 1.2, v * 4.0));
      float facet = hash(cell);
      c = mix(vec3(0.24, 0.48, 0.84), vec3(0.62, 0.9, 1.0), facet * 0.7 + 0.3 * w);
      float creep = 0.5 + 0.5 * sin(t * 0.8);
      float frost = smoothstep(creep - 0.25, creep + 0.05, fbm(vec2(x * 0.5, v * 3.0)) + w * 0.4);
      c = mix(c, vec3(0.95, 0.98, 1.0), frost * 0.55);
      float twinkle = pow(max(sin(t * 4.0 + facet * 40.0), 0.0), 18.0) * step(0.86, facet);
      c += vec3(1.0) * twinkle * 1.4;
      glow += 0.3 + twinkle;
      glowColor = vec3(0.6, 0.9, 1.0);
    }
    if (style == 6) {
      // Inferno: molten cracks flowing towards the butt.
      c = vec3(0.1, 0.02, 0.01);
      float f = fbm(vec2(x * 0.45 - t * 0.9, v * 2.2 + t * 0.2));
      float crack = smoothstep(0.08, 0.0, abs(f - 0.5));
      float heat = 0.75 + 0.25 * sin(t * 5.0 + x);
      c += mix(vec3(1.0, 0.25, 0.02), vec3(1.0, 0.85, 0.3), crack) * (crack * 1.4 + 0.2 * f) * heat;
      glow += 0.45 * heat;
      glowColor = vec3(1.0, 0.45, 0.08);
    }
    if (style == 7) {
      // Thunderbolt: arcs crawling along it, flickering.
      c = vec3(0.07, 0.05, 0.2);
      for (int k = 0; k < 3; k++) {
        float fk = float(k);
        float path = sin(x * 2.1 + t * 14.0 + fk * 2.3) * 0.35 + (noise(vec2(x * 1.7 + t * 9.0, fk)) - 0.5) * 0.9;
        float on = step(0.32, fract(t * 2.7 + fk * 0.41));
        c += vec3(0.62, 0.86, 1.0) * glowLine(v - path, 0.06, 0.12) * on;
      }
      glow += 0.45 + 0.25 * step(0.5, fract(t * 6.0));
      glowColor = vec3(0.55, 0.8, 1.0);
    }
    if (style == 8) {
      // Galaxy: a nebula swirling inside, stars twinkling.
      c = mix(vec3(0.05, 0.02, 0.14), vec3(0.15, 0.04, 0.32), w);
      float neb = fbm(vec2(x * 0.35 + t * 0.12, v * 1.8 - t * 0.05));
      c += mix(vec3(0.85, 0.2, 0.75), vec3(0.2, 0.45, 1.0), neb) * smoothstep(0.35, 0.8, neb) * 0.9;
      vec2 sc = floor(vec2(x * 2.4, v * 6.0));
      float s = hash(sc);
      float star = step(0.9, s) * (0.5 + 0.5 * sin(t * 3.0 + s * 50.0));
      c += vec3(1.0) * star;
      glow += 0.35 + 0.15 * neb;
      glowColor = vec3(0.6, 0.4, 1.0);
    }
    if (style == 9) {
      // Phoenix: crimson and gold feathers, a shine sweeping along.
      float feather = fract(x * 0.32 - abs(v) * 0.55);
      c = mix(vec3(0.62, 0.06, 0.08), vec3(1.0, 0.62, 0.12), feather);
      c = mix(c, vec3(1.0, 0.9, 0.55), smoothstep(0.9, 1.0, feather) * 0.8);
      float sd = (w - fract(t * 0.35) * 1.4 + 0.2) * 9.0;
      float sweep = exp(-sd * sd);
      c += vec3(1.0, 0.85, 0.5) * sweep * 0.9;
      glow += 0.4 + sweep * 0.5;
      glowColor = vec3(1.0, 0.55, 0.15);
    }
    if (style == 10) {
      // Prism: rainbow light pouring through glass.
      c = hue(fract(x * 0.05 - t * 0.25 + v * 0.08)) * 0.85 + 0.12;
      float facet = step(0.97, fract(x * 0.25 + v * 0.5)) + step(0.97, fract(x * 0.25 - v * 0.5));
      c = mix(c, vec3(1.0), facet * 0.7);
      float glint = pow(max(sin(t * 2.0 - x * 0.4), 0.0), 24.0);
      c += vec3(1.0) * glint * 0.8;
      glow += 0.55;
      glowColor = hue(fract(t * 0.2));
    }
    if (style == 11) {
      // Jade Dragon: emerald scales, jade fire running along them.
      vec2 q = vec2(x * 0.8, v * 2.2);
      q.x += step(1.0, mod(floor(q.y), 2.0)) * 0.5;
      vec2 f = fract(q) - vec2(0.5, 0.2);
      float scale = length(f * vec2(1.0, 1.6));
      c = mix(vec3(0.02, 0.24, 0.15), vec3(0.08, 0.5, 0.32), smoothstep(0.55, 0.2, scale));
      c = mix(c, vec3(0.95, 0.78, 0.35), smoothstep(0.5, 0.56, scale) * 0.8);
      float fire = fbm(vec2(x * 0.5 - t * 1.4, v * 2.0));
      float flame = smoothstep(0.55, 0.85, fire) * (0.6 + 0.4 * sin(t * 6.0 + x));
      c += vec3(0.25, 1.0, 0.65) * flame;
      glow += 0.45 + flame * 0.4;
      glowColor = vec3(0.3, 1.0, 0.65);
    }
    // The butt cap.
    if (w > 0.975) c = vec3(0.06, 0.06, 0.07);
  }

  // The design's own light comes through the shading; the rest is lit.
  float lit = animated ? mix(diffuse, 1.0, 0.35) : diffuse;
  vec3 colour = c * lit + vec3(spec) * (animated ? 0.55 : 0.7);
  colour += glowColor * glow * 0.12 * (0.7 + 0.6 * uLevel) * nz;

  // Premultiplied: the aura is light over whatever's behind.
  float a = clamp(aura, 0.0, 1.0);
  fragColor = vec4(colour * inside + glowColor * a * (1.0 - inside), inside + a * (1.0 - inside));
}
