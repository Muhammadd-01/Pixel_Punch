using System.Collections.Generic;
using UnityEngine;

namespace PixelPunch3D
{
    /// <summary>
    /// A jointed 3D humanoid built from primitives, animated procedurally from
    /// the synced Combatant state: walk/run cycles, crouch, prone crawl, jump,
    /// skydive, boxing guard + 3-hit punch combo, gun holding, hit flash and
    /// knock-out. Villains get horns, a cape and their own face on the head.
    /// </summary>
    public class CharacterVisual : MonoBehaviour
    {
        public Transform Hips, Spine, Neck, Head, ShoulderL, ShoulderR, ElbowL, ElbowR, HandL, HandR,
            HipL, HipR, KneeL, KneeR;
        public Transform Muzzle { get; private set; }

        Combatant _combatant;
        readonly List<Renderer> _bodyRenderers = new();
        readonly List<Renderer> _headRenderers = new();
        MaterialPropertyBlock _flashBlock;
        Transform _weaponRoot;
        WeaponId _shownWeapon = (WeaponId)255;
        bool _built;
        bool _hideHead;

        float _phase;
        float _punchTimer = 1f;
        int _punchStep;
        float _recoil;
        float _flash;
        float _deathT = -1f;
        Vector3 _lastPos;
        float _localSpeed;

        // Overhead info
        TextMesh _nameText;
        Transform _healthFill;
        Transform _overhead;
        TextMesh _bubbleText;
        Transform _bubble;
        float _bubbleTime;

        readonly Dictionary<Transform, Quaternion> _target = new();

        void Awake()
        {
            _combatant = GetComponent<Combatant>();
            _flashBlock = new MaterialPropertyBlock();
        }

        // ------------------------------------------------------------------
        // Construction

        public void Build(Color main, Color skin, Color hair, int facePhotoIndex, bool villain, string archetype)
        {
            if (_built) ClearRig();
            _built = true;

            var root = new GameObject("Rig").transform;
            root.SetParent(transform, false);

            var shirt = Mats.Unique(main);
            var shirtDark = Mats.Unique(main * 0.65f + new Color(0, 0, 0, 1));
            var skinMat = Mats.Unique(skin);
            var pants = Mats.Color(villain ? new Color(0.12f, 0.1f, 0.14f) : new Color(0.16f, 0.2f, 0.3f));
            var shoes = Mats.Color(new Color(0.08f, 0.08f, 0.08f));
            var gloves = villain ? skinMat : Mats.Color(new Color(0.85f, 0.12f, 0.12f), 0.4f);

            Hips = Joint("Hips", root, new Vector3(0, 0.95f, 0));
            Spine = Joint("Spine", Hips, new Vector3(0, 0.08f, 0));
            Part(PrimitiveType.Cube, Spine, new Vector3(0, 0.28f, 0), new Vector3(0.44f, 0.56f, 0.26f), shirt);
            Part(PrimitiveType.Cube, Spine, new Vector3(0, 0.02f, 0), new Vector3(0.42f, 0.12f, 0.24f), shirtDark); // belt
            Neck = Joint("Neck", Spine, new Vector3(0, 0.6f, 0));
            Part(PrimitiveType.Cylinder, Neck, new Vector3(0, 0.04f, 0), new Vector3(0.1f, 0.05f, 0.1f), skinMat);
            Head = Joint("Head", Neck, new Vector3(0, 0.17f, 0.01f));

            var headGo = new GameObject("Face");
            headGo.transform.SetParent(Head, false);
            headGo.transform.localScale = new Vector3(0.25f, 0.29f, 0.26f);
            headGo.AddComponent<MeshFilter>().sharedMesh = FaceLibrary.HeadMesh;
            var headRenderer = headGo.AddComponent<MeshRenderer>();
            headRenderer.sharedMaterial = Mats.Unique(Color.white, FaceLibrary.HeadTexture(facePhotoIndex, skin, hair, villain));
            _headRenderers.Add(headRenderer);

            var hairGo = new GameObject("Hair");
            hairGo.transform.SetParent(Head, false);
            hairGo.transform.localPosition = new Vector3(0, 0.012f, -0.008f);
            hairGo.transform.localScale = new Vector3(0.265f, 0.3f, 0.27f);
            hairGo.AddComponent<MeshFilter>().sharedMesh = FaceLibrary.HairMesh;
            var hairRenderer = hairGo.AddComponent<MeshRenderer>();
            hairRenderer.sharedMaterial = Mats.Unique(hair);
            _headRenderers.Add(hairRenderer);

            if (villain)
            {
                var hornMat = Mats.Color(new Color(0.18f, 0.08f, 0.1f), 0.5f);
                foreach (var side in new[] { -1f, 1f })
                {
                    var horn = Part(PrimitiveType.Capsule, Head, new Vector3(0.09f * side, 0.15f, -0.01f), new Vector3(0.045f, 0.08f, 0.045f), hornMat);
                    horn.localRotation = Quaternion.Euler(0, 0, -28f * side);
                    _headRenderers.Add(horn.GetComponent<Renderer>());
                }
                var cape = Part(PrimitiveType.Cube, Spine, new Vector3(0, 0.12f, -0.16f), new Vector3(0.5f, 0.95f, 0.03f), shirtDark);
                cape.localRotation = Quaternion.Euler(8f, 0, 0);
                if (archetype == "tank")
                    Part(PrimitiveType.Cube, Spine, new Vector3(0, 0.32f, 0.14f), new Vector3(0.36f, 0.38f, 0.04f), Mats.Color(new Color(0.6f, 0.62f, 0.66f), 0.6f));
            }
            else
            {
                // Hero headband in team colour.
                var band = Part(PrimitiveType.Cylinder, Head, new Vector3(0, 0.06f, 0), new Vector3(0.27f, 0.025f, 0.28f), shirt);
                _headRenderers.Add(band.GetComponent<Renderer>());
            }

            BuildArm(-1, out ShoulderL, out ElbowL, out HandL, shirt, skinMat, gloves);
            BuildArm(1, out ShoulderR, out ElbowR, out HandR, shirt, skinMat, gloves);
            BuildLeg(-1, out HipL, out KneeL, pants, shoes);
            BuildLeg(1, out HipR, out KneeR, pants, shoes);

            foreach (var r in root.GetComponentsInChildren<Renderer>())
            {
                if (!_headRenderers.Contains(r)) _bodyRenderers.Add(r);
                r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
            }
            BuildOverhead();
            _shownWeapon = (WeaponId)255;
            SetHeadVisible(!_hideHead);
            _lastPos = transform.position;
        }

