using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace PixelPunch3D
{
    /// <summary>
    /// In-match HUD: health/armor, weapon + ammo, crosshair and hit markers,
    /// minimap with the safe zone, alive counters, kill feed and messages.
    /// </summary>
    public class HUD : MonoBehaviour
    {
        public static HUD Instance { get; private set; }

        Canvas _canvas;
        Image _healthFill, _armorFill, _vignette, _hitMarker;
        Text _healthText, _weaponText, _ammoText, _counts, _zoneText, _message, _pickup, _status;
        RectTransform _crosshair, _minimap, _playerMarker, _zoneRing, _nextZoneRing;
        readonly List<RectTransform> _mateMarkers = new();
        readonly List<(Text text, float time)> _feed = new();
        Transform _feedRoot;
        float _messageTime, _hitTime, _damageFlash;
        RawImage _mapImage;

        public static void Create()
        {
            if (Instance != null) return;
            var go = new GameObject("HUD");
            DontDestroyOnLoad(go);
            Instance = go.AddComponent<HUD>();
            Instance.Build();
            ZoneWall.Create();
        }

        public static void Teardown()
        {
            ZoneWall.Teardown();
            if (Instance == null) return;
            if (Instance._canvas != null) Destroy(Instance._canvas.gameObject);
            Destroy(Instance.gameObject);
            Instance = null;
        }

        void Build()
        {
            _canvas = UIFactory.Canvas("HUDCanvas", 5);
            var root = _canvas.transform;

            var vignette = UIFactory.Rect("Damage", root, Vector2.zero, Vector2.one);
            _vignette = UIFactory.Image(vignette, new Color(0.8f, 0, 0, 0));

            // Health + armor (top-left)
            var hp = UIFactory.Box("Health", root, new Vector2(0, 1), new Vector2(230, -60), new Vector2(380, 30));
            UIFactory.Image(hp, new Color(0, 0, 0, 0.5f));
            var fill = UIFactory.Rect("Fill", hp, Vector2.zero, Vector2.one, new Vector2(3, 3), new Vector2(-3, -3));
            _healthFill = UIFactory.Image(fill, new Color(0.35f, 0.9f, 0.4f));
            _healthFill.type = Image.Type.Filled;
            _healthFill.fillMethod = Image.FillMethod.Horizontal;
            _healthFill.sprite = ProcTex.Sprite(Texture2D.whiteTexture);
            _healthText = UIFactory.Text("Value", hp, "100", 24, TextAnchor.MiddleCenter, Color.white);
            var armor = UIFactory.Box("Armor", root, new Vector2(0, 1), new Vector2(230, -88), new Vector2(380, 12));
            UIFactory.Image(armor, new Color(0, 0, 0, 0.5f));
            var armorFill = UIFactory.Rect("Fill", armor, Vector2.zero, Vector2.one, new Vector2(2, 2), new Vector2(-2, -2));
            _armorFill = UIFactory.Image(armorFill, new Color(0.3f, 0.6f, 1f));
            _armorFill.type = Image.Type.Filled;
            _armorFill.fillMethod = Image.FillMethod.Horizontal;
            _armorFill.sprite = ProcTex.Sprite(Texture2D.whiteTexture);

            _status = Label(root, new Vector2(0, 1), new Vector2(230, -118), new Vector2(380, 30), 20, TextAnchor.MiddleLeft, new Color(1, 1, 1, 0.8f));

            // Counts + zone (top-centre)
            _counts = Label(root, new Vector2(0.5f, 1), new Vector2(0, -40), new Vector2(700, 40), 30, TextAnchor.MiddleCenter, Color.white);
            _zoneText = Label(root, new Vector2(0.5f, 1), new Vector2(0, -80), new Vector2(700, 36), 24, TextAnchor.MiddleCenter, new Color(0.6f, 0.85f, 1f));

            // Weapon + ammo (bottom-centre)
            _weaponText = Label(root, new Vector2(0.5f, 0), new Vector2(0, 95), new Vector2(600, 36), 26, TextAnchor.MiddleCenter, Color.white);
            _ammoText = Label(root, new Vector2(0.5f, 0), new Vector2(0, 55), new Vector2(600, 44), 36, TextAnchor.MiddleCenter, new Color(1f, 0.9f, 0.5f));

            // Crosshair + hit marker
            _crosshair = UIFactory.Box("Crosshair", root, new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(40, 40));
            foreach (var (pos, size) in new[]
                     {
                         (new Vector2(0, 12), new Vector2(3, 12)), (new Vector2(0, -12), new Vector2(3, 12)),
                         (new Vector2(12, 0), new Vector2(12, 3)), (new Vector2(-12, 0), new Vector2(12, 3)),
                     })
            {
                var bar = UIFactory.Box("Bar", _crosshair, new Vector2(0.5f, 0.5f), pos, size);
                UIFactory.Image(bar, new Color(1, 1, 1, 0.85f));
            }
            var hit = UIFactory.Box("HitMarker", root, new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(34, 34));
            hit.localRotation = Quaternion.Euler(0, 0, 45);
            _hitMarker = UIFactory.Image(hit, new Color(1, 1, 1, 0), ProcTex.Sprite(ProcTex.Ring));

            _message = Label(root, new Vector2(0.5f, 0.5f), new Vector2(0, 200), new Vector2(1100, 60), 34, TextAnchor.MiddleCenter, new Color(1f, 0.92f, 0.5f));
            _pickup = Label(root, new Vector2(0.5f, 0.5f), new Vector2(0, -150), new Vector2(800, 40), 28, TextAnchor.MiddleCenter, Color.white);

            // Minimap (top-right)
            _minimap = UIFactory.Box("Minimap", root, new Vector2(1, 1), new Vector2(-170, -170), new Vector2(280, 280));
            UIFactory.Image(_minimap, new Color(0, 0, 0, 0.55f));
            var mapRect = UIFactory.Rect("Map", _minimap, Vector2.zero, Vector2.one, new Vector2(4, 4), new Vector2(-4, -4));
            _mapImage = mapRect.gameObject.AddComponent<RawImage>();
            _mapImage.raycastTarget = false;
            var mask = _minimap.gameObject.AddComponent<RectMask2D>();
            mask.enabled = true;
            _nextZoneRing = UIFactory.Box("NextZone", mapRect, new Vector2(0, 0), Vector2.zero, new Vector2(10, 10));
            UIFactory.Image(_nextZoneRing, new Color(1, 1, 1, 0.9f), ProcTex.Sprite(ProcTex.Ring));
            _zoneRing = UIFactory.Box("Zone", mapRect, new Vector2(0, 0), Vector2.zero, new Vector2(10, 10));
            UIFactory.Image(_zoneRing, new Color(0.3f, 0.6f, 1f, 1f), ProcTex.Sprite(ProcTex.Ring));
            _playerMarker = UIFactory.Box("Me", mapRect, new Vector2(0, 0), Vector2.zero, new Vector2(16, 16));
            UIFactory.Image(_playerMarker, new Color(1f, 0.85f, 0.2f), ProcTex.Sprite(ProcTex.Circle));
            var nose = UIFactory.Box("Dir", _playerMarker, new Vector2(0.5f, 0.5f), new Vector2(0, 11), new Vector2(5, 10));
            UIFactory.Image(nose, new Color(1f, 0.85f, 0.2f));

            _feedRoot = UIFactory.Box("KillFeed", root, new Vector2(1, 1), new Vector2(-260, -390), new Vector2(480, 160));
        }

        Text Label(Transform root, Vector2 anchor, Vector2 pos, Vector2 size, int fontSize, TextAnchor align, Color color)
        {
            var rt = UIFactory.Box("Text", root, anchor, pos, size);
            return UIFactory.Text("T", rt, "", fontSize, align, color);
        }

        // ------------------------------------------------------------------

        public void ShowMessage(string text, float seconds)
        {
            if (_message == null) return;
            _message.text = text;
            _messageTime = seconds;
        }

        public void ShowDamage(float amount)
        {
            _damageFlash = Mathf.Clamp01(_damageFlash + amount / 40f);
            PlayerController.Local?.Camera?.AddShake(Mathf.Clamp(amount / 30f, 0.15f, 0.7f));
        }

        public void ShowHitMarker(bool kill)
        {
            _hitTime = 0.25f;
            _hitMarker.color = kill ? new Color(1f, 0.25f, 0.2f, 1f) : new Color(1, 1, 1, 1);
        }

        public void SetPickupPrompt(string label) => _pickup.text = label ?? "";

        public void AddKillFeed(string line, bool villainDied)
        {
            var rt = UIFactory.Box("Line", _feedRoot, new Vector2(1, 1), new Vector2(-240, -18), new Vector2(480, 32));
            var text = UIFactory.Text("T", rt, line, 22, TextAnchor.MiddleRight, villainDied ? new Color(0.6f, 1f, 0.6f) : new Color(1f, 0.6f, 0.55f));
            _feed.Insert(0, (text, 6f));
            while (_feed.Count > 5)
            {
                Destroy(_feed[^1].text.transform.parent.gameObject);
                _feed.RemoveAt(_feed.Count - 1);
            }
            for (int i = 0; i < _feed.Count; i++)
                ((RectTransform)_feed[i].text.transform.parent).anchoredPosition = new Vector2(-240, -18 - i * 32);
        }

        public void SetPlayerState(Combatant me, WeaponSystem weapons, bool aiming, bool firstPerson)
        {
            var pct = me.MaxHealth.Value > 0 ? me.Health.Value / me.MaxHealth.Value : 0;
            _healthFill.fillAmount = pct;
            _healthFill.color = Color.Lerp(new Color(1f, 0.25f, 0.2f), new Color(0.35f, 0.9f, 0.4f), pct * 1.4f - 0.2f);
            _healthText.text = me.IsDead.Value ? "KNOCKED OUT" : Mathf.CeilToInt(me.Health.Value).ToString();
            _armorFill.fillAmount = me.Armor.Value / 100f;

            var def = weapons.Current;
            _weaponText.text = def.Name.ToUpperInvariant();
            _ammoText.text = def.IsGun
                ? (weapons.Reloading ? "RELOADING..." : $"{weapons.CurrentMagazine} / {weapons.ReserveAmmo}")
                : "COMBO: JAB • CROSS • HOOK";
            _crosshair.localScale = Vector3.one * (aiming ? 0.6f : 1f);
            _crosshair.gameObject.SetActive(!me.IsDead.Value);
            var stance = me.NetStance.Value switch { Stance.Crouching => "CROUCHING", Stance.Prone => "PRONE", _ => "" };
            _status.text = $"{(firstPerson ? "FPP" : "TPP")}  {stance}  K:{me.Kills.Value}";
        }

        void Update()
        {
            var dt = Time.deltaTime;
            if (_messageTime > 0)
            {
                _messageTime -= dt;
                var c = _message.color;
                c.a = Mathf.Clamp01(_messageTime * 2f);
                _message.color = c;
            }
            if (_hitTime > 0)
            {
                _hitTime -= dt;
                var c = _hitMarker.color;
                c.a = Mathf.Clamp01(_hitTime * 4f);
                _hitMarker.color = c;
            }
            _damageFlash = Mathf.MoveTowards(_damageFlash, 0, dt * 1.5f);
            _vignette.color = new Color(0.8f, 0, 0, _damageFlash * 0.45f);

            for (int i = _feed.Count - 1; i >= 0; i--)
            {
                var (text, time) = _feed[i];
                time -= dt;
                if (time <= 0)
                {
                    Destroy(text.transform.parent.gameObject);
                    _feed.RemoveAt(i);
                    continue;
                }
                _feed[i] = (text, time);
            }

            UpdateMatchInfo();
            UpdateMinimap();
        }

        void UpdateMatchInfo()
        {
            var state = MatchState.Instance;
            if (state == null) return;
            _counts.text = $"VILLAINS LEFT {state.VillainsAlive.Value}   •   SQUAD ALIVE {state.PlayersAlive.Value}";
            var me = PlayerController.Local;
            var outside = me != null && me.Combatant.IsAlive && !state.IsInsideZone(me.transform.position) && state.Phase.Value == MatchPhase.Playing;
            if (outside)
            {
                _zoneText.color = new Color(1f, 0.4f, 0.35f);
                _zoneText.text = "YOU ARE OUTSIDE THE SAFE ZONE — RUN!";
            }
            else if (state.ZoneShrinking.Value)
            {
                _zoneText.color = new Color(1f, 0.75f, 0.3f);
                _zoneText.text = $"ZONE SHRINKING  {Mathf.CeilToInt(state.ZoneTimer.Value)}s";
            }
            else if (!float.IsInfinity(state.ZoneTimer.Value) && state.Phase.Value == MatchPhase.Playing)
            {
                _zoneText.color = new Color(0.6f, 0.85f, 1f);
                var t = Mathf.CeilToInt(state.ZoneTimer.Value);
                _zoneText.text = $"ZONE SHRINKS IN {t / 60}:{t % 60:00}";
            }
            else
            {
                _zoneText.text = "";
            }
        }

        void UpdateMinimap()
        {
            var world = WorldGenerator.Instance;
            var state = MatchState.Instance;
            if (world == null || state == null) return;
            if (_mapImage.texture != world.MinimapTexture) _mapImage.texture = world.MinimapTexture;
            var mapSize = ((RectTransform)_mapImage.transform).rect.size;
            Vector2 ToMap(Vector3 p) => new Vector2(p.x / world.Size * mapSize.x, p.z / world.Size * mapSize.y);
            Vector2 ToMap2(Vector2 p) => new Vector2(p.x / world.Size * mapSize.x, p.y / world.Size * mapSize.y);

            var me = PlayerController.Local;
            if (me != null)
            {
                _playerMarker.anchoredPosition = ToMap(me.transform.position);
                _playerMarker.localRotation = Quaternion.Euler(0, 0, -me.transform.eulerAngles.y);
            }
            var zoneR = state.ZoneRadius.Value / world.Size * mapSize.x * 2f * (64f / 60f);
            _zoneRing.anchoredPosition = ToMap2(state.ZoneCenter.Value);
            _zoneRing.sizeDelta = Vector2.one * Mathf.Min(zoneR, 5000f);
            var nextR = state.ZoneNextRadius.Value / world.Size * mapSize.x * 2f * (64f / 60f);
            _nextZoneRing.anchoredPosition = ToMap2(state.ZoneNextCenter.Value);
            _nextZoneRing.sizeDelta = Vector2.one * Mathf.Min(nextR, 5000f);

            // Teammates
            var i = 0;
            foreach (var c in Combatant.All)
            {
                if (c.Team.Value != Combatant.TeamHeroes || (me != null && c == me.Combatant) || c.IsDead.Value) continue;
                if (i >= _mateMarkers.Count)
                {
                    var m = UIFactory.Box("Mate", _mapImage.transform, Vector2.zero, Vector2.zero, new Vector2(12, 12));
                    UIFactory.Image(m, new Color(0.4f, 1f, 0.5f), ProcTex.Sprite(ProcTex.Circle));
                    _mateMarkers.Add(m);
                }
                _mateMarkers[i].gameObject.SetActive(true);
                _mateMarkers[i].anchoredPosition = ToMap(c.transform.position);
                i++;
            }
            for (; i < _mateMarkers.Count; i++) _mateMarkers[i].gameObject.SetActive(false);
        }
    }

    /// <summary>The glowing wall of the safe zone, visible in the world.</summary>
    public class ZoneWall : MonoBehaviour
    {
        static ZoneWall _instance;
        Transform _wall;

        public static void Create()
        {
            if (_instance != null) return;
            var go = new GameObject("ZoneWall");
            _instance = go.AddComponent<ZoneWall>();
            var wall = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            Destroy(wall.GetComponent<Collider>());
            wall.transform.SetParent(go.transform, false);
            wall.GetComponent<Renderer>().sharedMaterial = Mats.Transparent(new Color(0.25f, 0.5f, 1f, 0.22f));
            wall.GetComponent<Renderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            _instance._wall = wall.transform;
        }

        public static void Teardown()
        {
            if (_instance != null) Destroy(_instance.gameObject);
            _instance = null;
        }

        void Update()
        {
            var state = MatchState.Instance;
            var show = state != null && state.ZoneRadius.Value < 5000f;
            _wall.gameObject.SetActive(show);
            if (!show) return;
            var r = state.ZoneRadius.Value;
            _wall.position = new Vector3(state.ZoneCenter.Value.x, 60f, state.ZoneCenter.Value.y);
            _wall.localScale = new Vector3(r * 2f, 150f, r * 2f);
        }
    }
}
