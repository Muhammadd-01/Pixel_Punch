using System.Collections.Generic;
using UnityEngine;

namespace PixelPunch3D
{
    /// <summary>
    /// Builds the battle royale map from a seed: rolling terrain with a
    /// mountain border, flattened towns of enterable buildings, trees, rocks,
    /// cover crates and loot spots. Every peer builds the identical map.
    /// </summary>
    public class WorldGenerator : MonoBehaviour
    {
        public static WorldGenerator Instance { get; private set; }

        public Terrain Terrain { get; private set; }
        public float Size { get; private set; }
        public Texture2D MinimapTexture { get; private set; }
        public readonly List<Vector3> LootPoints = new();
        public readonly List<Vector3> TownCenters = new();
        public readonly List<string> TownNames = new();
        readonly List<Bounds> _blocked = new();

        const float TerrainHeight = 90f;
        const int HeightRes = 513;
        System.Random _rng;
        Vector2 _noiseOffset;
        Transform _static;
        Transform _dynamic;

        static readonly string[] Names =
        {
            "Pixel Port", "Deadline Docks", "Bugville", "Firewall Farms", "Lag Lagoon",
            "Server Springs", "Neon Heights", "Chaos Corner", "Sprint Station", "Rooftop Ridge",
            "Merge Meadows", "Patch Point",
        };

        public static void Generate(int seed, float size)
        {
            Clear();
            var go = new GameObject("World");
            Instance = go.AddComponent<WorldGenerator>();
            Instance.Build(seed, size);
        }

        public static void Clear()
        {
            if (Instance == null) return;
            Destroy(Instance.gameObject);
            Instance = null;
        }

        void Build(int seed, float size)
        {
            Size = size;
            _rng = new System.Random(seed);
            _noiseOffset = new Vector2(_rng.Next(0, 10000), _rng.Next(0, 10000));
            _static = new GameObject("Static").transform;
            _static.SetParent(transform);
            _dynamic = new GameObject("Dynamic").transform;
            _dynamic.SetParent(transform);

            PickTowns();
            BuildTerrain();
            BuildTowns();
            ScatterNature();
            BuildBoundary();
            SetupLighting();
            BuildMinimap();

            Physics.SyncTransforms();
            StaticBatchingUtility.Combine(_static.gameObject);
        }

        // ------------------------------------------------------------------
        // Terrain

        void PickTowns()
        {
            var count = Mathf.Clamp(Mathf.RoundToInt(Size / 300f) + 3, 4, 12);
            var tries = 0;
            while (TownCenters.Count < count && tries++ < 500)
            {
                var p = new Vector3(Rand(0.16f, 0.84f) * Size, 0, Rand(0.16f, 0.84f) * Size);
                var ok = true;
                foreach (var t in TownCenters)
                    if (Vector3.Distance(t, p) < Size * 0.17f) { ok = false; break; }
                if (!ok) continue;
                TownCenters.Add(p);
                TownNames.Add(Names[TownNames.Count % Names.Length]);
            }
        }

        float BaseHeight(float x, float z)
        {
            float u = x / Size, v = z / Size;
            float sum = 0, amp = 1, freq = Size / 900f, norm = 0;
            for (int i = 0; i < 5; i++)
            {
                sum += Mathf.PerlinNoise(_noiseOffset.x + u * freq * 4f, _noiseOffset.y + v * freq * 4f) * amp;
                norm += amp;
                amp *= 0.5f;
                freq *= 2.1f;
            }
            var h = sum / norm * 0.32f;
            // Mountains around the edge keep everyone on the island.
            var edge = Mathf.Max(Mathf.Abs(u - 0.5f), Mathf.Abs(v - 0.5f)) * 2f;
            var border = Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(0.78f, 1f, edge));
            var ridge = Mathf.PerlinNoise(_noiseOffset.x + u * 30f, _noiseOffset.y + v * 30f);
            return h + border * (0.45f + ridge * 0.35f);
        }

