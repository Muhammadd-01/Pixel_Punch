using System.Collections.Generic;
using Unity.Netcode;
using UnityEngine;

namespace PixelPunch3D
{
    /// <summary>
    /// A villain from the roster (built-in or made from a face in the Villain
    /// Lab). The server runs its brain: roam the island, notice heroes by sight
    /// or sound, chase, punch or shoot, taunt, and keep inside the safe zone.
    /// </summary>
    [RequireComponent(typeof(Combatant), typeof(WeaponSystem))]
    public class VillainNet : NetworkBehaviour
    {
        static readonly List<VillainNet> All = new();

        public readonly NetworkVariable<int> SpecIndex = new(-1);

        Combatant _self;
        WeaponSystem _weapons;
        VillainSpec _spec;
        System.Random _rng;

        enum Mode { Roam, Chase, Attack, ToZone }
        Mode _mode = Mode.Roam;
        Combatant _target;
        Vector3 _roamPoint;
        float _thinkTimer;
        float _verticalVelocity;
        float _tauntTimer;
        float _stuckTimer;
        float _strafeDir = 1f;
        Vector3 _lastPos;
        float _moveSpeed = 4f;
        bool _taunted;

        void Awake()
        {
            _self = GetComponent<Combatant>();
            _weapons = GetComponent<WeaponSystem>();
        }

        /// Server, before Spawn().
        public void ServerSetup(int specIndex, VillainSpec spec, int seed)
        {
            SpecIndex.Value = specIndex;
            _self.DisplayName.Value = Combatant.SafeName(spec.name);
            _self.Team.Value = Combatant.TeamVillains;
            var hp = Mathf.Clamp(spec.health, 40, 300) * 1.3f;
            _self.MaxHealth.Value = hp;
            _self.Health.Value = hp;
            _self.Defense.Value = Mathf.Clamp(spec.defense, 0, 40) * 0.5f;
            _self.MainColor.Value = spec.MainColor;
            _rng = new System.Random(seed);
        }

        public override void OnNetworkSpawn()
        {
            All.Add(this);
            SpecIndex.OnValueChanged += (_, _) => RefreshAppearance();
            RefreshAppearance();
            if (IsServer)
            {
                _rng ??= new System.Random(SpecIndex.Value * 31 + (int)NetworkObjectId);
                _spec = MatchState.Instance != null ? MatchState.Instance.SpecAt(SpecIndex.Value) : null;
                _moveSpeed = Mathf.Clamp(_spec != null ? _spec.speed : 4.2f, 2.8f, 7f);
                _weapons.DamageScale = Mathf.Clamp((_spec != null ? _spec.attack : 14) / 14f, 0.6f, 2f);
                ArmForArchetype(_spec != null ? _spec.archetype : "balanced");
                _roamPoint = transform.position;
                _tauntTimer = 8f + (float)_rng.NextDouble() * 10f;
                _lastPos = transform.position;
            }
        }

        public override void OnNetworkDespawn() => All.Remove(this);

        void ArmForArchetype(string archetype)
        {
            switch (archetype)
            {
                case "speedster": _weapons.GiveWeapon(WeaponId.Smg); break;
                case "trickster": _weapons.GiveWeapon(WeaponId.Pistol); break;
                case "support": _weapons.GiveWeapon(WeaponId.Rifle); break;
                case "balanced":
                    if (_rng.NextDouble() < 0.5) _weapons.GiveWeapon(WeaponId.Shotgun);
                    break;
                // Tanks and heavy hitters fight with their fists.
            }
        }

        public void RefreshAppearance()
        {
            var state = MatchState.Instance;
            var spec = state != null ? state.SpecAt(SpecIndex.Value) : null;
            if (spec == null)
            {
                _self.Visual.Build(_self.MainColor.Value, new Color(0.88f, 0.67f, 0.41f), new Color(0.2f, 0.12f, 0.1f), -1, true, "balanced");
                return;
            }
            var hasFace = FaceLibrary.Photo(SpecIndex.Value) != null;
            _self.Visual.Build(spec.MainColor, spec.SkinColor, spec.HairColor, hasFace ? SpecIndex.Value : -1, true, spec.archetype);
        }

