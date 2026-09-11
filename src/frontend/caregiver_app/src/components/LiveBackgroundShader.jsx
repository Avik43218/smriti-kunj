import React, { useEffect, useRef } from 'react';
import { useTheme } from '../context/ThemeContext';

const VERTEX_SHADER = `
  attribute vec2 a_position;
  varying vec2 v_texCoord;
  void main() {
    v_texCoord = a_position * 0.5 + 0.5;
    gl_Position = vec4(a_position, 0.0, 1.0);
  }
`;

const FRAGMENT_SHADER = `
  precision highp float;
  uniform float u_time;
  uniform vec2 u_resolution;
  uniform vec2 u_mouse;
  uniform float u_theme_blend; // 1.0 for dark, 0.0 for light
  varying vec2 v_texCoord;

  // Cultural Silk & River Brahmaputra flowing weave shader

  float hash(vec2 p) {
      return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
  }

  float noise(vec2 p) {
      vec2 i = floor(p);
      vec2 f = fract(p);
      vec2 u = f * f * (3.0 - 2.0 * f);
      return mix(mix(hash(i + vec2(0.0,0.0)), hash(i + vec2(1.0,0.0)), u.x),
                 mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x), u.y);
  }

  // Gamusa geometric diamond weave
  float diamondGrid(vec2 uv, float scale) {
      vec2 gv = fract(uv * scale) - 0.5;
      float d = abs(gv.x) + abs(gv.y);
      return smoothstep(0.48, 0.44, d) - smoothstep(0.38, 0.34, d);
  }

  void main() {
      vec2 uv = gl_FragCoord.xy / u_resolution.xy;
      vec2 p = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / min(u_resolution.x, u_resolution.y);
      
      // Gentle mouse parallax
      vec2 m = (u_mouse / u_resolution - 0.5) * 0.35;
      p += m;

      float t = u_time * 0.25;

      // Organic river & hill wave deformation
      float flow1 = sin(p.x * 2.5 + t + sin(p.y * 2.0 + t * 0.7)) * 0.35;
      float flow2 = cos(p.y * 3.0 - t * 0.8 + cos(p.x * 2.2)) * 0.35;
      vec2 warpedP = p + vec2(flow1, flow2);

      // Balanced Dark Mode Cultural Palette (Harmonized with #2E2A24 dashboard dark mode):
      vec3 deepRed = vec3(0.58, 0.14, 0.16);         // Gamusa Red (#942429)
      vec3 warmInkDark = vec3(0.133, 0.110, 0.098);  // Balanced Warm Dark Ink (#221C19)
      vec3 mugaGold = vec3(0.85, 0.56, 0.16);        // Assam Golden Muga Silk

      // Wave ridges
      float wave1 = sin(warpedP.x * 4.0 + warpedP.y * 3.0 + t);
      float wave2 = cos(warpedP.x * 6.0 - warpedP.y * 5.0 - t * 1.2);
      float blend = smoothstep(-0.6, 0.8, wave1 * 0.6 + wave2 * 0.4);

      vec3 col = mix(warmInkDark, deepRed, blend * 0.72);

      // Subtle cultural textile weave overlay
      float weave = diamondGrid(warpedP + vec2(t * 0.05, t * 0.03), 12.0);
      col += mugaGold * weave * 0.35;

      // Luminous silk highlights
      float sheen = pow(max(0.0, sin(p.x * 3.0 + p.y * 4.0 + t * 1.5)), 4.0);
      col += mugaGold * sheen * 0.24;

      // Ambient edge vignette
      float vignette = smoothstep(1.2, 0.2, length(p * vec2(0.9, 1.1)));
      col = mix(col * 0.50, col, vignette);

      // Floating subtle golden embers/particles
      vec2 particleUv = uv * 24.0 + vec2(sin(t * 0.5), t * 1.2);
      float n = noise(particleUv);
      float embers = smoothstep(0.72, 0.78, n) * smoothstep(0.0, 0.8, sin(u_time * 2.0 + n * 20.0));
      col += mugaGold * embers * 0.42;

      // Theme blending
      vec3 lightAdjust = col * 0.95 + vec3(0.04, 0.03, 0.02);
      vec3 finalCol = mix(lightAdjust, col, u_theme_blend);

      gl_FragColor = vec4(finalCol, 1.0);
  }
`;

