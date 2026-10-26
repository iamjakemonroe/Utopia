// A pool ball, drawn as a lit sphere in the square it's painted into: its
// colour, its stripe (white caps either side of the band) or not, a white
// disc where its number goes, and the cue ball's two red dots, all turning
// with the ball as it rolls (uRow0-2: the ball's orientation, from the
// view into the ball). lib/features/pool/presentation/pool_art.dart sets
// it up.
#include <flutter/runtime_effect.glsl>

uniform vec2 uOrigin;   // the square's top-left (logical pixels)
uniform vec2 uSize;     // its size
uniform vec3 uRow0;
uniform vec3 uRow1;
uniform vec3 uRow2;
uniform vec4 uColor;    // the ball's colour (straight alpha)
uniform float uKind;    // 0 solid, 1 stripe, 2 cue ball
uniform float uPixel;   // one device pixel, as a fraction of the radius

out vec4 fragColor;

void main() {
  vec2 p = (FlutterFragCoord().xy - uOrigin) / uSize * 2.0 - 1.0;
  float r2 = dot(p, p);
  if (r2 > 1.0) {
    fragColor = vec4(0.0);
    return;
  }
  // The point on the sphere facing us, and where that is on the ball.
  vec3 n = vec3(p.x, p.y, sqrt(1.0 - r2));
  vec3 local = vec3(dot(uRow0, n), dot(uRow1, n), dot(uRow2, n));

  vec3 white = vec3(0.97, 0.96, 0.93);
  vec3 base = uColor.rgb;
  float edge = uPixel * 2.0;
  if (uKind < 0.5) {
    // A solid: white number disc at its pole.
    float disc = smoothstep(0.885 - edge, 0.885 + edge, local.z);
    base = mix(base, white, disc);
  } else if (uKind < 1.5) {
    // A stripe: white caps above and below the band; the number disc on
    // the band.
    float cap = smoothstep(0.6 - edge, 0.6 + edge, abs(local.z));
    base = mix(base, white, cap);
    float disc = smoothstep(0.91 - edge, 0.91 + edge, local.x);
    base = mix(base, white, disc);
  } else {
    // The cue ball: two small red dots, so its spin shows.
    base = white;
    float dot = smoothstep(0.975 - edge, 0.975 + edge, abs(local.z));
    base = mix(base, vec3(0.86, 0.16, 0.2), dot);
  }

  // Lit from the top left: soft diffuse, a bright highlight, a darker rim.
  vec3 light = normalize(vec3(-0.45, -0.55, 0.7));
  float diffuse = 0.5 + 0.5 * max(dot(n, light), 0.0);
  vec3 h = normalize(light + vec3(0.0, 0.0, 1.0));
  float spec = pow(max(dot(n, h), 0.0), 48.0);
  float rim = smoothstep(0.55, 1.0, r2) * 0.28;
  vec3 colour = base * diffuse * (1.0 - rim) + vec3(spec * 0.75);

  // Smooth along the edge, and premultiplied.
  float alpha = 1.0 - smoothstep(1.0 - edge, 1.0, sqrt(r2));
  fragColor = vec4(colour * alpha, alpha);
}