        void BuildArm(int side, out Transform shoulder, out Transform elbow, out Transform hand, Material sleeve, Material skin, Material glove)
        {
            shoulder = Joint(side < 0 ? "ShoulderL" : "ShoulderR", Spine, new Vector3(0.28f * side, 0.5f, 0));
            Part(PrimitiveType.Sphere, shoulder, Vector3.zero, Vector3.one * 0.15f, sleeve);
            Part(PrimitiveType.Capsule, shoulder, new Vector3(0, -0.15f, 0), new Vector3(0.11f, 0.15f, 0.11f), sleeve);
            elbow = Joint(side < 0 ? "ElbowL" : "ElbowR", shoulder, new Vector3(0, -0.3f, 0));
            Part(PrimitiveType.Capsule, elbow, new Vector3(0, -0.13f, 0), new Vector3(0.095f, 0.13f, 0.095f), skin);
            hand = Joint(side < 0 ? "HandL" : "HandR", elbow, new Vector3(0, -0.28f, 0));
            Part(PrimitiveType.Sphere, hand, Vector3.zero, new Vector3(0.13f, 0.12f, 0.14f), glove);
        }

        void BuildLeg(int side, out Transform hip, out Transform knee, Material pants, Material shoes)
        {
            hip = Joint(side < 0 ? "HipL" : "HipR", Hips, new Vector3(0.11f * side, -0.04f, 0));
            Part(PrimitiveType.Capsule, hip, new Vector3(0, -0.22f, 0), new Vector3(0.16f, 0.23f, 0.16f), pants);
            knee = Joint(side < 0 ? "KneeL" : "KneeR", hip, new Vector3(0, -0.45f, 0));
            Part(PrimitiveType.Capsule, knee, new Vector3(0, -0.2f, 0), new Vector3(0.13f, 0.21f, 0.13f), pants);
            Part(PrimitiveType.Cube, knee, new Vector3(0, -0.43f, 0.05f), new Vector3(0.13f, 0.09f, 0.26f), shoes);
        }

        static Transform Joint(string name, Transform parent, Vector3 localPos)
        {
            var t = new GameObject(name).transform;
            t.SetParent(parent, false);
            t.localPosition = localPos;
            return t;
        }

