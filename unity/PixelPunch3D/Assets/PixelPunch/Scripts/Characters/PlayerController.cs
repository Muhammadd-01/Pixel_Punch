using System.Collections;
using Unity.Netcode;
using UnityEngine;

namespace PixelPunch3D
{
    /// <summary>
    /// The human player. The owning client simulates movement (walk, sprint,
    /// jump, crouch, prone, skydive) and combat input; everyone else just sees
    /// the replicated pose through Combatant.
    /// </summary>
    [RequireComponent(typeof(Combatant), typeof(WeaponSystem))]
    public class PlayerController : NetworkBehaviour
    {
        public static PlayerController Local { get; private set; }

        public Combatant Combatant { get; private set; }
        public WeaponSystem Weapons { get; private set; }
        public PlayerCamera Camera { get; private set; }

        static readonly Color[] HeroColors =
        {
            new(0.3f, 0.69f, 0.31f), new(0.13f, 0.59f, 0.95f), new(1f, 0.76f, 0.03f),
            new(0.61f, 0.15f, 0.69f), new(1f, 0.34f, 0.13f), new(0f, 0.74f, 0.83f),
        };

        float _yaw;
        float _pitch;
        float _verticalVelocity;
        bool _aiming;
        bool _ready;
        bool _gliding;
        bool _wasGrounded = true;
        float _stepTimer;
        LootItem _nearbyLoot;
        Combatant _spectating;

        const float Gravity = -20f;
        const float JumpVelocity = 6.8f;

        void Awake()
        {
            Combatant = GetComponent<Combatant>();
            Weapons = GetComponent<WeaponSystem>();
        }

        public override void OnNetworkSpawn()
        {
            Combatant.MainColor.OnValueChanged += (_, _) => BuildVisual();
            BuildVisual();

            if (IsOwner)
            {
                Local = this;
                var config = MatchManager.Config ?? new MatchConfig();
                ProfileRpc(config.playerName, ColorUtil.Parse(config.heroColor, HeroColors[(int)(OwnerClientId % (ulong)HeroColors.Length)]));
                SetLayerRecursively(gameObject, PlayerCamera.IgnoreLayer);
                Combatant.Visual.SetOverheadVisible(false);
                Camera = PlayerCamera.Create(transform, Combatant.Visual, config.startInFirstPerson);
                TouchControls.Create();
                HUD.Create();
                StartCoroutine(DropIn());
            }
        }

        public override void OnNetworkDespawn()
        {
            if (Local == this) Local = null;
        }

        [Rpc(SendTo.Server)]
        void ProfileRpc(string playerName, Color color)
        {
            Combatant.DisplayName.Value = Combatant.SafeName(string.IsNullOrWhiteSpace(playerName)
                ? $"Player {OwnerClientId + 1}"
                : playerName);
            Combatant.MainColor.Value = color;
            Combatant.Team.Value = Combatant.TeamHeroes;
            Combatant.MaxHealth.Value = 100;
            Combatant.Health.Value = 100;
        }

        void BuildVisual()
        {
            var color = Combatant.MainColor.Value;
            var skins = new[] { new Color(0.95f, 0.76f, 0.6f), new Color(0.88f, 0.67f, 0.41f), new Color(0.55f, 0.36f, 0.2f) };
            var skin = skins[(int)(OwnerClientId % 3)];
            Combatant.Visual.Build(color, skin, new Color(0.18f, 0.12f, 0.08f), -1, false, "balanced");
            if (IsOwner && Camera != null) Camera.Follow(transform, Combatant.Visual);
            if (IsOwner) Combatant.Visual.SetOverheadVisible(false);
        }

        static void SetLayerRecursively(GameObject go, int layer)
        {
            go.layer = layer;
            foreach (Transform child in go.transform) SetLayerRecursively(child.gameObject, layer);
        }