        float FinalHeight(float x, float z)
        {
            var h = BaseHeight(x, z);
            foreach (var town in TownCenters)
            {
                var d = Vector2.Distance(new Vector2(x, z), new Vector2(town.x, town.z));
                var flat = 1f - Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(70f, 120f, d));
                if (flat > 0) h = Mathf.Lerp(h, BaseHeight(town.x, town.z), flat);
            }
            return h;
        }

        void BuildTerrain()
        {
            var data = new TerrainData
            {
                heightmapResolution = HeightRes,
                alphamapResolution = 256,
                baseMapResolution = 256,
            };
            data.size = new Vector3(Size, TerrainHeight, Size);

            var heights = new float[HeightRes, HeightRes];
            for (int z = 0; z < HeightRes; z++)
                for (int x = 0; x < HeightRes; x++)
                {
                    var wx = x / (float)(HeightRes - 1) * Size;
                    var wz = z / (float)(HeightRes - 1) * Size;
                    heights[z, x] = Mathf.Clamp01(FinalHeight(wx, wz));
                }
            data.SetHeights(0, 0, heights);

            data.terrainLayers = new[]
            {
                new TerrainLayer { diffuseTexture = ProcTex.Grass, tileSize = new Vector2(6, 6) },
                new TerrainLayer { diffuseTexture = ProcTex.Dirt, tileSize = new Vector2(5, 5) },
                new TerrainLayer { diffuseTexture = ProcTex.Rock, tileSize = new Vector2(8, 8) },
            };

            var res = data.alphamapResolution;
            var alpha = new float[res, res, 3];
            for (int z = 0; z < res; z++)
                for (int x = 0; x < res; x++)
                {
                    float u = x / (float)(res - 1), v = z / (float)(res - 1);
                    var steep = data.GetSteepness(u, v);
                    var h = data.GetInterpolatedHeight(u, v) / TerrainHeight;
                    var rock = Mathf.Clamp01(Mathf.InverseLerp(22f, 38f, steep) + Mathf.InverseLerp(0.55f, 0.75f, h));
                    var dirt = 0f;
                    foreach (var town in TownCenters)
                    {
                        var d = Vector2.Distance(new Vector2(u * Size, v * Size), new Vector2(town.x, town.z));
                        dirt = Mathf.Max(dirt, 1f - Mathf.InverseLerp(55f, 85f, d));
                    }
                    dirt = Mathf.Max(dirt, Mathf.PerlinNoise(u * 40f + _noiseOffset.x, v * 40f) > 0.72f ? 0.6f : 0f);
                    dirt *= 1f - rock;
                    var grass = Mathf.Max(0, 1f - rock - dirt);
                    alpha[z, x, 0] = grass;
                    alpha[z, x, 1] = dirt;
                    alpha[z, x, 2] = rock;
                }
            data.SetAlphamaps(0, 0, alpha);

            var go = Terrain.CreateTerrainGameObject(data);
            go.name = "Terrain";
            go.transform.SetParent(transform);
            Terrain = go.GetComponent<Terrain>();
            Terrain.heightmapPixelError = 6;
            Terrain.basemapDistance = 250;
            Terrain.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            var terrainShader = Shader.Find("Nature/Terrain/Standard");
            if (terrainShader != null && Terrain.materialTemplate == null)
                Terrain.materialTemplate = new Material(terrainShader);

            for (int i = 0; i < TownCenters.Count; i++)
            {
                var t = TownCenters[i];
                TownCenters[i] = new Vector3(t.x, HeightAt(t.x, t.z), t.z);
            }
        }

        public float HeightAt(float x, float z) =>
            Terrain != null ? Terrain.SampleHeight(new Vector3(x, 0, z)) + Terrain.transform.position.y : 0f;

        public Vector3 GroundPoint(float x, float z) => new Vector3(x, HeightAt(x, z), z);

        float SlopeAt(float x, float z) =>
            Terrain != null ? Terrain.terrainData.GetSteepness(x / Size, z / Size) : 0f;

        // ------------------------------------------------------------------
        // Towns and buildings

        void BuildTowns()
        {
            foreach (var town in TownCenters)
            {
                var houseCount = _rng.Next(6, 11);
                var placed = new List<Rect>();
                var tries = 0;
                while (placed.Count < houseCount && tries++ < 120)
                {
                    var w = Rand(8f, 14f);
                    var d = Rand(8f, 12f);
                    var angle = Rand(0f, Mathf.PI * 2f);
                    var radius = Rand(12f, 52f);
                    var cx = town.x + Mathf.Cos(angle) * radius;
                    var cz = town.z + Mathf.Sin(angle) * radius;
                    var rect = new Rect(cx - w / 2 - 3, cz - d / 2 - 3, w + 6, d + 6);
                    var overlaps = false;
                    foreach (var r in placed) if (r.Overlaps(rect)) { overlaps = true; break; }
                    if (overlaps) continue;
                    placed.Add(rect);
                    BuildHouse(new Vector3(cx, town.y, cz), w, d, _rng.NextDouble() < 0.35 ? 2 : 1);
                }

                // Cover crates and a couple of outdoor loot spots in the square.
                for (int i = 0; i < 6; i++)
                {
                    var p = town + new Vector3(Rand(-10f, 10f), 0, Rand(-10f, 10f));
                    p.y = HeightAt(p.x, p.z);
                    var size = Rand(1f, 1.6f);
                    Box(_static, p + Vector3.up * size / 2, new Vector3(size, size, size),
                        Mats.Textured("wood", ProcTex.Wood, Color.white, Vector2.one), Quaternion.Euler(0, Rand(0, 90), 0));
                    if (i % 2 == 0) LootPoints.Add(p + new Vector3(1.6f, 0.35f, 0));
                }
            }
        }

        struct Opening
        {
            public float From, To, Sill, Top;
            public Opening(float from, float to, float sill, float top) { From = from; To = to; Sill = sill; Top = top; }
        }

        void BuildHouse(Vector3 center, float width, float depth, int floors)
        {
            const float floorHeight = 3.2f;
            const float wall = 0.25f;
            var house = new GameObject("House").transform;
            house.SetParent(_static);
            house.position = center;
            var yaw = _rng.Next(0, 4) * 90f;
            house.rotation = Quaternion.Euler(0, yaw, 0);

            var useBrick = _rng.NextDouble() < 0.5;
            var wallMat = useBrick
                ? Mats.Textured("brick", ProcTex.Brick, Color.white, new Vector2(2, 1))
                : Mats.Textured("plaster", ProcTex.Plaster, new Color(Rand(0.8f, 1f), Rand(0.8f, 1f), Rand(0.75f, 0.95f)), new Vector2(2, 1));
            var floorMat = Mats.Textured("wood", ProcTex.Wood, Color.white, new Vector2(3, 3));
            var roofMat = Mats.Textured("roof", ProcTex.Roof, Color.white, new Vector2(3, 3));

            // Foundation sinks into the ground so slopes never show a gap.
            LocalBox(house, new Vector3(0, -0.6f, 0), new Vector3(width + 0.4f, 1.4f, depth + 0.4f),
                Mats.Textured("concrete", ProcTex.Concrete, Color.white, new Vector2(3, 3)));

            var doorSide = _rng.Next(0, 4);
            for (int f = 0; f < floors; f++)
            {
                var baseY = 0.1f + f * floorHeight;
                for (int side = 0; side < 4; side++)
                {
                    var along = side % 2 == 0 ? width : depth;
                    var openings = new List<Opening>();
                    if (f == 0 && side == doorSide)
                        openings.Add(new Opening(along / 2 - 0.8f, along / 2 + 0.8f, 0f, 2.4f));
                    // Windows every ~4 m.
                    for (var wpos = 1.8f; wpos < along - 2.4f; wpos += Rand(3.2f, 4.6f))
                    {
                        if (openings.Count > 0 && Mathf.Abs(wpos + 0.6f - along / 2) < 1.8f) continue;
                        openings.Add(new Opening(wpos, wpos + 1.2f, 1.0f, 2.1f));
                    }
                    BuildWall(house, side, width, depth, baseY, floorHeight, wall, openings, wallMat);
                }

                // Floor slab for upper storeys, with a stairwell hole.
                if (f > 0)
                {
                    var holeW = 1.6f;
                    LocalBox(house, new Vector3(-holeW / 2f, baseY - 0.1f, 0), new Vector3(width - holeW, 0.2f, depth), floorMat);
                    LocalBox(house, new Vector3(width / 2f - holeW / 2f, baseY - 0.1f, -1.5f), new Vector3(holeW, 0.2f, depth - 3f), floorMat);
                    // Ramp (works as stairs for a CharacterController).
                    var ramp = LocalBox(house, new Vector3(width / 2f - holeW / 2f - 0.05f, baseY - floorHeight / 2f, depth / 2f - 2.1f),
                        new Vector3(holeW - 0.1f, 0.2f, 5.2f), floorMat);
                    ramp.localRotation = Quaternion.Euler(-36f, 0, 0);
                }
                else
                {
                    LocalBox(house, new Vector3(0, baseY - 0.05f, 0), new Vector3(width, 0.1f, depth), floorMat);
                }

                // Loot inside on every floor.
                var loot = _rng.Next(1, 4);
                for (int i = 0; i < loot; i++)
                {
                    var local = new Vector3(Rand(-width / 2 + 1.2f, width / 2 - 2.2f), baseY + 0.35f, Rand(-depth / 2 + 1.2f, depth / 2 - 1.2f));
                    LootPoints.Add(house.TransformPoint(local));
                }
            }

            // Flat roof with a little parapet.
            var roofY = 0.1f + floors * floorHeight;
            LocalBox(house, new Vector3(0, roofY, 0), new Vector3(width + 0.5f, 0.3f, depth + 0.5f), roofMat);
            LocalBox(house, new Vector3(0, roofY + 0.45f, depth / 2f + 0.15f), new Vector3(width + 0.5f, 0.6f, 0.2f), wallMat);
            LocalBox(house, new Vector3(0, roofY + 0.45f, -depth / 2f - 0.15f), new Vector3(width + 0.5f, 0.6f, 0.2f), wallMat);

            var b = new Bounds(center, new Vector3(Mathf.Max(width, depth) + 2, 20, Mathf.Max(width, depth) + 2));
            _blocked.Add(b);
        }

        void BuildWall(Transform house, int side, float width, float depth, float baseY, float height, float thickness,
            List<Opening> openings, Material mat)
        {
            // Wall runs along local X for sides 0/2 (front/back) and local Z for 1/3.
            var length = side % 2 == 0 ? width : depth;
            Vector3 Origin(float along) => side switch
            {
                0 => new Vector3(-width / 2 + along, 0, depth / 2),
                1 => new Vector3(width / 2, 0, depth / 2 - along),
                2 => new Vector3(width / 2 - along, 0, -depth / 2),
                _ => new Vector3(-width / 2, 0, -depth / 2 + along),
            };
            var rot = Quaternion.Euler(0, side * 90f, 0);
            void Piece(float from, float to, float y0, float y1)
            {
                if (to - from < 0.05f || y1 - y0 < 0.05f) return;
                var mid = (from + to) / 2f;
                var pos = Origin(mid);
                pos.y = baseY + (y0 + y1) / 2f;
                var t = LocalBox(house, pos, new Vector3(to - from + (side % 2 == 1 ? 0 : thickness), y1 - y0, thickness), mat);
                t.localRotation = rot;
            }

            openings.Sort((a, b) => a.From.CompareTo(b.From));
            var cursor = 0f;
            foreach (var o in openings)
            {
                Piece(cursor, o.From, 0, height);
                Piece(o.From, o.To, 0, o.Sill);
                Piece(o.From, o.To, o.Top, height);
                cursor = o.To;
            }
            Piece(cursor, length, 0, height);
        }

        Transform LocalBox(Transform parent, Vector3 localPos, Vector3 size, Material mat, Vector3 extraOffset = default)
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Cube);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos + extraOffset;
            go.transform.localScale = size;
            go.GetComponent<Renderer>().sharedMaterial = mat;
            go.isStatic = true;
            return go.transform;
        }

        Transform Box(Transform parent, Vector3 pos, Vector3 size, Material mat, Quaternion rot)
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Cube);
            go.transform.SetParent(parent, false);
            go.transform.SetPositionAndRotation(pos, rot);
            go.transform.localScale = size;
            go.GetComponent<Renderer>().sharedMaterial = mat;
            go.isStatic = true;
            return go.transform;
        }

        // ------------------------------------------------------------------
        // Nature

        bool NearTown(Vector3 p, float extra)
        {
            foreach (var t in TownCenters)
                if (Vector2.Distance(new Vector2(p.x, p.z), new Vector2(t.x, t.z)) < 70f + extra) return true;
            return false;
        }

        void ScatterNature()
        {
            var trunkMat = Mats.Textured("bark", ProcTex.Wood, new Color(0.55f, 0.42f, 0.3f), new Vector2(1, 3));
            var leafMats = new[]
            {
                Mats.Color(new Color(0.18f, 0.45f, 0.18f)),
                Mats.Color(new Color(0.24f, 0.52f, 0.2f)),
                Mats.Color(new Color(0.14f, 0.38f, 0.22f)),
            };
            var rockMat = Mats.Textured("rock", ProcTex.Rock, Color.white, Vector2.one);

            var trees = Mathf.RoundToInt(Size * Size / 6000f);
            for (int i = 0, tries = 0; i < trees && tries < trees * 4; tries++)
            {
                var x = Rand(0.06f, 0.94f) * Size;
                var z = Rand(0.06f, 0.94f) * Size;
                if (SlopeAt(x, z) > 28f) continue;
                var p = GroundPoint(x, z);
                if (NearTown(p, 0)) continue;
                i++;
                var tree = new GameObject("Tree").transform;
                tree.SetParent(_static);
                tree.position = p;
                var h = Rand(4f, 7f);
                var trunk = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
                Object.Destroy(trunk.GetComponent<Collider>());
                trunk.transform.SetParent(tree, false);
                trunk.transform.localPosition = new Vector3(0, h / 2f, 0);
                trunk.transform.localScale = new Vector3(0.35f, h / 2f, 0.35f);
                trunk.GetComponent<Renderer>().sharedMaterial = trunkMat;
                var col = tree.gameObject.AddComponent<CapsuleCollider>();
                col.center = new Vector3(0, h / 2f, 0);
                col.height = h;
                col.radius = 0.3f;

                var leaves = leafMats[_rng.Next(leafMats.Length)];
                var crown = _rng.NextDouble() < 0.5 ? 2 : 3;
                for (int c = 0; c < crown; c++)
                {
                    var s = GameObject.CreatePrimitive(PrimitiveType.Sphere);
                    Object.Destroy(s.GetComponent<Collider>());
                    s.transform.SetParent(tree, false);
                    var r = Rand(2.2f, 3.4f) * (1f - c * 0.22f);
                    s.transform.localPosition = new Vector3(Rand(-0.4f, 0.4f), h + c * 1.4f, Rand(-0.4f, 0.4f));
                    s.transform.localScale = new Vector3(r, r * 0.9f, r);
                    var rend = s.GetComponent<Renderer>();
                    rend.sharedMaterial = leaves;
                    rend.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                }
                foreach (var t in tree.GetComponentsInChildren<Transform>()) t.gameObject.isStatic = true;
            }

            var rocks = Mathf.RoundToInt(Size * Size / 22000f);
            for (int i = 0; i < rocks; i++)
            {
                var x = Rand(0.05f, 0.95f) * Size;
                var z = Rand(0.05f, 0.95f) * Size;
                var p = GroundPoint(x, z);
                if (NearTown(p, -20)) continue;
                var s = Rand(1f, 3.2f);
                var rock = GameObject.CreatePrimitive(PrimitiveType.Sphere);
                rock.transform.SetParent(_static);
                rock.transform.position = p + Vector3.up * s * 0.2f;
                rock.transform.localScale = new Vector3(s * Rand(1f, 1.6f), s * Rand(0.6f, 1f), s * Rand(1f, 1.5f));
                rock.transform.rotation = Quaternion.Euler(Rand(-10, 10), Rand(0, 360), Rand(-10, 10));
                rock.GetComponent<Renderer>().sharedMaterial = rockMat;
                rock.isStatic = true;
            }

            // A few loot spots out in the wild for explorers.
            for (int i = 0; i < TownCenters.Count * 3; i++)
            {
                var x = Rand(0.15f, 0.85f) * Size;
                var z = Rand(0.15f, 0.85f) * Size;
                if (SlopeAt(x, z) > 20f) continue;
                LootPoints.Add(GroundPoint(x, z) + Vector3.up * 0.35f);
            }
        }

        void BuildBoundary()
        {
            void Wall(Vector3 center, Vector3 size)
            {
                var go = new GameObject("Boundary");
                go.transform.SetParent(transform);
                go.transform.position = center;
                go.AddComponent<BoxCollider>().size = size;
            }
            var h = 400f;
            Wall(new Vector3(Size / 2, h / 2, -1), new Vector3(Size, h, 2));
            Wall(new Vector3(Size / 2, h / 2, Size + 1), new Vector3(Size, h, 2));
            Wall(new Vector3(-1, h / 2, Size / 2), new Vector3(2, h, Size));
            Wall(new Vector3(Size + 1, h / 2, Size / 2), new Vector3(2, h, Size));
        }

        void SetupLighting()
        {
            if (FindAnyObjectByType<Light>() == null)
            {
                var sun = new GameObject("Sun").AddComponent<Light>();
                sun.transform.SetParent(transform);
                sun.type = LightType.Directional;
                sun.intensity = 1.15f;
                sun.color = new Color(1f, 0.96f, 0.88f);
                sun.shadows = LightShadows.Soft;
                sun.transform.rotation = Quaternion.Euler(48f, -35f, 0);
                RenderSettings.sun = sun;
            }
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.62f, 0.72f, 0.86f);
            RenderSettings.ambientEquatorColor = new Color(0.52f, 0.56f, 0.5f);
            RenderSettings.ambientGroundColor = new Color(0.28f, 0.26f, 0.22f);
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.Linear;
            RenderSettings.fogColor = new Color(0.7f, 0.78f, 0.86f);
            RenderSettings.fogStartDistance = 160f;
            RenderSettings.fogEndDistance = 620f;
            QualitySettings.shadowDistance = 70f;
        }

        void BuildMinimap()
        {
            const int res = 256;
            MinimapTexture = new Texture2D(res, res, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            var pixels = new Color[res * res];
            for (int y = 0; y < res; y++)
                for (int x = 0; x < res; x++)
                {
                    var wx = x / (float)(res - 1) * Size;
                    var wz = y / (float)(res - 1) * Size;
                    var h = HeightAt(wx, wz) / TerrainHeight;
                    var slope = SlopeAt(wx, wz);
                    Color c = slope > 28f || h > 0.6f
                        ? Color.Lerp(new Color(0.45f, 0.43f, 0.4f), Color.white, Mathf.InverseLerp(0.6f, 0.9f, h))
                        : Color.Lerp(new Color(0.3f, 0.5f, 0.24f), new Color(0.5f, 0.6f, 0.3f), h * 2f);
                    pixels[y * res + x] = c;
                }
            foreach (var b in _blocked)
            {
                var px = Mathf.RoundToInt(b.center.x / Size * (res - 1));
                var py = Mathf.RoundToInt(b.center.z / Size * (res - 1));
                for (int dy = -2; dy <= 2; dy++)
                    for (int dx = -2; dx <= 2; dx++)
                    {
                        var ix = Mathf.Clamp(px + dx, 0, res - 1);
                        var iy = Mathf.Clamp(py + dy, 0, res - 1);
                        pixels[iy * res + ix] = new Color(0.55f, 0.32f, 0.25f);
                    }
            }
            MinimapTexture.SetPixels(pixels);
            MinimapTexture.Apply();
        }

        // ------------------------------------------------------------------
        // Queries used by spawning and AI

        public List<Vector3> RandomLandPoints(int count, System.Random rng, float minSpacing)
        {
            var result = new List<Vector3>();
            var tries = 0;
            while (result.Count < count && tries++ < count * 60)
            {
                var x = (float)(0.12 + rng.NextDouble() * 0.76) * Size;
                var z = (float)(0.12 + rng.NextDouble() * 0.76) * Size;
                if (SlopeAt(x, z) > 24f) continue;
                var p = GroundPoint(x, z);
                if (IsBlocked(p)) continue;
                var spaced = true;
                foreach (var r in result) if (Vector3.Distance(r, p) < minSpacing) { spaced = false; break; }
                if (spaced || tries > count * 40) result.Add(p);
            }
            return result;
        }

        public bool IsBlocked(Vector3 p)
        {
            foreach (var b in _blocked) if (b.Contains(new Vector3(p.x, b.center.y, p.z))) return true;
            return false;
        }

        /// Where a player's skydive starts: high above a random spot near the middle.
        public Vector3 DropPoint(ulong clientId)
        {
            var rng = new System.Random((int)clientId * 7919 + 17);
            var x = Size * (0.35f + (float)rng.NextDouble() * 0.3f);
            var z = Size * (0.35f + (float)rng.NextDouble() * 0.3f);
            return new Vector3(x, HeightAt(x, z) + 140f, z);
        }

        public string NearestTownName(Vector3 p)
        {
            var best = "Wilderness";
            var bestDist = 160f;
            for (int i = 0; i < TownCenters.Count; i++)
            {
                var d = Vector3.Distance(TownCenters[i], p);
                if (d < bestDist) { bestDist = d; best = TownNames[i]; }
            }
            return best;
        }

        public Transform DynamicRoot => _dynamic;

        float Rand(float min, float max) => min + (float)_rng.NextDouble() * (max - min);
    }
}
