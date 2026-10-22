using UnityEngine;

namespace PixelPunch3D
{
    /// <summary>
    /// Third-person over-the-shoulder camera with wall collision, and a
    /// first-person camera at the eyes. Aiming zooms in (weapon-specific FOV).
    /// </summary>
    public class PlayerCamera : MonoBehaviour
    {
        public Camera Cam { get; private set; }
        public bool FirstPerson { get; private set; }

        Transform _target;
        CharacterVisual _visual;
        float _currentDistance = 3f;
        float _shake;
        float _fov = 65f;

        public const int IgnoreLayer = 2; // "Ignore Raycast": the local player's own colliders
        public static int WorldMask => ~(1 << IgnoreLayer);

        public static PlayerCamera Create(Transform target, CharacterVisual visual, bool firstPerson)
        {
            var cam = Camera.main;
            if (cam == null)
            {
                var go = new GameObject("Main Camera") { tag = "MainCamera" };
                cam = go.AddComponent<Camera>();
                go.AddComponent<AudioListener>();
            }
            cam.nearClipPlane = 0.05f;
            cam.farClipPlane = 750f;
            cam.fieldOfView = 65f;
            var rig = cam.gameObject.GetComponent<PlayerCamera>();
            if (rig == null) rig = cam.gameObject.AddComponent<PlayerCamera>();
            rig.Cam = cam;
            rig._target = target;
            rig._visual = visual;
            rig.SetFirstPerson(firstPerson);
            return rig;
        }

        public void Follow(Transform target, CharacterVisual visual)
        {
            if (_visual != null) _visual.SetHeadVisible(true);
            _target = target;
            _visual = visual;
            SetFirstPerson(FirstPerson);
        }

        public void SetFirstPerson(bool on)
        {
            FirstPerson = on;
            if (_visual != null) _visual.SetHeadVisible(!on);
            HUD.Instance?.ShowMessage(on ? "First-person view" : "Third-person view", 1.2f);
        }

        public void AddShake(float amount) => _shake = Mathf.Max(_shake, amount);

        /// Called by PlayerController every frame after it moves.
        public void Apply(float yaw, float pitch, Stance stance, bool aiming, float aimFov, bool gliding)
        {
            if (_target == null || Cam == null) return;
            var rot = Quaternion.Euler(pitch, yaw, 0);
            var eye = Combatant.EyeHeight(stance);
            var targetFov = aiming ? aimFov : (gliding ? 75f : 65f);
            _fov = Mathf.Lerp(_fov, targetFov, 1f - Mathf.Exp(-12f * Time.deltaTime));
            Cam.fieldOfView = _fov;

            Vector3 position;
            if (FirstPerson && !gliding)
            {
                var head = _visual != null && _visual.Head != null ? _visual.Head.position : _target.position + Vector3.up * eye;
                position = head + rot * new Vector3(0, 0.05f, 0.12f);
            }
            else
            {
                var pivot = _target.position + Vector3.up * (stance == Stance.Prone ? 0.9f : eye + 0.1f);
                var desired = gliding ? 6f : aiming ? 1.7f : stance == Stance.Prone ? 2.4f : 3.1f;
                var offset = rot * new Vector3(aiming ? 0.65f : 0.55f, 0.12f, 0);
                var start = pivot + offset;
                var dir = rot * Vector3.back;
                var dist = desired;
                if (Physics.SphereCast(start, 0.2f, dir, out var hit, desired, WorldMask, QueryTriggerInteraction.Ignore))
                    dist = Mathf.Max(0.3f, hit.distance - 0.05f);
                _currentDistance = dist < _currentDistance ? dist : Mathf.Lerp(_currentDistance, dist, 1f - Mathf.Exp(-6f * Time.deltaTime));
                position = start + dir * _currentDistance;
            }

            if (_shake > 0)
            {
                _shake = Mathf.MoveTowards(_shake, 0, Time.deltaTime * 2.5f);
                position += Random.insideUnitSphere * _shake * 0.08f;
            }
            Cam.transform.SetPositionAndRotation(position, rot);
        }

        /// Ray from the screen centre; starts past the player in third person
        /// so nothing between the camera and the player blocks shots.
        public Ray AimRay()
        {
            var t = Cam.transform;
            var start = t.position;
            if (!FirstPerson && _target != null)
            {
                var along = Vector3.Dot(_target.position + Vector3.up * 1.2f - start, t.forward);
                start += t.forward * Mathf.Max(0, along);
            }
            return new Ray(start, t.forward);
        }
    }
}