        public static void RefreshAllAppearances()
        {
            foreach (var v in All) if (v != null) v.RefreshAppearance();
        }

        public static IEnumerable<string> DefeatedIds()
        {
            var state = MatchState.Instance;
            var seen = new HashSet<string>();
            foreach (var v in All)
            {
                if (v == null || !v._self.IsDead.Value) continue;
                var spec = state != null ? state.SpecAt(v.SpecIndex.Value) : null;
                if (spec != null && seen.Add(spec.id)) yield return spec.id;
            }
        }

        // ------------------------------------------------------------------
        // Brain (server only)

        void Update()
        {
            if (!IsServer || !IsSpawned || _self.IsDead.Value) return;
            var state = MatchState.Instance;
            if (state == null || state.Phase.Value != MatchPhase.Playing) return;

            _thinkTimer -= Time.deltaTime;
            if (_thinkTimer <= 0)
            {
                _thinkTimer = 0.3f;
                Think(state);
            }
            Act(state);
            _self.WritePose(transform.eulerAngles.y, 0, _self.Controller.velocity.magnitude, _self.Controller.isGrounded);
        }

        void Think(MatchState state)
        {
            // Zone first: villains are not suicidal.
            if (!state.IsInsideZone(transform.position) || state.ZoneRadius.Value < 9000 &&
                Vector2.Distance(new Vector2(transform.position.x, transform.position.z), state.ZoneCenter.Value) > state.ZoneRadius.Value * 0.92f)
            {
                if (_target == null || Vector3.Distance(_target.transform.position, transform.position) > 15f)
                {
                    _mode = Mode.ToZone;
                    return;
                }
            }

            var eye = transform.position + Vector3.up * 1.5f;
            Combatant best = null;
            var bestDist = float.MaxValue;
            foreach (var c in Combatant.All)
            {
                if (c.IsDead.Value || c.Team.Value == _self.Team.Value || c.NetGliding.Value) continue;
                var d = Vector3.Distance(c.transform.position, transform.position);
                var hearing = c.NetStance.Value == Stance.Prone ? 6f : c.NetStance.Value == Stance.Crouching ? 10f : 16f;
                var sight = c.NetStance.Value == Stance.Prone ? 35f : 70f;
                if (d > sight) continue;
                var visible = d < hearing || HasLineOfSightIgnoringSelf(eye, c);
                if (!visible) continue;
                if (d < bestDist) { bestDist = d; best = c; }
            }

            if (best != null && best != _target && !_taunted)
            {
                _taunted = true;
                Taunt();
            }
            _target = best;
            if (_target == null)
            {
                _mode = Mode.Roam;
                if (Vector3.Distance(transform.position, _roamPoint) < 3f || _stuckTimer > 2f) PickRoamPoint(state);
                return;
            }
            var range = _weapons.Current.IsGun ? Mathf.Min(_weapons.Current.Range * 0.5f, 45f) : 1.7f;
            _mode = bestDist <= range ? Mode.Attack : Mode.Chase;
            if (_rng.NextDouble() < 0.1) _strafeDir = -_strafeDir;
        }

        bool HasLineOfSightIgnoringSelf(Vector3 eye, Combatant target)
        {
            var dir = target.AimPoint - eye;
            var hits = Physics.RaycastAll(eye, dir.normalized, dir.magnitude, ~0, QueryTriggerInteraction.Ignore);
            foreach (var h in hits)
            {
                var c = h.collider.GetComponentInParent<Combatant>();
                if (c == _self || c == target) continue;
                if (c != null) continue; // other characters don't block sight
                return false;
            }
            return true;
        }

