using System.Collections.Generic;
using UnityEngine;

namespace PixelPunch3D
{
    /// <summary>
    /// Material + texture factory. Lit materials are cloned from Unity's own
    /// default material so the shader is always included in builds, and work
    /// in both the Built-in and URP render pipelines (color/mainTexture map to
    /// the pipeline's main properties).
    /// </summary>
    public static class Mats
    {
        static Material _lit;
        static Material _unlit;
        static readonly Dictionary<string, Material> Cache = new();

        static Material LitBase
        {
            get
            {
                if (_lit != null) return _lit;
                var probe = GameObject.CreatePrimitive(PrimitiveType.Cube);
                _lit = new Material(probe.GetComponent<Renderer>().sharedMaterial);
                Object.Destroy(probe);
                return _lit;
            }
        }

        public static Material Color(Color color, float smoothness = 0.1f)
        {
            var key = $"c{ColorUtility.ToHtmlStringRGBA(color)}{smoothness:0.00}";
            if (Cache.TryGetValue(key, out var m) && m != null) return m;
            m = new Material(LitBase) { color = color, mainTexture = null };
            SetSmoothness(m, smoothness);
            Cache[key] = m;
            return m;
        }

        public static Material Textured(string key, Texture2D texture, Color tint, Vector2 tiling, float smoothness = 0.05f)
        {
            key = $"t{key}{tiling.x:0.0}x{tiling.y:0.0}";
            if (Cache.TryGetValue(key, out var m) && m != null) return m;
            m = new Material(LitBase) { color = tint, mainTexture = texture, mainTextureScale = tiling };
            SetSmoothness(m, smoothness);
            Cache[key] = m;
            return m;
        }

        /// A fresh (not shared) lit material, e.g. for a character's own face.
        public static Material Unique(Color color, Texture texture = null)
        {
            var m = new Material(LitBase) { color = color, mainTexture = texture };
            SetSmoothness(m, 0.15f);
            return m;
        }

        /// Unlit, alpha-blended, double-sided (Sprites/Default is always in builds).
        public static Material Transparent(Color color)
        {
            var key = $"u{ColorUtility.ToHtmlStringRGBA(color)}";
            if (Cache.TryGetValue(key, out var m) && m != null) return m;
            if (_unlit == null) _unlit = new Material(Shader.Find("Sprites/Default"));
            m = new Material(_unlit) { color = color };
            Cache[key] = m;
            return m;
        }

        static void SetSmoothness(Material m, float value)
        {
            if (m.HasProperty("_Glossiness")) m.SetFloat("_Glossiness", value);
            if (m.HasProperty("_Smoothness")) m.SetFloat("_Smoothness", value);
            if (m.HasProperty("_Metallic")) m.SetFloat("_Metallic", 0f);
        }

        public static void ClearCache()
        {
            foreach (var m in Cache.Values) if (m != null) Object.Destroy(m);
            Cache.Clear();
        }
    }

    /// <summary>Small procedural textures so the project needs no art files.</summary>
    public static class ProcTex
    {
        static readonly Dictionary<string, Texture2D> Cache = new();

        static Texture2D Make(string key, int size, System.Func<int, int, Color> pixel)
        {
            if (Cache.TryGetValue(key, out var t) && t != null) return t;
            t = new Texture2D(size, size, TextureFormat.RGBA32, true)
            {
                wrapMode = TextureWrapMode.Repeat,
                filterMode = FilterMode.Bilinear,
                anisoLevel = 2,
                name = key,
            };
            var pixels = new Color[size * size];
            for (int y = 0; y < size; y++)
                for (int x = 0; x < size; x++)
                    pixels[y * size + x] = pixel(x, y);
            t.SetPixels(pixels);
            t.Apply(true, false);
            Cache[key] = t;
            return t;
        }

        static float Noise(float x, float y, float scale, int octaves = 3)
        {
            float sum = 0, amp = 1, norm = 0;
            for (int i = 0; i < octaves; i++)
            {
                sum += Mathf.PerlinNoise(x * scale + 17.3f * i, y * scale + 41.7f * i) * amp;
                norm += amp;
                amp *= 0.5f;
                scale *= 2f;
            }
            return sum / norm;
        }

