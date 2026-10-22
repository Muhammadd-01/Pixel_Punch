using System;
using UnityEngine;

namespace PixelPunch3D
{
    /// <summary>
    /// Everything Flutter tells the 3D game before a match (sent as JSON via
    /// GameBridge.StartMatch). Field names match the Dart side exactly.
    /// </summary>
    [Serializable]
    public class MatchConfig
    {
        /// offline | host | join | lan_host | lan_join
        public string role = "offline";
        /// Unity Multiplayer session code used when role == join.
        public string joinCode = "";
        /// Host IP for role == lan_join (testing without Unity Gaming Services).
        public string lanAddress = "127.0.0.1";
        public int maxPlayers = 4;

        public int seed = 1337;
        public float mapSize = 1600f;
        public int villainCount = 12;
        public bool startInFirstPerson = false;

        public string playerName = "Player";
        public string heroId = "hero_striker";
        public string heroColor = "#4CAF50";

        public VillainSpec[] villains = Array.Empty<VillainSpec>();

        public static MatchConfig FromJson(string json)
        {
            var config = JsonUtility.FromJson<MatchConfig>(json) ?? new MatchConfig();
            config.villains ??= Array.Empty<VillainSpec>();
            config.mapSize = Mathf.Clamp(config.mapSize, 400f, 4000f);
            config.villainCount = Mathf.Clamp(config.villainCount, 1, 40);
            config.maxPlayers = Mathf.Clamp(config.maxPlayers, 1, 16);
            return config;
        }

        /// A self-contained match for pressing Play inside the Unity editor.
        public static MatchConfig EditorDefault() => new MatchConfig
        {
            role = "offline",
            seed = 2026,
            villainCount = 10,
            villains = new[]
            {
                new VillainSpec { id = "villain_bug_phantom", name = "Bug Phantom", archetype = "trickster", color = "#8BC34A", health = 80, attack = 10, defense = 5, speed = 5.5f },
                new VillainSpec { id = "villain_captain_deadline", name = "Captain Deadline", archetype = "heavy_hitter", color = "#F44336", health = 120, attack = 22, defense = 15, speed = 3.8f },
                new VillainSpec { id = "villain_firewall_guardian", name = "Firewall Guardian", archetype = "tank", color = "#FF9800", health = 160, attack = 14, defense = 25, speed = 3.4f },
                new VillainSpec { id = "villain_lag_lord", name = "Lag Lord", archetype = "speedster", color = "#00BCD4", health = 70, attack = 9, defense = 4, speed = 6.5f },
            },
        };
    }

    /// <summary>A villain to put on the map (built-in or made in the Villain Lab).</summary>
    [Serializable]
    public class VillainSpec
    {
        public string id = "";
        public string name = "Villain";
        public string title = "";
        public string archetype = "balanced";
        public string color = "#E53935";
        public string skin = "#E0AC69";
        public string hair = "#3B2A20";
        public int health = 100;
        public int attack = 15;
        public int defense = 10;
        public float speed = 4.5f;
        /// Base64 PNG of the person's face (front photo crop). Empty = no face.
        public string face = "";
        public string[] taunts = Array.Empty<string>();

        public Color MainColor => ColorUtil.Parse(color, new Color(0.9f, 0.2f, 0.2f));
        public Color SkinColor => ColorUtil.Parse(skin, new Color(0.88f, 0.67f, 0.41f));
        public Color HairColor => ColorUtil.Parse(hair, new Color(0.23f, 0.16f, 0.12f));
    }

    public static class ColorUtil
    {
        public static Color Parse(string hex, Color fallback)
        {
            if (string.IsNullOrEmpty(hex)) return fallback;
            if (hex.StartsWith("0x") && hex.Length == 10) hex = "#" + hex.Substring(4) ;
            if (!hex.StartsWith("#")) hex = "#" + hex;
            return ColorUtility.TryParseHtmlString(hex, out var c) ? c : fallback;
        }
    }
}
