using System;
using System.Collections;
using System.Collections.Generic;
using Unity.Netcode;
using UnityEngine;

namespace PixelPunch3D
{
    public enum MatchPhase : byte { Loading = 0, Playing = 1, Victory = 2, Defeat = 3 }

    /// <summary>
    /// The one synced object that owns the match: map seed, villain roster
    /// (including face photos), the shrinking safe zone and win/lose state.
    /// The server decides; every peer generates the same world from the seed.
    /// </summary>
    public class MatchState : NetworkBehaviour
    {
        public static MatchState Instance { get; private set; }

        public readonly NetworkVariable<int> Seed = new();
        public readonly NetworkVariable<float> MapSize = new(1600f);
        public readonly NetworkVariable<MatchPhase> Phase = new(MatchPhase.Loading);
        public readonly NetworkVariable<int> VillainsAlive = new();
        public readonly NetworkVariable<int> PlayersAlive = new();
        public readonly NetworkVariable<float> MatchTime = new();

        public readonly NetworkVariable<Vector2> ZoneCenter = new();
        public readonly NetworkVariable<float> ZoneRadius = new(10000f);
        public readonly NetworkVariable<Vector2> ZoneNextCenter = new();
        public readonly NetworkVariable<float> ZoneNextRadius = new(10000f);
        public readonly NetworkVariable<float> ZoneTimer = new();
        public readonly NetworkVariable<bool> ZoneShrinking = new();
        public readonly NetworkVariable<int> ZoneStage = new();

        /// Villain roster; on clients it arrives by RPC after spawning.
        public VillainSpec[] Roster { get; private set; } = Array.Empty<VillainSpec>();
        public bool WorldReady { get; private set; }

        MatchConfig _config;
        System.Random _rng;
        readonly Dictionary<int, byte[][]> _faceChunks = new();
        Vector2 _shrinkFromCenter;
        float _shrinkFromRadius;
        bool _reported;

        struct ZoneStageDef
        {
            public float Wait, Shrink, RadiusFraction, Dps;
            public ZoneStageDef(float wait, float shrink, float radiusFraction, float dps)
            {
                Wait = wait; Shrink = shrink; RadiusFraction = radiusFraction; Dps = dps;
            }
        }

        static readonly ZoneStageDef[] Stages =
        {
            new(90, 60, 0.62f, 1f),
            new(60, 45, 0.38f, 2f),
            new(45, 40, 0.2f, 4f),
            new(40, 30, 0.09f, 7f),
            new(30, 25, 0.0f, 12f),
        };

        public float ZoneDps => Stages[Mathf.Clamp(ZoneStage.Value, 0, Stages.Length - 1)].Dps;

        /// Called on the server before Spawn().
        public void ServerConfigure(MatchConfig config)
        {
            _config = config;
            Seed.Value = config.seed != 0 ? config.seed : UnityEngine.Random.Range(1, int.MaxValue);
            MapSize.Value = config.mapSize;
            Roster = config.villains.Length > 0 ? config.villains : MatchConfig.EditorDefault().villains;
        }

        public override void OnNetworkSpawn()
        {
            Instance = this;
            Phase.OnValueChanged += OnPhaseChanged;
            if (IsServer)
            {
                for (int i = 0; i < Roster.Length; i++)
                    FaceLibrary.Register(i, Roster[i].face);
                NetworkManager.OnClientConnectedCallback += SendRosterTo;
                foreach (var id in NetworkManager.ConnectedClientsIds)
                    if (id != NetworkManager.ServerClientId) SendRosterTo(id);
            }
            StartCoroutine(GenerateWorld());
        }

        public override void OnNetworkDespawn()
        {
            Phase.OnValueChanged -= OnPhaseChanged;
            if (IsServer && NetworkManager != null)
                NetworkManager.OnClientConnectedCallback -= SendRosterTo;
            if (Instance == this) Instance = null;
        }

        IEnumerator GenerateWorld()
        {
            LoadingScreen.Show("Building the map...");
            yield return null; // let the loading text render first
            WorldGenerator.Generate(Seed.Value, MapSize.Value);
            WorldReady = true;
            AudioBank.PlayMusic("battle_theme_1", 0.3f);

            if (IsServer)
            {
                _rng = new System.Random(Seed.Value ^ 0x5bd1e995);
                SpawnLoot();
                yield return null;
                SpawnVillains();
                var size = MapSize.Value;
                ZoneCenter.Value = new Vector2(size / 2f, size / 2f);
                ZoneRadius.Value = size * 0.72f;
                ZoneStage.Value = 0;
                ZoneTimer.Value = Stages[0].Wait;
                PickNextZone();
                Phase.Value = MatchPhase.Playing;
            }
            LoadingScreen.Hide();
        }