        /// Wait for the map, then skydive in from high above.
        IEnumerator DropIn()
        {
            while (MatchState.Instance == null || !MatchState.Instance.WorldReady) yield return null;
            var drop = WorldGenerator.Instance.DropPoint(OwnerClientId);
            Combatant.Controller.enabled = false;
            transform.position = drop;
            Combatant.Controller.enabled = true;
            _yaw = Random.Range(0f, 360f);
            _pitch = 20f;
            _gliding = true;
            Combatant.NetGliding.Value = true;
            _ready = true;
            HUD.Instance?.ShowMessage($"Skydiving over {WorldGenerator.Instance.NearestTownName(drop)} — steer to land!", 4f);
            AudioBank.Play2D("dodge_whoosh", 0.8f);
        }

        void Update()
        {
            if (!IsOwner || !_ready) return;
            var input = TouchControls.Instance != null ? TouchControls.Instance.Read() : default;

            if (Combatant.IsDead.Value)
            {
                Spectate(input);
                return;
            }

            // Look
            _yaw += input.Look.x;
            _pitch = Mathf.Clamp(_pitch - input.Look.y, -75f, 80f);

            if (input.ViewPressed) Camera.SetFirstPerson(!Camera.FirstPerson);
            if (input.AimToggled && Weapons.Current.IsGun && !_gliding) _aiming = !_aiming;
            if (!Weapons.Current.IsGun) _aiming = false;

            var stance = Combatant.NetStance.Value;
            if (!_gliding)
            {
                if (input.CrouchPressed) stance = stance == Stance.Crouching ? Stance.Standing : Stance.Crouching;
                if (input.PronePressed) stance = stance == Stance.Prone ? Stance.Standing : Stance.Prone;
                if (input.JumpPressed && stance != Stance.Standing) { stance = Stance.Standing; input.JumpPressed = false; }
                if (stance == Stance.Standing && Combatant.NetStance.Value != Stance.Standing && !HasHeadroom(1.8f))
                    stance = Combatant.NetStance.Value; // something is above us
                if (stance != Combatant.NetStance.Value)
                {
                    Combatant.NetStance.Value = stance;
                    Combatant.ApplyStanceCollider(stance);
                }
            }

            Move(input, stance);
            transform.rotation = Quaternion.Euler(0, _yaw, 0);

            var aimRay = Camera.AimRay();
            var punchYaw = Weapons.Tick(input, aimRay, _aiming);
            if (punchYaw.HasValue) _yaw = Mathf.LerpAngle(_yaw, punchYaw.Value, 0.6f);

            if (Combatant.NetAiming.Value != _aiming) Combatant.NetAiming.Value = _aiming;
            Camera.Apply(_yaw, _pitch, stance, _aiming, Weapons.Current.AimFov, _gliding);

            HandleLoot(input);
            Combatant.WritePose(_yaw, _pitch, new Vector3(Combatant.Controller.velocity.x, 0, Combatant.Controller.velocity.z).magnitude, Combatant.Controller.isGrounded || !_gliding && _wasGrounded);
            HUD.Instance?.SetPlayerState(Combatant, Weapons, _aiming, Camera.FirstPerson);
        }

        bool HasHeadroom(float height)
        {
            var origin = transform.position + Vector3.up * 0.5f;
            return !Physics.SphereCast(origin, 0.3f, Vector3.up, out _, height - 0.6f, PlayerCamera.WorldMask, QueryTriggerInteraction.Ignore);
        }

