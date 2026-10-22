using UnityEngine;

namespace PixelPunch3D
{
    public enum WeaponId : byte { Fists = 0, Pistol = 1, Smg = 2, Rifle = 3, Shotgun = 4, Sniper = 5 }

    public enum LootType : byte
    {
        Pistol = 1, Smg = 2, Rifle = 3, Shotgun = 4, Sniper = 5,
        Ammo = 10, Medkit = 11, Armor = 12,
    }

    public class WeaponDef
    {
        public WeaponId Id;
        public string Name;
        public float Damage;
        public float Interval;     // seconds between shots
        public float Spread;       // degrees (hip fire)
        public int Pellets = 1;
        public int Magazine;
        public float ReloadTime;
        public float Range;
        public bool Automatic;
        public float AimFov = 50f;
        public float Recoil = 1f;  // camera kick in degrees
        public Color Color = new Color(0.15f, 0.15f, 0.17f);
        public float Length = 0.4f;

        public bool IsGun => Id != WeaponId.Fists;
    }

    public static class Weapons
    {
        static readonly WeaponDef[] Defs =
        {
            new() { Id = WeaponId.Fists, Name = "Fists", Damage = 14, Interval = 0.3f, Range = 1.9f },
            new() { Id = WeaponId.Pistol, Name = "P92 Pistol", Damage = 22, Interval = 0.22f, Spread = 1.6f, Magazine = 12, ReloadTime = 1.3f, Range = 120, AimFov = 52, Recoil = 1.2f, Length = 0.26f },
            new() { Id = WeaponId.Smg, Name = "UMP Buzzer", Damage = 15, Interval = 0.085f, Spread = 2.6f, Magazine = 30, ReloadTime = 1.9f, Range = 140, Automatic = true, AimFov = 50, Recoil = 0.55f, Color = new Color(0.22f, 0.24f, 0.2f), Length = 0.48f },
            new() { Id = WeaponId.Rifle, Name = "M4 Punch-Rifle", Damage = 24, Interval = 0.11f, Spread = 1.8f, Magazine = 30, ReloadTime = 2.2f, Range = 260, Automatic = true, AimFov = 42, Recoil = 0.8f, Color = new Color(0.2f, 0.18f, 0.12f), Length = 0.72f },
            new() { Id = WeaponId.Shotgun, Name = "S12 Boomstick", Damage = 14, Interval = 0.85f, Spread = 6.5f, Pellets = 8, Magazine = 5, ReloadTime = 2.6f, Range = 40, AimFov = 55, Recoil = 3.5f, Color = new Color(0.32f, 0.2f, 0.12f), Length = 0.7f },
            new() { Id = WeaponId.Sniper, Name = "Kar Sniper", Damage = 85, Interval = 1.4f, Spread = 3.5f, Magazine = 5, ReloadTime = 2.8f, Range = 600, AimFov = 18, Recoil = 5f, Color = new Color(0.28f, 0.22f, 0.14f), Length = 0.95f },
        };

        public static WeaponDef Get(WeaponId id) => Defs[Mathf.Clamp((int)id, 0, Defs.Length - 1)];
        public static WeaponDef Get(byte id) => Get((WeaponId)id);
    }

    public static class LootTable
    {
        public static LootType Roll(System.Random rng)
        {
            var r = rng.NextDouble();
            if (r < 0.22) return LootType.Ammo;
            if (r < 0.36) return LootType.Medkit;
            if (r < 0.46) return LootType.Armor;
            if (r < 0.62) return LootType.Pistol;
            if (r < 0.75) return LootType.Smg;
            if (r < 0.86) return LootType.Rifle;
            if (r < 0.95) return LootType.Shotgun;
            return LootType.Sniper;
        }

        public static string Label(LootType type) => type switch
        {
            LootType.Ammo => "Ammo Box",
            LootType.Medkit => "Medkit",
            LootType.Armor => "Body Armor",
            _ => Weapons.Get((byte)type).Name,
        };

        public static Color Tint(LootType type) => type switch
        {
            LootType.Ammo => new Color(0.95f, 0.75f, 0.2f),
            LootType.Medkit => new Color(0.9f, 0.2f, 0.25f),
            LootType.Armor => new Color(0.25f, 0.55f, 0.95f),
            _ => new Color(0.85f, 0.85f, 0.9f),
        };
    }
}