export const LiveBackgroundShader = () => {
  const canvasRef = useRef(null);
  const { theme } = useTheme();
  const themeBlendRef = useRef(theme === 'dark' ? 1.0 : 0.0);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    let animationFrameId;
    let gl = canvas.getContext('webgl', { powerPreference: 'low-power', alpha: false, antialias: false }) ||
             canvas.getContext('experimental-webgl', { powerPreference: 'low-power', alpha: false });

    // Fallback if WebGL isn't supported
    if (!gl) {
      const ctx = canvas.getContext('2d');
      if (!ctx) return;

      const handleFallbackResize = () => {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
      };
      handleFallbackResize();
      window.addEventListener('resize', handleFallbackResize);

      let t = 0;
      const render2d = () => {
        t += 0.01;
        ctx.fillStyle = '#221C19';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        const grad = ctx.createRadialGradient(
          canvas.width * 0.4 + Math.sin(t) * 40,
          canvas.height * 0.5 + Math.cos(t) * 25,
          20,
          canvas.width * 0.5,
          canvas.height * 0.5,
          canvas.width * 0.75
        );
        grad.addColorStop(0, 'rgba(148, 36, 41, 0.65)');
        grad.addColorStop(0.5, 'rgba(217, 119, 6, 0.35)');
        grad.addColorStop(1, 'rgba(34, 28, 25, 0.95)');

        ctx.fillStyle = grad;
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        animationFrameId = requestAnimationFrame(render2d);
      };
      render2d();

      return () => {
        cancelAnimationFrame(animationFrameId);
        window.removeEventListener('resize', handleFallbackResize);
      };
    }

    // WebGL Shader Compilation
    const createShader = (glContext, type, source) => {
      const shader = glContext.createShader(type);
      glContext.shaderSource(shader, source);
      glContext.compileShader(shader);
      if (!glContext.getShaderParameter(shader, glContext.COMPILE_STATUS)) {
        console.warn('Shader compile failed:', glContext.getShaderInfoLog(shader));
        glContext.deleteShader(shader);
        return null;
      }
      return shader;
    };

    const vertShader = createShader(gl, gl.VERTEX_SHADER, VERTEX_SHADER);
    const fragShader = createShader(gl, gl.FRAGMENT_SHADER, FRAGMENT_SHADER);
    if (!vertShader || !fragShader) return;

    const program = gl.createProgram();
    gl.attachShader(program, vertShader);
    gl.attachShader(program, fragShader);
    gl.linkProgram(program);

    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      console.warn('Program link failed:', gl.getProgramInfoLog(program));
      return;
    }

    gl.useProgram(program);

    // Quad geometry (Triangle Strip)
    const positionBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    gl.bufferData(
      gl.ARRAY_BUFFER,
      new Float32Array([-1.0, -1.0, 1.0, -1.0, -1.0, 1.0, 1.0, 1.0]),
      gl.STATIC_DRAW
    );

    const positionLocation = gl.getAttribLocation(program, 'a_position');
    gl.enableVertexAttribArray(positionLocation);
    gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);

    const uResolution = gl.getUniformLocation(program, 'u_resolution');
    const uTime = gl.getUniformLocation(program, 'u_time');
    const uMouse = gl.getUniformLocation(program, 'u_mouse');
    const uThemeBlend = gl.getUniformLocation(program, 'u_theme_blend');

    let mouseX = window.innerWidth / 2;
    let mouseY = window.innerHeight / 2;

    const handleMouseMove = (event) => {
      const rect = canvas.getBoundingClientRect();
      if (rect.width && rect.height) {
        const nx = (event.clientX - rect.left) / rect.width;
        const ny = 1.0 - (event.clientY - rect.top) / rect.height;
        mouseX = nx * canvas.width;
        mouseY = ny * canvas.height;
      }
    };
    window.addEventListener('mousemove', handleMouseMove, { passive: true });

    const resize = () => {
      const w = window.innerWidth;
      const h = window.innerHeight;
      if (canvas.width !== w || canvas.height !== h) {
        canvas.width = w;
        canvas.height = h;
        gl.viewport(0, 0, w, h);
      }
    };
    resize();
    window.addEventListener('resize', resize);

    const startTime = performance.now();

    const render = () => {
      const now = performance.now();
      const elapsed = (now - startTime) * 0.001;

      // Smooth interpolation of theme transition
      const targetTheme = theme === 'dark' ? 1.0 : 0.0;
      themeBlendRef.current += (targetTheme - themeBlendRef.current) * 0.06;

      gl.viewport(0, 0, canvas.width, canvas.height);
      if (uResolution) gl.uniform2f(uResolution, canvas.width, canvas.height);
      if (uTime) gl.uniform1f(uTime, elapsed);
      if (uMouse) gl.uniform2f(uMouse, mouseX, mouseY);
      if (uThemeBlend) gl.uniform1f(uThemeBlend, themeBlendRef.current);

      gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
      animationFrameId = requestAnimationFrame(render);
    };

    animationFrameId = requestAnimationFrame(render);

    return () => {
      cancelAnimationFrame(animationFrameId);
      window.removeEventListener('resize', resize);
      window.removeEventListener('mousemove', handleMouseMove);
      if (gl) {
        gl.deleteProgram(program);
        gl.deleteShader(vertShader);
        gl.deleteShader(fragShader);
        gl.deleteBuffer(positionBuffer);
      }
    };
  }, [theme]);

  return (
    <div className="fixed inset-0 w-full h-full pointer-events-none z-0 overflow-hidden">
      <canvas
        ref={canvasRef}
        aria-hidden="true"
        className="absolute inset-0 w-full h-full object-cover transition-opacity duration-700 ease-in-out"
        style={{
          transform: 'translateZ(0)',
          willChange: 'transform',
        }}
      />
      {/* Silk Loom Veil & Balanced Dark Mode Underlay (#221C19) */}
      <div className="absolute inset-0 bg-gradient-to-tr from-[#221C19]/90 via-[#26201D]/80 to-[#7d1017]/40 backdrop-blur-[6px] transition-all duration-700 ease-in-out pointer-events-none" />
      <div className="absolute -top-32 -left-32 w-96 h-96 bg-[#9e2a2b]/20 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute -bottom-32 -right-32 w-[30rem] h-[30rem] bg-[#fec97b]/15 rounded-full blur-3xl pointer-events-none" />
    </div>
  );
};

export default LiveBackgroundShader;
