using System;
using System.Collections.Generic;
using UnityEngine;

namespace PixelPunch3D
{
    /// <summary>
    /// Face photos for villains (by roster index) and the textures/meshes that
    /// turn a front photo into a 3D head: the photo is projected onto the face
    /// side of the head, feathered into the skin tone, with hair at the back.
    /// </summary>
    public static class FaceLibrary
    {
        static readonly Dictionary<int, Texture2D> Photos = new();
        static readonly Dictionary<string, Texture2D> HeadTextures = new();
        static Mesh _headMesh;
        static Mesh _hairMesh;

        public static void Register(int index, string base64)
        {
            if (string.IsNullOrEmpty(base64)) return;
            try { Register(index, Convert.FromBase64String(base64)); }
            catch (FormatException) { Debug.LogWarning($"[Faces] Face {index} is not valid base64."); }
        }

        public static void Register(int index, byte[] png)
        {
            var tex = new Texture2D(2, 2, TextureFormat.RGBA32, false);
            if (!tex.LoadImage(png))
            {
                UnityEngine.Object.Destroy(tex);
                return;
            }
            tex.wrapMode = TextureWrapMode.Clamp;
            if (Photos.TryGetValue(index, out var old) && old != null) UnityEngine.Object.Destroy(old);
            Photos[index] = tex;
            // Any head texture built from an older photo is stale now.
            var stale = new List<string>();
            foreach (var key in HeadTextures.Keys) if (key.StartsWith($"{index}|")) stale.Add(key);
            foreach (var key in stale) HeadTextures.Remove(key);
        }

        public static Texture2D Photo(int index) => Photos.TryGetValue(index, out var t) ? t : null;

        public static void Clear()
        {
            foreach (var t in Photos.Values) if (t != null) UnityEngine.Object.Destroy(t);
            foreach (var t in HeadTextures.Values) if (t != null) UnityEngine.Object.Destroy(t);
            Photos.Clear();
            HeadTextures.Clear();
        }

        /// <summary>
        /// 512x256 atlas: left half = face (photo, or a drawn face), right half = hair.
        /// </summary>
        public static Texture2D HeadTexture(int photoIndex, Color skin, Color hair, bool villain)
        {
            var key = $"{photoIndex}|{ColorUtility.ToHtmlStringRGB(skin)}|{ColorUtility.ToHtmlStringRGB(hair)}|{villain}";
            if (HeadTextures.TryGetValue(key, out var cached) && cached != null) return cached;

            const int h = 256;
            var tex = new Texture2D(h * 2, h, TextureFormat.RGBA32, true) { wrapMode = TextureWrapMode.Clamp };
            var pixels = new Color[h * 2 * h];
            var photo = Photo(photoIndex);

            for (int y = 0; y < h; y++)
            {
                for (int x = 0; x < h; x++)
                {
                    float u = x / (float)(h - 1), v = y / (float)(h - 1);
                    // Soft oval: photo in the middle, skin towards the sides,
                    // hair colour above the forehead.
                    var dx = (u - 0.5f) / 0.43f;
                    var dy = (v - 0.47f) / 0.52f;
                    var oval = Mathf.Clamp01(1.25f - Mathf.Sqrt(dx * dx + dy * dy) * 1.25f) * 4f;
                    var baseColor = v > 0.82f ? Color.Lerp(skin, hair, Mathf.InverseLerp(0.82f, 0.92f, v)) : skin;
                    Color c;
                    if (photo != null)
                    {
                        var p = photo.GetPixelBilinear(u, v);
                        c = Color.Lerp(baseColor, p, Mathf.Clamp01(oval));
                    }
                    else
                    {
                        c = DrawnFace(u, v, baseColor, villain);
                    }
                    pixels[y * h * 2 + x] = c;
                }
                for (int x = h; x < h * 2; x++)
                {
                    var n = Mathf.PerlinNoise(x * 0.08f, y * 0.3f) * 0.12f;
                    pixels[y * h * 2 + x] = new Color(hair.r + n, hair.g + n, hair.b + n);
                }
            }
            tex.SetPixels(pixels);
            tex.Apply(true);
            HeadTextures[key] = tex;
            return tex;
        }

