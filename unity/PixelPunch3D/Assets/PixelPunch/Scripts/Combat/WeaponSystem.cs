using System.Collections;
using UnityEngine;

namespace PixelPunch3D
{
    /// <summary>
    /// Fists + two gun slots. Punches are a 3-hit combo (jab, cross, hook)
    /// with aim assist and a hit check on the impact frame; guns are hitscan
    /// with spread, damage falloff, headshots, recoil and reloads. Used by the
    /// local player (via Tick) and by villain AI (via the Ai* methods).
    /// </summary>
    public class WeaponSystem : MonoBehaviour
    {
        public readonly WeaponId[] Slots = { WeaponId.Fists, WeaponId.Fists };
        public readonly int[] Magazine = new int[2];
        public int ReserveAmmo = 30;
        public int ActiveSlot = -1; // -1 = fists
        public bool Reloading { get; private set; }
        public float DamageScale = 1f; // villains scale their punches by their attack stat

        public WeaponDef Current => Weapons.Get(ActiveSlot >= 0 ? Slots[ActiveSlot] : WeaponId.Fists);
        public int CurrentMagazine => ActiveSlot >= 0 ? Magazine[ActiveSlot] : 0;

        Combatant _self;
        float _nextFire;
        int _comboStep = -1;
        float _lastPunchTime = -10f;
        bool _punchQueued;

        static readonly float[] ComboDamage = { 1f, 1.3f, 2f };

        void Awake() => _self = GetComponent<Combatant>();

        void SyncWeapon()
        {
            if (_self != null && _self.IsSpawned && _self.IsOwner) _self.NetWeapon.Value = (byte)Current.Id;
            TouchControls.Instance?.SetFireLabel(Current.IsGun ? "FIRE" : "PUNCH");
        }

        // ------------------------------------------------------------------
        // Local player

        /// Returns a yaw to turn towards when punch aim-assist found a target.
        public float? Tick(InputFrame input, Ray aimRay, bool aiming)
        {
            float? assistYaw = null;
            if (input.SwitchPressed) Switch();
            if (input.ReloadPressed) StartReload();

            var def = Current;
            if (!def.IsGun)
            {
                if (input.FirePressed || (input.FireHeld && Time.time - _lastPunchTime > 0.45f)) _punchQueued = true;
                if (_punchQueued && Time.time >= _nextFire)
                {
                    _punchQueued = false;
                    var target = FindPunchTarget(2.8f, 70f);
                    if (target != null)
                    {
                        var to = target.transform.position - transform.position;
                        assistYaw = Mathf.Atan2(to.x, to.z) * Mathf.Rad2Deg;
                    }
                    Punch();
                }
                return assistYaw;
            }

            var wantsFire = def.Automatic ? input.FireHeld : input.FirePressed;
            if (wantsFire && Time.time >= _nextFire && !Reloading)
            {
                if (Magazine[ActiveSlot] <= 0)
                {
                    StartReload();
                }
                else
                {
                    Fire(aimRay.origin, aimRay.direction, aiming ? 0.35f : 1f, isPlayer: true);
                }
            }
            return assistYaw;
        }

        public void Switch()
        {
            // Cycle fists → slot 0 → slot 1 → fists, skipping empty slots.
            for (int i = 0; i < 3; i++)
            {
                ActiveSlot = ActiveSlot >= 1 ? -1 : ActiveSlot + 1;
                if (ActiveSlot == -1 || Slots[ActiveSlot] != WeaponId.Fists) break;
            }
            Reloading = false;
            _nextFire = Time.time + 0.25f;
            SyncWeapon();
            AudioBank.PlayAt("gun_reload", transform.position, 0.3f);
        }

        public void StartReload()
        {
            if (Reloading || ActiveSlot < 0 || !Current.IsGun) return;
            if (Magazine[ActiveSlot] >= Current.Magazine || ReserveAmmo <= 0) return;
            StartCoroutine(Reload());
        }

        IEnumerator Reload()
        {
            Reloading = true;
            var slot = ActiveSlot;
            AudioBank.PlayAt("gun_reload", transform.position, 0.7f);
            yield return new WaitForSeconds(Current.ReloadTime);
            if (!Reloading || slot != ActiveSlot) yield break;
            var need = Current.Magazine - Magazine[slot];
            var take = Mathf.Min(need, ReserveAmmo);
            Magazine[slot] += take;
            ReserveAmmo -= take;
            Reloading = false;
        }

        // ------------------------------------------------------------------
        // Punching

        Combatant FindPunchTarget(float range, float maxAngle)
        {
            Combatant best = null;
            var bestScore = float.MaxValue;
            foreach (var c in Combatant.All)
            {
                if (c == _self || c.IsDead.Value || c.Team.Value == _self.Team.Value) continue;
                var to = c.transform.position - transform.position;
                to.y = 0;
                var dist = to.magnitude;
                if (dist > range) continue;
                var angle = Vector3.Angle(transform.forward, to);
                if (angle > maxAngle) continue;
                var score = dist + angle * 0.02f;
                if (score < bestScore) { bestScore = score; best = c; }
            }
            return best;
        }

        public void Punch()
        {
            var sinceLast = Time.time - _lastPunchTime;
            _comboStep = sinceLast < 0.8f ? (_comboStep + 1) % 3 : 0;
            _lastPunchTime = Time.time;
            var duration = _self.Visual.PunchDuration(_comboStep);
            _nextFire = Time.time + duration * 0.8f;
            _self.Visual.PlayPunch(_comboStep);
            _self.BroadcastPunch(_comboStep);
            AudioBank.PlayAt("punch_miss", transform.position, 0.45f);
            StartCoroutine(PunchImpact(_comboStep, duration * 0.45f));

            // A little lunge into the punch.
            if (_self.Controller.enabled && _self.IsOwner)
                _self.Controller.Move(transform.forward * (_comboStep == 2 ? 0.35f : 0.18f));
        }