        static Transform Part(PrimitiveType type, Transform parent, Vector3 localPos, Vector3 scale, Material mat)
        {
            var go = GameObject.CreatePrimitive(type);
            Object.Destroy(go.GetComponent<Collider>());
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localScale = scale;
            go.GetComponent<Renderer>().sharedMaterial = mat;
            return go.transform;
        }

        void ClearRig()
        {
            var rig = transform.Find("Rig");
            if (rig != null) Destroy(rig.gameObject);
            if (_overhead != null) Destroy(_overhead.gameObject);
            _bodyRenderers.Clear();
            _headRenderers.Clear();
            _target.Clear();
            _weaponRoot = null;
        }

        void BuildOverhead()
        {
            var font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            _overhead = new GameObject("Overhead").transform;
            _overhead.SetParent(transform, false);
            _overhead.localPosition = new Vector3(0, 2.15f, 0);

            var nameGo = new GameObject("Name");
            nameGo.transform.SetParent(_overhead, false);
            _nameText = nameGo.AddComponent<TextMesh>();
            _nameText.font = font;
            _nameText.fontSize = 48;
            _nameText.characterSize = 0.02f;
            _nameText.anchor = TextAnchor.LowerCenter;
            _nameText.alignment = TextAlignment.Center;
            nameGo.GetComponent<MeshRenderer>().sharedMaterial = font.material;
            nameGo.transform.localPosition = new Vector3(0, 0.08f, 0);

            var back = Part(PrimitiveType.Cube, _overhead, Vector3.zero, new Vector3(0.62f, 0.07f, 0.01f), Mats.Color(new Color(0.1f, 0.1f, 0.1f)));
            back.GetComponent<Renderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            var fillPivot = new GameObject("FillPivot").transform;
            fillPivot.SetParent(_overhead, false);
            fillPivot.localPosition = new Vector3(-0.3f, 0, -0.008f);
            var fill = Part(PrimitiveType.Cube, fillPivot, new Vector3(0.3f, 0, 0), new Vector3(0.6f, 0.05f, 0.01f), Mats.Color(new Color(0.3f, 0.85f, 0.35f)));
            fill.GetComponent<Renderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            _healthFill = fillPivot;

            _bubble = new GameObject("Bubble").transform;
            _bubble.SetParent(_overhead, false);
            _bubble.localPosition = new Vector3(0, 0.45f, 0);
            var bubbleTextGo = new GameObject("BubbleText");
            bubbleTextGo.transform.SetParent(_bubble, false);
            _bubbleText = bubbleTextGo.AddComponent<TextMesh>();
            _bubbleText.font = font;
            _bubbleText.fontSize = 40;
            _bubbleText.characterSize = 0.022f;
            _bubbleText.color = new Color(1f, 0.92f, 0.4f);
            _bubbleText.anchor = TextAnchor.LowerCenter;
            _bubbleText.alignment = TextAlignment.Center;
            bubbleTextGo.GetComponent<MeshRenderer>().sharedMaterial = font.material;
            _bubble.gameObject.SetActive(false);
        }

        // ------------------------------------------------------------------
        // Public events

        public void SetHeadVisible(bool visible)
        {
            _hideHead = !visible;
            foreach (var r in _headRenderers)
                if (r != null) r.shadowCastingMode = visible
                    ? UnityEngine.Rendering.ShadowCastingMode.On
                    : UnityEngine.Rendering.ShadowCastingMode.ShadowsOnly;
        }

        public void SetOverheadVisible(bool visible)
        {
            if (_overhead != null) _overhead.gameObject.SetActive(visible);
        }

        public void PlayPunch(int step)
        {
            _punchStep = step;
            _punchTimer = 0f;
        }

        public float PunchDuration(int step) => step == 2 ? 0.42f : 0.26f;

        public void PlayRecoil() => _recoil = 1f;
        public void FlashHit() => _flash = 0.1f;
        public void PlayDeath() => _deathT = 0f;

        public void Say(string text)
        {
            if (_bubble == null || string.IsNullOrEmpty(text)) return;
            _bubbleText.text = Wrap(text, 26);
            _bubble.gameObject.SetActive(true);
            _bubbleTime = 3.2f;
        }

        static string Wrap(string text, int width)
        {
            var words = text.Split(' ');
            var sb = new System.Text.StringBuilder();
            var line = 0;
            foreach (var w in words)
            {
                if (line + w.Length > width && line > 0) { sb.Append('\n'); line = 0; }
                else if (line > 0) { sb.Append(' '); line++; }
                sb.Append(w);
                line += w.Length;
            }
            return sb.ToString();
        }