        void PickRoamPoint(MatchState state)
        {
            var world = WorldGenerator.Instance;
            for (int i = 0; i < 10; i++)
            {
                var angle = (float)_rng.NextDouble() * Mathf.PI * 2f;
                var dist = 15f + (float)_rng.NextDouble() * 45f;
                var p = transform.position + new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle)) * dist;
                p.x = Mathf.Clamp(p.x, world.Size * 0.1f, world.Size * 0.9f);
                p.z = Mathf.Clamp(p.z, world.Size * 0.1f, world.Size * 0.9f);
                if (!state.IsInsideZone(p)) continue;
                _roamPoint = world.GroundPoint(p.x, p.z);
                _stuckTimer = 0;
                return;
            }
            var c = state.ZoneCenter.Value;
            _roamPoint = world.GroundPoint(c.x, c.y);
        }

        void Act(MatchState state)
        {
            var controller = _self.Controller;
            if (!controller.enabled) return;
            Vector3 move = Vector3.zero;
            var speed = _moveSpeed;
            Vector3? face = null;

            switch (_mode)
            {
                case Mode.Roam:
                    move = Flat(_roamPoint - transform.position);
                    speed *= 0.5f;
                    break;
                case Mode.ToZone:
                    var c = state.ZoneCenter.Value;
                    move = Flat(new Vector3(c.x, 0, c.y) - transform.position);
                    speed *= 1.1f;
                    break;
                case Mode.Chase:
                    if (_target == null) break;
                    move = Flat(_target.transform.position - transform.position);
                    face = _target.transform.position;
                    break;
                case Mode.Attack:
                    if (_target == null) break;
                    face = _target.transform.position;
                    if (_weapons.Current.IsGun)
                    {
                        // Strafe while shooting.
                        var to = Flat(_target.transform.position - transform.position);
                        move = Vector3.Cross(Vector3.up, to) * _strafeDir;
                        speed *= 0.45f;
                        var inaccuracy = 2.6f + Vector3.Distance(_target.transform.position, transform.position) * 0.02f;
                        _weapons.AiFireAt(transform.position + Vector3.up * 1.5f, _target.AimPoint, inaccuracy);
                    }
                    else if (_weapons.AiCanPunch)
                    {
                        _weapons.Punch();
                    }
                    break;
            }

            if (move.sqrMagnitude > 0.01f) move = move.normalized;
            var lookAt = face ?? (move.sqrMagnitude > 0.01f ? transform.position + move : (Vector3?)null);
            if (lookAt.HasValue)
            {
                var dir = Flat(lookAt.Value - transform.position);
                if (dir.sqrMagnitude > 0.01f)
                {
                    var targetYaw = Mathf.Atan2(dir.x, dir.z) * Mathf.Rad2Deg;
                    var yaw = Mathf.MoveTowardsAngle(transform.eulerAngles.y, targetYaw, 540f * Time.deltaTime);
                    transform.rotation = Quaternion.Euler(0, yaw, 0);
                }
            }

            if (controller.isGrounded)
            {
                _verticalVelocity = -2f;
                // Hop over small obstacles when stuck.
                if (_stuckTimer > 0.8f && move.sqrMagnitude > 0)
                {
                    _verticalVelocity = 6.5f;
                    _stuckTimer = 0.4f;
                }
            }
            else
            {
                _verticalVelocity += -20f * Time.deltaTime;
            }
            controller.Move((move * speed + Vector3.up * _verticalVelocity) * Time.deltaTime);

            var moved = Flat(transform.position - _lastPos).magnitude;
            _stuckTimer = move.sqrMagnitude > 0 && moved < speed * Time.deltaTime * 0.25f ? _stuckTimer + Time.deltaTime : 0f;
            _lastPos = transform.position;

            _tauntTimer -= Time.deltaTime;
            if (_tauntTimer <= 0 && _target != null)
            {
                _tauntTimer = 12f + (float)_rng.NextDouble() * 10f;
                Taunt();
            }
        }

        void Taunt()
        {
            var lines = _spec != null && _spec.taunts != null && _spec.taunts.Length > 0
                ? _spec.taunts
                : new[] { "You can't hide from me!", "This island is MINE!", "Is that all you've got?" };
            _self.BroadcastSay(lines[_rng.Next(lines.Length)]);
        }

        static Vector3 Flat(Vector3 v) => new Vector3(v.x, 0, v.z);
    }
}