        static float Hash(int x, int y) => Mathf.Abs(Mathf.Sin(x * 12.9898f + y * 78.233f) * 43758.5453f) % 1f;

        public static Texture2D Grass => Make("grass", 128, (x, y) =>
        {
            var n = Noise(x, y, 0.06f);
            var blade = Hash(x, y) * 0.12f;
            return new Color(0.22f + n * 0.12f + blade, 0.42f + n * 0.2f + blade, 0.16f + n * 0.06f);
        });

        public static Texture2D Dirt => Make("dirt", 128, (x, y) =>
        {
            var n = Noise(x, y, 0.08f);
            var pebble = Hash(x, y) > 0.94f ? 0.12f : 0f;
            return new Color(0.42f + n * 0.15f + pebble, 0.32f + n * 0.12f + pebble, 0.2f + n * 0.08f + pebble);
        });

        public static Texture2D Rock => Make("rock", 128, (x, y) =>
        {
            var n = Noise(x, y, 0.09f, 4);
            var crack = Mathf.Abs(Noise(x, y, 0.03f) - 0.5f) < 0.02f ? -0.15f : 0f;
            var v = 0.42f + n * 0.25f + crack;
            return new Color(v, v * 0.98f, v * 0.95f);
        });

        public static Texture2D Brick => Make("brick", 128, (x, y) =>
        {
            int row = y / 16;
            int offset = row % 2 == 0 ? 0 : 16;
            bool mortar = y % 16 < 2 || (x + offset) % 32 < 2;
            if (mortar) return new Color(0.75f, 0.73f, 0.68f);
            var n = Noise(x, y, 0.2f) * 0.15f + Hash((x + offset) / 32, row) * 0.15f;
            return new Color(0.6f + n, 0.28f + n * 0.5f, 0.22f + n * 0.4f);
        });

        public static Texture2D Plaster => Make("plaster", 128, (x, y) =>
        {
            var n = Noise(x, y, 0.1f) * 0.08f + Hash(x, y) * 0.04f;
            return new Color(0.86f + n, 0.84f + n, 0.78f + n);
        });

        public static Texture2D Roof => Make("roof", 128, (x, y) =>
        {
            bool line = y % 12 < 2;
            var n = Noise(x, y, 0.15f) * 0.1f;
            return line ? new Color(0.25f, 0.12f, 0.1f) : new Color(0.55f + n, 0.22f + n, 0.16f + n);
        });

        public static Texture2D Wood => Make("wood", 128, (x, y) =>
        {
            var grain = Mathf.Sin((x + Noise(x, y, 0.05f) * 40f) * 0.35f) * 0.06f;
            bool seam = y % 32 < 1;
            var c = new Color(0.55f + grain, 0.38f + grain, 0.22f + grain);
            return seam ? c * 0.6f : c;
        });

        public static Texture2D Concrete => Make("concrete", 128, (x, y) =>
        {
            var v = 0.55f + Noise(x, y, 0.12f) * 0.12f + Hash(x, y) * 0.05f;
            return new Color(v, v, v * 1.02f);
        });

        /// White ring used for the minimap's safe-zone circle.
        public static Texture2D Ring => Make("ring", 128, (x, y) =>
        {
            var d = Vector2.Distance(new Vector2(x, y), new Vector2(63.5f, 63.5f));
            var a = Mathf.Clamp01(1f - Mathf.Abs(d - 60f) / 2.5f);
            return new Color(1, 1, 1, a);
        });

        public static Texture2D Circle => Make("circle", 64, (x, y) =>
        {
            var d = Vector2.Distance(new Vector2(x, y), new Vector2(31.5f, 31.5f));
            return new Color(1, 1, 1, Mathf.Clamp01(31f - d));
        });

        public static Sprite Sprite(Texture2D texture) =>
            UnityEngine.Sprite.Create(texture, new Rect(0, 0, texture.width, texture.height), new Vector2(0.5f, 0.5f));
    }
}
