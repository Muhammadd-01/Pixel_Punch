using System.Collections.Generic;
using Unity.Collections;
using Unity.Netcode;
using UnityEngine;

namespace PixelPunch3D
{
    public enum DamageKind : byte { Punch = 0, Bullet = 1, Zone = 2, Fall = 3 }
    public enum Stance : byte { Standing = 0, Crouching = 1, Prone = 2 }

    /// <summary>
    /// Shared health, stance and replicated pose for players and villains.
    /// The owner (a player's client, or the server for villains) moves the
    /// character and writes its pose; everyone else interpolates it. Health
    /// is server-authoritative: hits are requested by RPC and applied there.
    /// </summary>
    [RequireComponent(typeof(CharacterController))]
    public class Combatant : NetworkBehaviour
    {
        public const byte TeamHeroes = 0;
        public const byte TeamVillains = 1;

        public static readonly List<Combatant> All = new();

        public readonly NetworkVariable<float> Health = new(100f);
        public readonly NetworkVariable<float> MaxHealth = new(100f);
        public readonly NetworkVariable<float> Armor = new(0f);
        public readonly NetworkVariable<bool> IsDead = new();
        public readonly NetworkVariable<byte> Team = new(TeamHeroes);
        public readonly NetworkVariable<FixedString64Bytes> DisplayName = new();
        public readonly NetworkVariable<int> Kills = new();
        public readonly NetworkVariable<int> DamageDealt = new();
        public readonly NetworkVariable<float> Defense = new();
        public readonly NetworkVariable<Color> MainColor = new(Color.green);

        // Pose, written by whoever simulates this character.
        public readonly NetworkVariable<Vector3> NetPosition = new(default, NetworkVariableReadPermission.Everyone, NetworkVariableWritePermission.Owner);
        public readonly NetworkVariable<float> NetYaw = new(0, NetworkVariableReadPermission.Everyone, NetworkVariableWritePermission.Owner);
        public readonly NetworkVariable<float> NetPitch = new(0, NetworkVariableReadPermission.Everyone, NetworkVariableWritePermission.Owner);
        public readonly NetworkVariable<float> NetSpeed = new(0, NetworkVariableReadPermission.Everyone, NetworkVariableWritePermission.Owner);
        public readonly NetworkVariable<Stance> NetStance = new(Stance.Standing, NetworkVariableReadPermission.Everyone, NetworkVariableWritePermission.Owner);
        public readonly NetworkVariable<bool> NetGrounded = new(true, NetworkVariableReadPermission.Everyone, NetworkVariableWritePermission.Owner);
        public readonly NetworkVariable<bool> NetAiming = new(false, NetworkVariableReadPermission.Everyone, NetworkVariableWritePermission.Owner);
        public readonly NetworkVariable<byte> NetWeapon = new(0, NetworkVariableReadPermission.Everyone, NetworkVariableWritePermission.Owner);
        public readonly NetworkVariable<bool> NetGliding = new(false, NetworkVariableReadPermission.Everyone, NetworkVariableWritePermission.Owner);

        public CharacterController Controller { get; private set; }
        public CharacterVisual Visual { get; private set; }
        public bool IsAlive => !IsDead.Value;
        public Vector3 AimPoint => transform.position + Vector3.up * EyeHeight(NetStance.Value) * 0.85f;
        public string Name => DisplayName.Value.ToString();

        /// Last attacker, so zone deaths after a fight still credit the kill.
        Combatant _lastAttacker;
        float _lastAttackTime;

        /// FixedString64Bytes holds at most 61 UTF-8 bytes; trim safely.
        public static FixedString64Bytes SafeName(string name)
        {
            name = string.IsNullOrWhiteSpace(name) ? "Player" : name.Trim();
            while (System.Text.Encoding.UTF8.GetByteCount(name) > 58) name = name.Substring(0, name.Length - 1);
            return name;
        }

        public static float EyeHeight(Stance stance) => stance switch
        {
            Stance.Crouching => 1.1f,
            Stance.Prone => 0.45f,
            _ => 1.6f,
        };

        void Awake()
        {
            Controller = GetComponent<CharacterController>();
            Visual = GetComponent<CharacterVisual>();
            if (Visual == null) Visual = gameObject.AddComponent<CharacterVisual>();
        }