        void ShowWeapon(WeaponId id)
        {
            if (_shownWeapon == id || HandR == null) return;
            _shownWeapon = id;
            if (_weaponRoot != null) Destroy(_weaponRoot.gameObject);
            _weaponRoot = null;
            Muzzle = HandR;
            if (id == WeaponId.Fists) return;

            var def = Weapons.Get(id);
            _weaponRoot = new GameObject("Weapon").transform;
            _weaponRoot.SetParent(HandR, false);
            _weaponRoot.localRotation = Quaternion.Euler(90f, 0, 0); // +Z along the pointing arm
            _weaponRoot.localPosition = new Vector3(0, -0.02f, 0);
            var metal = Mats.Color(def.Color, 0.45f);
            var dark = Mats.Color(new Color(0.08f, 0.08f, 0.09f), 0.3f);
            var len = def.Length;
            Part(PrimitiveType.Cube, _weaponRoot, new Vector3(0, 0.04f, len * 0.35f), new Vector3(0.06f, 0.09f, len * 0.75f), metal);
            var barrel = Part(PrimitiveType.Cylinder, _weaponRoot, new Vector3(0, 0.06f, len * 0.8f), new Vector3(0.03f, len * 0.25f, 0.03f), dark);
            barrel.localRotation = Quaternion.Euler(90f, 0, 0);
            Part(PrimitiveType.Cube, _weaponRoot, new Vector3(0, -0.04f, 0.0f), new Vector3(0.05f, 0.12f, 0.06f), dark); // grip
            if (id != WeaponId.Pistol)
            {
                Part(PrimitiveType.Cube, _weaponRoot, new Vector3(0, 0.02f, -len * 0.25f), new Vector3(0.05f, 0.1f, len * 0.35f), metal); // stock
                Part(PrimitiveType.Cube, _weaponRoot, new Vector3(0, -0.06f, len * 0.3f), new Vector3(0.045f, 0.13f, 0.06f), dark); // magazine
            }
            if (id == WeaponId.Sniper)
            {
                var scope = Part(PrimitiveType.Cylinder, _weaponRoot, new Vector3(0, 0.13f, len * 0.35f), new Vector3(0.05f, 0.12f, 0.05f), dark);
                scope.localRotation = Quaternion.Euler(90f, 0, 0);
            }
            Muzzle = new GameObject("Muzzle").transform;
            Muzzle.SetParent(_weaponRoot, false);
            Muzzle.localPosition = new Vector3(0, 0.06f, len * 1.05f);
            foreach (var r in _weaponRoot.GetComponentsInChildren<Renderer>()) _bodyRenderers.Add(r);
        }

        // ------------------------------------------------------------------
        // Animation