        void Move(InputFrame input, Stance stance)
        {
            var controller = Combatant.Controller;
            if (!controller.enabled) return;
            var forward = Quaternion.Euler(0, _yaw, 0);
            var wish = forward * new Vector3(input.Move.x, 0, input.Move.y);
            var grounded = controller.isGrounded;

            if (_gliding)
            {
                var height = transform.position.y - WorldGenerator.Instance.HeightAt(transform.position.x, transform.position.z);
                var parachute = height < 55f;
                _verticalVelocity = Mathf.MoveTowards(_verticalVelocity, parachute ? -5f : -24f, 30f * Time.deltaTime);
                var horizontal = wish * (parachute ? 7f : 12f);
                controller.Move((horizontal + Vector3.up * _verticalVelocity) * Time.deltaTime);
                if (controller.isGrounded || height < 1.2f)
                {
                    _gliding = false;
                    Combatant.NetGliding.Value = false;
                    _verticalVelocity = 0;
                    AudioBank.Play2D("land", 1f);
                    Camera.AddShake(0.6f);
                    HUD.Instance?.ShowMessage("Landed! Grab weapons from buildings.", 3f);
                }
                return;
            }

            var sprinting = input.Sprint && stance == Stance.Standing && !_aiming && input.Move.y > 0.3f;
            var speed = stance switch
            {
                Stance.Crouching => 2.3f,
                Stance.Prone => 1.0f,
                _ => sprinting ? 6.6f : 4.3f,
            };
            if (_aiming) speed *= 0.65f;

            if (grounded)
            {
                if (_verticalVelocity < -2f) _verticalVelocity = -2f;
                if (!_wasGrounded) AudioBank.PlayAt("land", transform.position, 0.5f);
                if (input.JumpPressed && stance == Stance.Standing)
                {
                    _verticalVelocity = JumpVelocity;
                    AudioBank.PlayAt("jump", transform.position, 0.5f);
                }
            }
            _verticalVelocity += Gravity * Time.deltaTime;
            controller.Move((wish * speed + Vector3.up * _verticalVelocity) * Time.deltaTime);
            _wasGrounded = grounded;

            if (grounded && wish.sqrMagnitude > 0.01f)
            {
                _stepTimer -= Time.deltaTime * speed;
                if (_stepTimer <= 0)
                {
                    _stepTimer = 2.2f;
                    if (stance == Stance.Standing) AudioBank.PlayAt("footstep", transform.position, sprinting ? 0.5f : 0.3f);
                }
            }
        }

        void HandleLoot(InputFrame input)
        {
            _nearbyLoot = LootItem.Nearest(transform.position, 2.4f);
            if (_nearbyLoot != null && _nearbyLoot.AutoPickup && Vector3.Distance(_nearbyLoot.transform.position, transform.position) < 1.4f)
            {
                Combatant.RequestPickup(_nearbyLoot);
                _nearbyLoot = null;
            }
            var label = _nearbyLoot != null ? $"Pick up {_nearbyLoot.Label}" : null;
            TouchControls.Instance?.SetPickup(label);
            HUD.Instance?.SetPickupPrompt(label != null ? (TouchControls.UseTouch ? label : $"[F] {label}") : null);
            if (_nearbyLoot != null && input.PickupPressed) Combatant.RequestPickup(_nearbyLoot);
        }

        void Spectate(InputFrame input)
        {
            if (_spectating == null || _spectating.IsDead.Value || input.SwitchPressed)
            {
                _spectating = null;
                foreach (var c in Combatant.All)
                    if (c != Combatant && c.IsAlive && c.Team.Value == Combatant.TeamHeroes) { _spectating = c; break; }
                if (_spectating != null)
                {
                    Camera.Follow(_spectating.transform, _spectating.Visual);
                    HUD.Instance?.ShowMessage($"Spectating {_spectating.Name}", 2.5f);
                }
            }
            _yaw += input.Look.x;
            _pitch = Mathf.Clamp(_pitch - input.Look.y, -40f, 70f);
            if (_spectating != null) Camera.Apply(_yaw, _pitch, _spectating.NetStance.Value, false, 60f, false);
            else Camera.Apply(_yaw, Mathf.Max(_pitch, 25f), Stance.Standing, false, 60f, true);
            TouchControls.Instance?.SetPickup(null);
            HUD.Instance?.SetPlayerState(Combatant, Weapons, false, Camera.FirstPerson);
        }

        /// Recoil kicks the view up a little.
        public void Kick(float degrees)
        {
            _pitch = Mathf.Clamp(_pitch - degrees, -75f, 80f);
            _yaw += Random.Range(-degrees, degrees) * 0.3f;
            Camera.AddShake(degrees * 0.05f);
        }
    }
}