        public override void OnNetworkSpawn()
        {
            All.Add(this);
            NetStance.OnValueChanged += (_, s) => ApplyStanceCollider(s);
            IsDead.OnValueChanged += (_, dead) =>
            {
                if (dead) Visual.PlayDeath();
                Controller.enabled = !dead;
            };
            ApplyStanceCollider(NetStance.Value);
            if (IsOwner)
            {
                NetPosition.Value = transform.position;
                NetYaw.Value = transform.eulerAngles.y;
            }
            else
            {
                transform.position = NetPosition.Value;
            }
        }

        public override void OnNetworkDespawn()
        {
            All.Remove(this);
        }

        public void ApplyStanceCollider(Stance stance)
        {
            if (Controller == null) return;
            var height = stance switch { Stance.Crouching => 1.2f, Stance.Prone => 0.7f, _ => 1.8f };
            Controller.height = height;
            Controller.radius = stance == Stance.Prone ? 0.32f : 0.38f;
            Controller.center = new Vector3(0, height / 2f, 0);
        }

        /// Owner: push our pose to the network.
        public void WritePose(float yaw, float pitch, float speed, bool grounded)
        {
            if (!IsOwner) return;
            var pos = transform.position;
            if ((NetPosition.Value - pos).sqrMagnitude > 0.0004f) NetPosition.Value = pos;
            if (Mathf.Abs(Mathf.DeltaAngle(NetYaw.Value, yaw)) > 0.5f) NetYaw.Value = yaw;
            if (Mathf.Abs(NetPitch.Value - pitch) > 1f) NetPitch.Value = pitch;
            if (Mathf.Abs(NetSpeed.Value - speed) > 0.15f) NetSpeed.Value = speed;
            if (NetGrounded.Value != grounded) NetGrounded.Value = grounded;
        }

        void Update()
        {
            if (!IsSpawned || IsOwner) return;
            // Smoothly follow the owner's replicated pose.
            var target = NetPosition.Value;
            var current = transform.position;
            if ((target - current).sqrMagnitude > 25f) transform.position = target; // teleport
            else transform.position = Vector3.Lerp(current, target, 1f - Mathf.Exp(-14f * Time.deltaTime));
            var yaw = Mathf.LerpAngle(transform.eulerAngles.y, NetYaw.Value, 1f - Mathf.Exp(-14f * Time.deltaTime));
            transform.rotation = Quaternion.Euler(0, yaw, 0);
        }

        // ------------------------------------------------------------------
        // Damage

        /// Called by the attacker's owner to report a hit it detected.
        public void RequestHit(Combatant target, float damage, Vector3 point, DamageKind kind)
        {
            if (target == null || !target.IsSpawned) return;
            if (IsServer) target.ServerApplyDamage(damage, this, point, kind);
            else HitRpc(target.NetworkObjectId, damage, point, kind);
        }

        [Rpc(SendTo.Server)]
        void HitRpc(ulong targetId, float damage, Vector3 point, DamageKind kind)
        {
            if (IsDead.Value) return;
            if (!NetworkManager.SpawnManager.SpawnedObjects.TryGetValue(targetId, out var obj)) return;
            var target = obj.GetComponent<Combatant>();
            if (target == null) return;
            // Basic sanity checks against impossible hits.
            var maxRange = kind == DamageKind.Punch ? 4f : 600f;
            if (Vector3.Distance(transform.position, target.transform.position) > maxRange) return;
            target.ServerApplyDamage(Mathf.Clamp(damage, 0, 150), this, point, kind);
        }

        public void ServerApplyDamage(float amount, Combatant attacker, Vector3 point, DamageKind kind)
        {
            if (!IsServer || IsDead.Value || amount <= 0) return;
            if (attacker != null && attacker.Team.Value == Team.Value && attacker != this) return; // no friendly fire

            var reduced = kind == DamageKind.Zone ? amount : amount * 100f / (100f + Defense.Value * 3f);
            if (Armor.Value > 0 && kind == DamageKind.Bullet)
            {
                var absorbed = Mathf.Min(Armor.Value, reduced * 0.5f);
                Armor.Value -= absorbed;
                reduced -= absorbed;
            }
            Health.Value = Mathf.Max(0, Health.Value - reduced);

            if (attacker != null && attacker != this)
            {
                attacker.DamageDealt.Value += Mathf.RoundToInt(reduced);
                _lastAttacker = attacker;
                _lastAttackTime = Time.time;
            }
            if (kind != DamageKind.Zone) DamagedRpc(point, reduced, attacker != null ? attacker.NetworkObjectId : ulong.MaxValue);

            if (Health.Value <= 0)
            {
                IsDead.Value = true;
                var killer = attacker ?? (Time.time - _lastAttackTime < 10f ? _lastAttacker : null);
                if (killer != null && killer != this) killer.Kills.Value++;
                DiedRpc(killer != null ? killer.Name : "", Name, kind);
            }
        }