        /// Simple cartoon face for heroes/villains without a photo.
        static Color DrawnFace(float u, float v, Color skin, bool villain)
        {
            Color ink = new Color(0.1f, 0.06f, 0.12f);
            foreach (var ex in new[] { 0.36f, 0.64f })
            {
                var d = new Vector2((u - ex) / 0.07f, (v - 0.55f) / 0.09f).magnitude;
                if (d < 1f)
                {
                    var pupil = new Vector2((u - ex) / 0.035f, (v - 0.54f) / 0.045f).magnitude < 1f;
                    return pupil ? ink : (villain ? new Color(1f, 0.92f, 0.3f) : Color.white);
                }
                // Brows: angry for villains.
                var slope = villain ? (ex < 0.5f ? -0.6f : 0.6f) * (u - ex) : 0f;
                if (Mathf.Abs(v - (0.67f + slope)) < 0.018f && Mathf.Abs(u - ex) < 0.08f) return ink;
            }
            // Mouth.
            var mouthCurve = villain ? 0.3f - 2.2f * (u - 0.5f) * (u - 0.5f) : 0.27f + 2.4f * (u - 0.5f) * (u - 0.5f);
            if (Mathf.Abs(u - 0.5f) < 0.12f && Mathf.Abs(v - mouthCurve) < 0.016f) return ink;
            return skin;
        }

        /// UV sphere whose front (+Z) half maps onto the face side of the atlas.
        public static Mesh HeadMesh
        {
            get
            {
                if (_headMesh != null) return _headMesh;
                _headMesh = BuildSphere(28, 20, (n) =>
                {
                    if (n.z > -0.2f)
                    {
                        // Character's right (+X) shows on the photo's left.
                        return new Vector2(0.25f - n.x * 0.25f * 0.98f, 0.5f + n.y * 0.5f * 0.98f);
                    }
                    return new Vector2(0.75f + n.x * 0.2f, 0.5f + n.y * 0.45f);
                });
                _headMesh.name = "FaceHead";
                return _headMesh;
            }
        }

        /// Hair cap covering the top and back of the head.
        public static Mesh HairMesh
        {
            get
            {
                if (_hairMesh != null) return _hairMesh;
                _hairMesh = BuildSphere(20, 14, n => new Vector2(0.75f, 0.5f), keep: n => n.y > 0.15f || n.z < -0.15f);
                _hairMesh.name = "HairCap";
                return _hairMesh;
            }
        }

        static Mesh BuildSphere(int lon, int lat, Func<Vector3, Vector2> uv, Func<Vector3, bool> keep = null)
        {
            var verts = new List<Vector3>();
            var uvs = new List<Vector2>();
            var normals = new List<Vector3>();
            for (int y = 0; y <= lat; y++)
            {
                var theta = Mathf.PI * y / lat;
                for (int x = 0; x <= lon; x++)
                {
                    var phi = 2f * Mathf.PI * x / lon;
                    var n = new Vector3(Mathf.Sin(theta) * Mathf.Sin(phi), Mathf.Cos(theta), Mathf.Sin(theta) * Mathf.Cos(phi));
                    verts.Add(n * 0.5f);
                    normals.Add(n);
                    uvs.Add(uv(n));
                }
            }
            var tris = new List<int>();
            for (int y = 0; y < lat; y++)
                for (int x = 0; x < lon; x++)
                {
                    int a = y * (lon + 1) + x, b = a + lon + 1;
                    if (keep != null && !(keep(normals[a]) && keep(normals[b]) && keep(normals[a + 1]))) continue;
                    // Clockwise when seen from outside (Unity's front face).
                    tris.Add(a); tris.Add(b); tris.Add(a + 1);
                    tris.Add(a + 1); tris.Add(b); tris.Add(b + 1);
                }
            var mesh = new Mesh();
            mesh.SetVertices(verts);
            mesh.SetNormals(normals);
            mesh.SetUVs(0, uvs);
            mesh.SetTriangles(tris, 0);
            mesh.RecalculateBounds();
            return mesh;
        }
    }
}