        void Update()
        {
            if (!_built || _combatant == null) return;
            var dt = Time.deltaTime;

            // Speed: replicated for remotes, measured for locally simulated.
            var moved = transform.position - _lastPos;
            moved.y = 0;
            _lastPos = transform.position;
            _localSpeed = Mathf.Lerp(_localSpeed, dt > 0 ? moved.magnitude / dt : 0, 1f - Mathf.Exp(-10f * dt));
            var speed = Mathf.Min(_localSpeed, 9f);

            var stance = _combatant.NetStance.Value;
            var grounded = _combatant.NetGrounded.Value;
            var gliding = _combatant.NetGliding.Value;
            var aiming = _combatant.NetAiming.Value;
            var weapon = (WeaponId)_combatant.NetWeapon.Value;
            var pitch = _combatant.NetPitch.Value;
            ShowWeapon(weapon);

            _phase += dt * (speed > 0.2f ? 2.2f + speed * 1.1f : 0f) * (stance == Stance.Prone ? 0.5f : 1f);
            _punchTimer += dt;
            _recoil = Mathf.MoveTowards(_recoil, 0, dt * 8f);

            var s = Mathf.Sin(_phase);
            var c = Mathf.Cos(_phase);
            var walk = Mathf.Clamp01(speed / 4f);
            var run = Mathf.Clamp01((speed - 4f) / 3f);

            var hipsPos = new Vector3(0, 0.95f - Mathf.Abs(c) * 0.03f * walk, 0);
            var hipsRot = Vector3.zero;
            var spine = new Vector3(4f * walk + 8f * run, 0, 0);
            var neck = Vector3.zero;
            float legAmp = 32f * walk + 12f * run;
            var thighL = new Vector3(-s * legAmp, 0, 0);
            var thighR = new Vector3(s * legAmp, 0, 0);
            var kneeL = new Vector3(Mathf.Max(0, c) * (40f * walk + 30f * run) + 4f, 0, 0);
            var kneeR = new Vector3(Mathf.Max(0, -c) * (40f * walk + 30f * run) + 4f, 0, 0);

            // Arms default: relaxed swing.
            var armAmp = 28f * walk + 25f * run;
            var shL = new Vector3(s * armAmp, 0, 6f);
            var shR = new Vector3(-s * armAmp, 0, -6f);
            var elL = new Vector3(-10f - 25f * run, 0, 0);
            var elR = new Vector3(-10f - 25f * run, 0, 0);

            var holdingGun = weapon != WeaponId.Fists;
            if (holdingGun)
            {
                var aimPitch = Mathf.Clamp(pitch, -60f, 60f);
                shR = new Vector3(-82f + aimPitch - _recoil * 12f, 8f, -6f);
                elR = new Vector3(-4f, 0, 0);
                shL = new Vector3(-70f + aimPitch, -28f, 34f);
                elL = new Vector3(-38f, 0, 0);
                spine.y = 0;
                if (!aiming) { shR.x += 25f; shL.x += 25f; }
            }
            else
            {
                // Boxing guard.
                var guard = grounded && !gliding ? 1f : 0f;
                shL = Vector3.Lerp(shL, new Vector3(-42f, 0, 18f), guard * 0.85f);
                shR = Vector3.Lerp(shR, new Vector3(-42f, 0, -18f), guard * 0.85f);
                elL = Vector3.Lerp(elL, new Vector3(-118f, 0, 0), guard * 0.85f);
                elR = Vector3.Lerp(elR, new Vector3(-118f, 0, 0), guard * 0.85f);

                var dur = PunchDuration(_punchStep);
                if (_punchTimer < dur)
                {
                    var t = _punchTimer / dur;
                    var ext = Mathf.Sin(Mathf.Clamp01(t) * Mathf.PI);
                    switch (_punchStep)
                    {
                        case 0: // jab (left)
                            shL = Vector3.Lerp(shL, new Vector3(-88f, 0, 4f), ext);
                            elL = Vector3.Lerp(elL, new Vector3(-4f, 0, 0), ext);
                            spine.y = 14f * ext;
                            break;
                        case 1: // cross (right)
                            shR = Vector3.Lerp(shR, new Vector3(-88f, 0, -4f), ext);
                            elR = Vector3.Lerp(elR, new Vector3(-4f, 0, 0), ext);
                            spine.y = -22f * ext;
                            break;
                        default: // hook (right, sweeping)
                            shR = new Vector3(-80f, 0, Mathf.Lerp(45f, -40f, Mathf.Clamp01(t * 1.4f)));
                            elR = new Vector3(-75f, 0, 0);
                            spine.y = Mathf.Lerp(25f, -35f, t);
                            hipsRot.y = Mathf.Lerp(10f, -15f, t);
                            break;
                    }
                }
            }

            if (stance == Stance.Crouching)
            {
                hipsPos.y = 0.62f;
                spine.x += 18f;
                thighL = new Vector3(-72f + thighL.x * 0.4f, 0, -6f);
                thighR = new Vector3(-62f + thighR.x * 0.4f, 0, 6f);
                kneeL = new Vector3(118f, 0, 0);
                kneeR = new Vector3(108f, 0, 0);
            }
            else if (stance == Stance.Prone)
            {
                hipsPos.y = 0.2f;
                hipsRot.x = 88f;
                neck.x = -62f;
                spine.x = -6f;
                var crawl = speed > 0.2f ? s * 18f : 0f;
                thighL = new Vector3(crawl, 0, -8f);
                thighR = new Vector3(-crawl, 0, 8f);
                kneeL = new Vector3(Mathf.Max(0, crawl), 0, 0);
                kneeR = new Vector3(Mathf.Max(0, -crawl), 0, 0);
                if (holdingGun)
                {
                    shR = new Vector3(-170f + pitch * 0.5f, 0, -8f);
                    shL = new Vector3(-160f + pitch * 0.5f, 0, 18f);
                }
                else
                {
                    shL = new Vector3(-150f - crawl, 0, 20f);
                    shR = new Vector3(-150f + crawl, 0, -20f);
                    elL = elR = new Vector3(-30f, 0, 0);
                }
            }

            if (gliding)
            {
                hipsRot.x = 72f;
                neck.x = -55f;
                shL = new Vector3(-20f, 0, 75f);
                shR = new Vector3(-20f, 0, -75f);
                elL = elR = new Vector3(-20f, 0, 0);
                thighL = new Vector3(10f, 0, -18f);
                thighR = new Vector3(10f, 0, 18f);
                kneeL = kneeR = new Vector3(30f, 0, 0);
            }
            else if (!grounded)
            {
                thighL = new Vector3(-38f, 0, 0);
                thighR = new Vector3(-12f, 0, 0);
                kneeL = new Vector3(70f, 0, 0);
                kneeR = new Vector3(40f, 0, 0);
            }

            // Look up/down with the head when not prone.
            if (stance != Stance.Prone && !gliding) neck.x += Mathf.Clamp(pitch, -50f, 50f) * 0.5f;

            if (_deathT >= 0f)
            {
                _deathT += dt;
                var t = Mathf.Clamp01(_deathT / 0.6f);
                hipsPos.y = Mathf.Lerp(0.95f, 0.18f, t);
                hipsRot = new Vector3(Mathf.Lerp(0, -88f, t), 0, 0);
                shL = new Vector3(-150f, 0, 40f);
                shR = new Vector3(-150f, 0, -40f);
                elL = elR = Vector3.zero;
                thighL = new Vector3(0, 0, -10f);
                thighR = new Vector3(0, 0, 10f);
                kneeL = kneeR = new Vector3(10f, 0, 0);
                neck = new Vector3(10f, 25f, 0);
            }

            var k = 1f - Mathf.Exp(-18f * dt);
            Hips.localPosition = Vector3.Lerp(Hips.localPosition, hipsPos, k);
            Pose(Hips, hipsRot, k);
            Pose(Spine, spine, k);
            Pose(Neck, neck, k);
            Pose(ShoulderL, shL, k * 1.4f);
            Pose(ShoulderR, shR, k * 1.4f);
            Pose(ElbowL, elL, k * 1.4f);
            Pose(ElbowR, elR, k * 1.4f);
            Pose(HipL, thighL, k);
            Pose(HipR, thighR, k);
            Pose(KneeL, kneeL, k);
            Pose(KneeR, kneeR, k);

            UpdateFlash(dt);
            UpdateOverhead(dt);
        }