        public void ServerHeal(float amount)
        {
            if (!IsServer || IsDead.Value) return;
            Health.Value = Mathf.Min(MaxHealth.Value, Health.Value + amount);
        }

        [Rpc(SendTo.Everyone)]
        void DamagedRpc(Vector3 point, float amount, ulong attackerId)
        {
            Visual.FlashHit();
            Effects.Impact(point, true);
            AudioBank.PlayAt("damage_taken", point, 0.6f);
            if (IsOwner && PlayerController.Local != null && PlayerController.Local.Combatant == this)
                HUD.Instance?.ShowDamage(amount);
            var local = PlayerController.Local;
            if (local != null && local.Combatant.NetworkObjectId == attackerId)
                HUD.Instance?.ShowHitMarker(IsDead.Value || Health.Value <= 0);
        }

        [Rpc(SendTo.Everyone)]
        void DiedRpc(string killerName, string victimName, DamageKind kind)
        {
            var how = kind switch
            {
                DamageKind.Punch => "knocked out",
                DamageKind.Zone => "was caught by the zone",
                DamageKind.Fall => "fell",
                _ => "eliminated",
            };
            var line = string.IsNullOrEmpty(killerName) || kind == DamageKind.Zone
                ? $"{victimName} {how}"
                : $"{killerName} {how} {victimName}";
            HUD.Instance?.AddKillFeed(line, Team.Value == TeamVillains);
            AudioBank.PlayAt("knockout", transform.position, 0.8f);
        }

        // ------------------------------------------------------------------
        // Cosmetic events from the owner to everyone else

        public void BroadcastPunch(int comboStep)
        {
            if (IsSpawned) PunchRpc((byte)comboStep);
        }

        [Rpc(SendTo.NotMe)]
        void PunchRpc(byte step)
        {
            Visual.PlayPunch(step);
            AudioBank.PlayAt("punch_miss", transform.position, 0.5f);
        }

        public void BroadcastShot(Vector3 from, Vector3 to, byte weaponId)
        {
            if (IsSpawned) ShotRpc(from, to, weaponId);
        }

        [Rpc(SendTo.NotMe)]
        void ShotRpc(Vector3 from, Vector3 to, byte weaponId)
        {
            Visual.PlayRecoil();
            Effects.Tracer(from, to);
            Effects.MuzzleFlash(from);
            AudioBank.PlayAt("gun_shot", from, 0.8f);
        }

        public void BroadcastSay(string text)
        {
            if (IsSpawned && IsServer) SayRpc(text);
        }

        [Rpc(SendTo.Everyone)]
        void SayRpc(string text) => Visual.Say(text);

        // ------------------------------------------------------------------
        // Loot

        public void RequestPickup(LootItem item)
        {
            if (item == null || !item.IsSpawned) return;
            if (IsServer) item.ServerTryPickup(this);
            else PickupRpc(item.NetworkObjectId);
        }

        [Rpc(SendTo.Server)]
        void PickupRpc(ulong lootId)
        {
            if (!NetworkManager.SpawnManager.SpawnedObjects.TryGetValue(lootId, out var obj)) return;
            var item = obj.GetComponent<LootItem>();
            if (item != null) item.ServerTryPickup(this);
        }

        /// Server → owner: you picked something up.
        public void ServerGive(LootType type, int amount)
        {
            switch (type)
            {
                case LootType.Medkit: ServerHeal(amount); break;
                case LootType.Armor: Armor.Value = Mathf.Min(100, Armor.Value + amount); break;
            }
            GiveRpc(type, amount);
        }

        [Rpc(SendTo.Owner)]
        void GiveRpc(LootType type, int amount)
        {
            AudioBank.Play2D("item_pickup", 0.8f);
            var weapons = GetComponent<WeaponSystem>();
            if (weapons != null) weapons.OnLootReceived(type, amount);
        }
    }
}
