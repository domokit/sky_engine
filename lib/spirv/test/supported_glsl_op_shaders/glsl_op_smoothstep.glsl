#version 320 es

precision highp float;

layout(location = 0) out vec4 fragColor;

// performs Hermite interpolation between two values:
//
// smoothstep(edge0, edge1, 0) {
//   t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
//   return t * t * (3.0 - 2.0 * t);
// }
void main() {
    fragColor = vec4(
        // smoothstep(1.0, 5.0, 0.25) is -1.0, add 1.0 to get 0.0
        smoothstep(1.0, 5.0, 0.25) + 1.0,
        // smoothstep(0.0, 2.0, 1.0) is 0.5, add 0.5 to get 1.0
        smoothstep(0.0, 2.0, 1.0) + 0.5,
        0.0,
        1.0
    );
}