        // ------------------------------------------------------------------
        // Roster sync (server → clients). Faces are sent in small chunks so
        // they fit in a single transport packet.

        [Serializable]
        class RosterWrapper { public VillainSpec[] items; }

        void SendRosterTo(ulong clientId)
        {
            if (clientId == NetworkManager.ServerClientId) return;
            var target = RpcTarget.Single(clientId, RpcTargetUse.Temp);
            var stripped = new VillainSpec[Roster.Length];
            for (int i = 0; i < Roster.Length; i++)
            {
                var copy = JsonUtility.FromJson<VillainSpec>(JsonUtility.ToJson(Roster[i]));
                copy.face = "";
                stripped[i] = copy;
            }
            RosterRpc(JsonUtility.ToJson(new RosterWrapper { items = stripped }), target);

            const int chunkSize = 3000;
            for (int i = 0; i < Roster.Length; i++)
            {
                if (string.IsNullOrEmpty(Roster[i].face)) continue;
                byte[] bytes;
                try { bytes = Convert.FromBase64String(Roster[i].face); }
                catch { continue; }
                int total = (bytes.Length + chunkSize - 1) / chunkSize;
                for (int c = 0; c < total; c++)
                {
                    int len = Mathf.Min(chunkSize, bytes.Length - c * chunkSize);
                    var part = new byte[len];
                    Buffer.BlockCopy(bytes, c * chunkSize, part, 0, len);
                    FaceChunkRpc(i, c, total, part, RpcTarget.Single(clientId, RpcTargetUse.Temp));
                }
            }
        }

        [Rpc(SendTo.SpecifiedInParams)]
        void RosterRpc(string json, RpcParams rpcParams = default)
        {
            var wrapper = JsonUtility.FromJson<RosterWrapper>(json);
            Roster = wrapper?.items ?? Array.Empty<VillainSpec>();
            VillainNet.RefreshAllAppearances();
        }

        [Rpc(SendTo.SpecifiedInParams)]
        void FaceChunkRpc(int index, int chunk, int total, byte[] data, RpcParams rpcParams = default)
        {
            if (!_faceChunks.TryGetValue(index, out var parts) || parts.Length != total)
            {
                parts = new byte[total][];
                _faceChunks[index] = parts;
            }
            parts[chunk] = data;
            foreach (var p in parts) if (p == null) return;

            var length = 0;
            foreach (var p in parts) length += p.Length;
            var all = new byte[length];
            var offset = 0;
            foreach (var p in parts)
            {
                Buffer.BlockCopy(p, 0, all, offset, p.Length);
                offset += p.Length;
            }
            _faceChunks.Remove(index);
            FaceLibrary.Register(index, all);
            VillainNet.RefreshAllAppearances();
        }

        public VillainSpec SpecAt(int index) =>
            index >= 0 && index < Roster.Length ? Roster[index] : null;

        // ------------------------------------------------------------------
        // Server spawning

        void SpawnVillains()
        {
            var count = _config != null ? _config.villainCount : 10;
            var points = WorldGenerator.Instance.RandomLandPoints(count, _rng, minSpacing: 60f);
            for (int i = 0; i < points.Count; i++)
            {
                var go = Instantiate(NetworkRuntime.VillainPrefab, points[i] + Vector3.up * 1.2f, Quaternion.Euler(0, _rng.Next(0, 360), 0));
                var villain = go.GetComponent<VillainNet>();
                villain.ServerSetup(i % Roster.Length, Roster[i % Roster.Length], _rng.Next());
                go.GetComponent<NetworkObject>().Spawn(true);
            }
        }

        void SpawnLoot()
        {
            foreach (var point in WorldGenerator.Instance.LootPoints)
            {
                var type = LootTable.Roll(_rng);
                var go = Instantiate(NetworkRuntime.LootPrefab, point, Quaternion.identity);
                go.GetComponent<LootItem>().ServerSetup(type);
                go.GetComponent<NetworkObject>().Spawn(true);
            }
        }

        // ------------------------------------------------------------------
        // Server match loop

        void Update()
        {
            if (!IsServer || Phase.Value != MatchPhase.Playing) return;
            var dt = Time.deltaTime;
            MatchTime.Value += dt;
            UpdateZone(dt);
            DamageOutsideZone(dt);

            int heroes = 0, villains = 0;
            foreach (var c in Combatant.All)
            {
                if (c.IsDead.Value) continue;
                if (c.Team.Value == Combatant.TeamHeroes) heroes++; else villains++;
            }
            PlayersAlive.Value = heroes;
            VillainsAlive.Value = villains;

            // Give late joiners a moment before deciding defeat.
            if (villains == 0) Phase.Value = MatchPhase.Victory;
            else if (heroes == 0 && MatchTime.Value > 5f) Phase.Value = MatchPhase.Defeat;
        }