        static void Pose(Transform joint, Vector3 euler, float k)
        {
            joint.localRotation = Quaternion.Slerp(joint.localRotation, Quaternion.Euler(euler), Mathf.Clamp01(k));
        }

        void UpdateFlash(float dt)
        {
            if (_flash <= 0) return;
            _flash -= dt;
            if (_flash > 0)
            {
                _flashBlock.SetColor("_Color", new Color(1f, 0.45f, 0.45f));
                _flashBlock.SetColor("_BaseColor", new Color(1f, 0.45f, 0.45f));
                foreach (var r in _bodyRenderers) if (r != null) r.SetPropertyBlock(_flashBlock);
            }
            else
            {
                foreach (var r in _bodyRenderers) if (r != null) r.SetPropertyBlock(null);
            }
        }

        void UpdateOverhead(float dt)
        {
            if (_overhead == null) return;
            var cam = Camera.main;
            if (cam != null)
            {
                _overhead.rotation = Quaternion.LookRotation(_overhead.position - cam.transform.position);
                var dist = Vector3.Distance(cam.transform.position, _overhead.position);
                _overhead.localScale = Vector3.one * Mathf.Clamp(dist / 12f, 0.8f, 3.5f);
                // Names of far-away enemies stay hidden (no wall-hack).
                var showBar = dist < (_combatant.Team.Value == Combatant.TeamHeroes ? 400f : 60f);
                _overhead.GetChild(0).gameObject.SetActive(showBar);
            }
            var dead = _combatant.IsDead.Value;
            if (dead && _bubbleTime <= 0) { _overhead.gameObject.SetActive(false); return; }
            _nameText.text = _combatant.Name;
            _nameText.color = _combatant.Team.Value == Combatant.TeamHeroes ? new Color(0.5f, 1f, 0.6f) : new Color(1f, 0.55f, 0.5f);
            var pct = _combatant.MaxHealth.Value > 0 ? Mathf.Clamp01(_combatant.Health.Value / _combatant.MaxHealth.Value) : 0f;
            _healthFill.localScale = new Vector3(Mathf.Max(0.001f, pct), 1, 1);

            if (_bubbleTime > 0)
            {
                _bubbleTime -= dt;
                if (_bubbleTime <= 0) _bubble.gameObject.SetActive(false);
            }
        }
    }
}