        IEnumerator PunchImpact(int step, float delay)
        {
            yield return new WaitForSeconds(delay);
            if (_self.IsDead.Value) yield break;
            var target = FindPunchTarget(Weapons.Get(WeaponId.Fists).Range + 0.3f, 60f);
            if (target == null) yield break;
            var damage = Weapons.Get(WeaponId.Fists).Damage * ComboDamage[step] * DamageScale;
            var point = target.AimPoint;
            _self.RequestHit(target, damage, point, DamageKind.Punch);
            AudioBank.PlayAt(step == 2 ? "punch_heavy" : "punch_hit", point, 0.9f);
            Effects.Impact(point, true);
            if (step == 2) Effects.Shockwave(target.transform.position, new Color(1f, 0.6f, 0.2f, 0.5f));
            if (PlayerController.Local != null && PlayerController.Local.Combatant == _self)
            {
                PlayerController.Local.Camera.AddShake(step == 2 ? 0.8f : 0.35f);
                HUD.Instance?.ShowHitMarker(false);
            }
        }

        // ------------------------------------------------------------------
        // Shooting

        void Fire(Vector3 origin, Vector3 direction, float spreadScale, bool isPlayer)
        {
            var def = Current;
            _nextFire = Time.time + def.Interval;
            Magazine[ActiveSlot]--;
            var muzzle = _self.Visual.Muzzle != null ? _self.Visual.Muzzle.position : transform.position + Vector3.up * 1.4f;
            Vector3 lastEnd = origin + direction * def.Range;

            for (int p = 0; p < def.Pellets; p++)
            {
                var spread = def.Spread * spreadScale;
                var dir = Quaternion.Euler(Random.Range(-spread, spread), Random.Range(-spread, spread), 0) * direction;
                var end = origin + dir * def.Range;
                if (Physics.Raycast(origin, dir, out var hit, def.Range, isPlayer ? PlayerCamera.WorldMask : ~0, QueryTriggerInteraction.Ignore))
                {
                    end = hit.point;
                    var target = hit.collider.GetComponentInParent<Combatant>();
                    if (target != null && target != _self)
                    {
                        var falloff = Mathf.Lerp(1f, 0.55f, hit.distance / def.Range);
                        var headY = target.transform.position.y + Combatant.EyeHeight(target.NetStance.Value);
                        var headshot = hit.point.y > headY - 0.15f && target.NetStance.Value != Stance.Prone;
                        var damage = def.Damage * falloff * (headshot ? 1.8f : 1f) * (isPlayer ? 1f : 0.55f);
                        _self.RequestHit(target, damage, hit.point, DamageKind.Bullet);
                    }
                    else
                    {
                        Effects.Impact(hit.point, false);
                    }
                }
                lastEnd = end;
                Effects.Tracer(muzzle, end);
            }

            Effects.MuzzleFlash(muzzle);
            AudioBank.PlayAt("gun_shot", muzzle, 0.9f);
            _self.Visual.PlayRecoil();
            _self.BroadcastShot(muzzle, lastEnd, (byte)def.Id);
            if (isPlayer && PlayerController.Local != null && PlayerController.Local.Combatant == _self)
                PlayerController.Local.Kick(def.Recoil);
        }

        // ------------------------------------------------------------------
        // Loot (owner) and AI helpers (server)

        public void OnLootReceived(LootType type, int amount)
        {
            switch (type)
            {
                case LootType.Ammo:
                    ReserveAmmo += amount;
                    HUD.Instance?.ShowMessage($"+{amount} ammo", 1.5f);
                    return;
                case LootType.Medkit:
                    HUD.Instance?.ShowMessage("Healed!", 1.5f);
                    return;
                case LootType.Armor:
                    HUD.Instance?.ShowMessage("Armor equipped", 1.5f);
                    return;
            }
            GiveWeapon((WeaponId)(byte)type);
            ReserveAmmo += Weapons.Get((byte)type).Magazine * 2;
            HUD.Instance?.ShowMessage($"Picked up {Weapons.Get((byte)type).Name}", 1.8f);
        }

        public void GiveWeapon(WeaponId id)
        {
            var slot = Slots[0] == WeaponId.Fists ? 0 : Slots[1] == WeaponId.Fists ? 1 : Mathf.Max(ActiveSlot, 0);
            Slots[slot] = id;
            Magazine[slot] = Weapons.Get(id).Magazine;
            ActiveSlot = slot;
            Reloading = false;
            SyncWeapon();
        }

        public bool AiCanFire => Current.IsGun && Time.time >= _nextFire && !Reloading;

        public void AiFireAt(Vector3 eye, Vector3 targetPoint, float inaccuracy)
        {
            if (!AiCanFire) return;
            if (Magazine[ActiveSlot] <= 0)
            {
                Magazine[ActiveSlot] = Current.Magazine; // villains have endless ammo
                _nextFire = Time.time + Current.ReloadTime;
                AudioBank.PlayAt("gun_reload", transform.position, 0.6f);
                return;
            }
            Fire(eye, (targetPoint - eye).normalized, inaccuracy, isPlayer: false);
        }

        public bool AiCanPunch => !Current.IsGun && Time.time >= _nextFire;
    }
}