        void UpdateZone(float dt)
        {
            ZoneTimer.Value -= dt;
            var stage = Stages[Mathf.Clamp(ZoneStage.Value, 0, Stages.Length - 1)];
            if (!ZoneShrinking.Value)
            {
                if (ZoneTimer.Value <= 0 && ZoneStage.Value < Stages.Length)
                {
                    ZoneShrinking.Value = true;
                    ZoneTimer.Value = stage.Shrink;
                    _shrinkFromCenter = ZoneCenter.Value;
                    _shrinkFromRadius = ZoneRadius.Value;
                    ZoneAnnouncementRpc("The safe zone is shrinking!");
                }
                return;
            }

            var t = 1f - Mathf.Clamp01(ZoneTimer.Value / stage.Shrink);
            ZoneCenter.Value = Vector2.Lerp(_shrinkFromCenter, ZoneNextCenter.Value, t);
            ZoneRadius.Value = Mathf.Lerp(_shrinkFromRadius, ZoneNextRadius.Value, t);
            if (ZoneTimer.Value <= 0)
            {
                ZoneShrinking.Value = false;
                ZoneStage.Value = Mathf.Min(ZoneStage.Value + 1, Stages.Length);
                if (ZoneStage.Value < Stages.Length)
                {
                    ZoneTimer.Value = Stages[ZoneStage.Value].Wait;
                    PickNextZone();
                }
                else
                {
                    ZoneTimer.Value = float.PositiveInfinity;
                }
            }
        }

        void PickNextZone()
        {
            var stage = Stages[Mathf.Clamp(ZoneStage.Value, 0, Stages.Length - 1)];
            var nextRadius = MapSize.Value * stage.RadiusFraction;
            var maxOffset = Mathf.Max(0, ZoneRadius.Value - nextRadius);
            var angle = (float)_rng.NextDouble() * Mathf.PI * 2f;
            var dist = (float)_rng.NextDouble() * maxOffset * 0.8f;
            var center = ZoneCenter.Value + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * dist;
            // Keep the final circle on land, away from the map border.
            var margin = Mathf.Max(nextRadius, MapSize.Value * 0.08f);
            center.x = Mathf.Clamp(center.x, margin, MapSize.Value - margin);
            center.y = Mathf.Clamp(center.y, margin, MapSize.Value - margin);
            ZoneNextCenter.Value = center;
            ZoneNextRadius.Value = nextRadius;
        }

        void DamageOutsideZone(float dt)
        {
            foreach (var c in Combatant.All)
            {
                if (c.IsDead.Value) continue;
                if (!IsInsideZone(c.transform.position))
                    c.ServerApplyDamage(ZoneDps * dt, null, c.transform.position, DamageKind.Zone);
            }
        }

        public bool IsInsideZone(Vector3 position)
        {
            var p = new Vector2(position.x, position.z);
            return (p - ZoneCenter.Value).sqrMagnitude <= ZoneRadius.Value * ZoneRadius.Value;
        }

        [Rpc(SendTo.Everyone)]
        void ZoneAnnouncementRpc(string text)
        {
            HUD.Instance?.ShowMessage(text, 3f);
            AudioBank.Play2D("health_low", 0.6f);
        }

        // ------------------------------------------------------------------
        // End of match (all peers)

        void OnPhaseChanged(MatchPhase previous, MatchPhase current)
        {
            if (current == MatchPhase.Playing)
            {
                HUD.Instance?.ShowMessage("Hunt down the villains! Stay inside the safe zone.", 4f);
                return;
            }
            if ((current != MatchPhase.Victory && current != MatchPhase.Defeat) || _reported) return;
            _reported = true;
            var victory = current == MatchPhase.Victory;
            var me = PlayerController.Local != null ? PlayerController.Local.Combatant : null;
            var kills = me != null ? me.Kills.Value : 0;
            var damage = me != null ? me.DamageDealt.Value : 0;
            var seconds = Mathf.RoundToInt(MatchTime.Value);
            AudioBank.StopMusic();
            AudioBank.Play2D(victory ? "victory_fanfare" : "defeat_sting", 0.9f);
            ResultsScreen.Show(victory, kills, damage, seconds);
            GameBridge.Send("match_over",
                $"{{\"victory\":{(victory ? "true" : "false")},\"kills\":{kills},\"damage\":{damage},\"seconds\":{seconds}," +
                $"\"villainsDefeated\":\"{GameBridge.Escape(string.Join(",", VillainNet.DefeatedIds()))}\"}}");
        }
    }
}
