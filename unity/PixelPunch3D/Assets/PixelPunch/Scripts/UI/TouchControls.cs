using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace PixelPunch3D
{
    /// <summary>One frame of player intent, merged from touch and keyboard/mouse.</summary>
    public struct InputFrame
    {
        public Vector2 Move;
        public Vector2 Look;      // degrees this frame
        public bool Sprint;
        public bool JumpPressed;
        public bool CrouchPressed;
        public bool PronePressed;
        public bool FireHeld;
        public bool FirePressed;
        public bool ReloadPressed;
        public bool AimToggled;
        public bool SwitchPressed;
        public bool ViewPressed;
        public bool PickupPressed;
    }

    /// <summary>
    /// Mobile controls: floating move stick (left), drag-to-look (right),
    /// and buttons for fire/punch, aim, jump, crouch, prone, reload, switch,
    /// pickup and TPP/FPP view. Keyboard + mouse work alongside on desktop.
    /// </summary>
    public class TouchControls : MonoBehaviour
    {
        public static TouchControls Instance { get; private set; }
        public static float LookSensitivity = 0.16f;
        public static float MouseSensitivity = 2.2f;

        Canvas _canvas;
        Stick _stick;
        LookPad _look;
        readonly Dictionary<string, HoldButton> _buttons = new();
        Text _fireLabel;
        GameObject _pickupButton;
        Text _pickupLabel;

        public static void Create()
        {
            if (Instance != null) return;
            var go = new GameObject("TouchControls");
            DontDestroyOnLoad(go);
            Instance = go.AddComponent<TouchControls>();
            Instance.Build();
        }

        public static void Teardown()
        {
            if (Instance == null) return;
            if (Instance._canvas != null) Destroy(Instance._canvas.gameObject);
            Destroy(Instance.gameObject);
            Instance = null;
        }

        public static bool UseTouch => Application.isMobilePlatform || Input.touchSupported;

        void Build()
        {
            _canvas = UIFactory.Canvas("ControlsCanvas", 10);
            var root = _canvas.transform;

            // Look pad first so buttons sit on top of it.
            var lookRect = UIFactory.Rect("LookPad", root, new Vector2(0.4f, 0f), new Vector2(1f, 0.85f));
            UIFactory.Image(lookRect, new Color(0, 0, 0, 0), null, true);
            _look = lookRect.gameObject.AddComponent<LookPad>();

            var stickArea = UIFactory.Rect("StickArea", root, new Vector2(0f, 0f), new Vector2(0.4f, 0.75f));
            UIFactory.Image(stickArea, new Color(0, 0, 0, 0), null, true);
            _stick = stickArea.gameObject.AddComponent<Stick>();
            _stick.Build();

            Btn("fire", "PUNCH", new Vector2(1, 0), new Vector2(-170, 190), 170, new Color(0.95f, 0.35f, 0.2f, 0.55f), out _fireLabel);
            Btn("fire2", "FIRE", new Vector2(0, 0.5f), new Vector2(110, 120), 110, new Color(0.95f, 0.35f, 0.2f, 0.4f), out _);
            Btn("aim", "AIM", new Vector2(1, 0), new Vector2(-350, 140), 110, new Color(0.2f, 0.6f, 0.95f, 0.45f), out _);
            Btn("jump", "JUMP", new Vector2(1, 0), new Vector2(-110, 380), 110, new Color(0.3f, 0.85f, 0.4f, 0.45f), out _);
            Btn("crouch", "CROUCH", new Vector2(1, 0), new Vector2(-260, 330), 100, new Color(0.6f, 0.6f, 0.65f, 0.45f), out _);
            Btn("prone", "PRONE", new Vector2(1, 0), new Vector2(-380, 300), 100, new Color(0.6f, 0.6f, 0.65f, 0.45f), out _);
            Btn("reload", "RELOAD", new Vector2(1, 0), new Vector2(-470, 110), 100, new Color(0.95f, 0.75f, 0.2f, 0.45f), out _);
            Btn("switch", "SWAP", new Vector2(1, 1), new Vector2(-120, -330), 100, new Color(0.7f, 0.5f, 0.95f, 0.45f), out _);
            Btn("view", "TPP/FPP", new Vector2(1, 1), new Vector2(-250, -330), 100, new Color(0.3f, 0.3f, 0.35f, 0.5f), out _);
            _pickupButton = Btn("pickup", "PICK UP", new Vector2(0.5f, 0), new Vector2(260, 260), 130, new Color(0.95f, 0.85f, 0.3f, 0.6f), out _pickupLabel).gameObject;
            _pickupButton.SetActive(false);

            _canvas.gameObject.SetActive(UseTouch);
        }

        HoldButton Btn(string id, string label, Vector2 anchor, Vector2 pos, float size, Color color, out Text text)
        {
            var rt = UIFactory.Box(id, _canvas.transform, anchor, pos, new Vector2(size, size));
            UIFactory.Image(rt, color, ProcTex.Sprite(ProcTex.Circle), true);
            text = UIFactory.Text("Label", rt, label, size > 120 ? 32 : 22, TextAnchor.MiddleCenter, Color.white);
            var b = rt.gameObject.AddComponent<HoldButton>();
            _buttons[id] = b;
            return b;
        }

        public void SetFireLabel(string label)
        {
            if (_fireLabel != null) _fireLabel.text = label;
        }

        public void SetPickup(string label)
        {
            if (_pickupButton == null) return;
            var show = UseTouch && !string.IsNullOrEmpty(label);
            if (_pickupButton.activeSelf != show) _pickupButton.SetActive(show);
            if (show) _pickupLabel.text = label;
        }

        bool Pressed(string id) => _buttons.TryGetValue(id, out var b) && b.ConsumePress();
        bool Held(string id) => _buttons.TryGetValue(id, out var b) && b.Held;

        /// Builds this frame's input from touch + keyboard/mouse.
        public InputFrame Read()
        {
            var f = new InputFrame();

            // Touch
            if (UseTouch && _canvas.gameObject.activeSelf)
            {
                f.Move = _stick.Value;
                f.Sprint = _stick.Value.magnitude > 0.95f && _stick.Value.y > 0.6f;
                f.Look = _look.ConsumeDelta() * LookSensitivity;
                f.FireHeld = Held("fire") || Held("fire2");
                f.FirePressed = Pressed("fire") | Pressed("fire2");
                f.AimToggled = Pressed("aim");
                f.JumpPressed = Pressed("jump");
                f.CrouchPressed = Pressed("crouch");
                f.PronePressed = Pressed("prone");
                f.ReloadPressed = Pressed("reload");
                f.SwitchPressed = Pressed("switch");
                f.ViewPressed = Pressed("view");
                f.PickupPressed = Pressed("pickup");
            }

            // Keyboard + mouse
            var key = new Vector2(
                (Input.GetKey(KeyCode.D) ? 1 : 0) - (Input.GetKey(KeyCode.A) ? 1 : 0),
                (Input.GetKey(KeyCode.W) ? 1 : 0) - (Input.GetKey(KeyCode.S) ? 1 : 0));
            if (key.sqrMagnitude > 0) f.Move = Vector2.ClampMagnitude(key, 1f);
            if (Input.GetKey(KeyCode.LeftShift)) f.Sprint = true;
            if (Cursor.lockState == CursorLockMode.Locked)
                f.Look += new Vector2(Input.GetAxisRaw("Mouse X"), Input.GetAxisRaw("Mouse Y")) * MouseSensitivity;
            if (Input.GetMouseButton(0) && Cursor.lockState == CursorLockMode.Locked) f.FireHeld = true;
            if (Input.GetMouseButtonDown(0) && Cursor.lockState == CursorLockMode.Locked) f.FirePressed = true;
            if (Input.GetMouseButtonDown(1)) f.AimToggled = true;
            if (Input.GetKeyDown(KeyCode.Space)) f.JumpPressed = true;
            if (Input.GetKeyDown(KeyCode.C) || Input.GetKeyDown(KeyCode.LeftControl)) f.CrouchPressed = true;
            if (Input.GetKeyDown(KeyCode.Z)) f.PronePressed = true;
            if (Input.GetKeyDown(KeyCode.R)) f.ReloadPressed = true;
            if (Input.GetKeyDown(KeyCode.Alpha1) || Input.GetKeyDown(KeyCode.Alpha2) || Input.GetKeyDown(KeyCode.Q) ||
                Mathf.Abs(Input.mouseScrollDelta.y) > 0.1f) f.SwitchPressed = true;
            if (Input.GetKeyDown(KeyCode.V)) f.ViewPressed = true;
            if (Input.GetKeyDown(KeyCode.F) || Input.GetKeyDown(KeyCode.E)) f.PickupPressed = true;

            // Desktop: click to capture the mouse, Esc to release it.
            if (!UseTouch)
            {
                if (Input.GetMouseButtonDown(0) && Cursor.lockState != CursorLockMode.Locked)
                {
                    Cursor.lockState = CursorLockMode.Locked;
                    Cursor.visible = false;
                }
                if (Input.GetKeyDown(KeyCode.Escape))
                {
                    Cursor.lockState = CursorLockMode.None;
                    Cursor.visible = true;
                }
            }
            return f;
        }

        void OnDestroy()
        {
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
        }

        // ------------------------------------------------------------------

        class HoldButton : MonoBehaviour, IPointerDownHandler, IPointerUpHandler
        {
            public bool Held { get; private set; }
            bool _pressed;

            public void OnPointerDown(PointerEventData e)
            {
                Held = true;
                _pressed = true;
                transform.localScale = Vector3.one * 0.92f;
            }

            public void OnPointerUp(PointerEventData e) => Release();

            void Release()
            {
                Held = false;
                transform.localScale = Vector3.one;
            }

            public bool ConsumePress()
            {
                var p = _pressed;
                _pressed = false;
                return p;
            }

            void OnDisable() => Release();
        }

        class Stick : MonoBehaviour, IPointerDownHandler, IDragHandler, IPointerUpHandler
        {
            public Vector2 Value { get; private set; }
            RectTransform _base, _knob, _area;
            Vector2 _home;
            const float Radius = 110f;

            public void Build()
            {
                _area = (RectTransform)transform;
                _base = UIFactory.Box("Base", transform, new Vector2(0, 0), new Vector2(250, 250), new Vector2(Radius * 2, Radius * 2));
                UIFactory.Image(_base, new Color(1, 1, 1, 0.15f), ProcTex.Sprite(ProcTex.Ring));
                _knob = UIFactory.Box("Knob", _base, new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(100, 100));
                UIFactory.Image(_knob, new Color(1, 1, 1, 0.45f), ProcTex.Sprite(ProcTex.Circle));
                _home = _base.anchoredPosition;
            }

            public void OnPointerDown(PointerEventData e)
            {
                if (RectTransformUtility.ScreenPointToLocalPointInRectangle(_area, e.position, e.pressEventCamera, out var local))
                {
                    // Floating stick: centre it where the thumb lands.
                    var size = _area.rect.size;
                    _base.anchoredPosition = local + size * _area.pivot;
                }
                OnDrag(e);
            }

            public void OnDrag(PointerEventData e)
            {
                if (!RectTransformUtility.ScreenPointToLocalPointInRectangle(_base, e.position, e.pressEventCamera, out var local)) return;
                var v = Vector2.ClampMagnitude(local, Radius);
                _knob.anchoredPosition = v;
                var value = v / Radius;
                Value = value.magnitude < 0.12f ? Vector2.zero : value;
            }

            public void OnPointerUp(PointerEventData e)
            {
                Value = Vector2.zero;
                _knob.anchoredPosition = Vector2.zero;
                _base.anchoredPosition = _home;
            }
        }

        class LookPad : MonoBehaviour, IDragHandler
        {
            Vector2 _delta;
            public void OnDrag(PointerEventData e) => _delta += e.delta;

            public Vector2 ConsumeDelta()
            {
                var d = _delta;
                _delta = Vector2.zero;
                return d;
            }
        }
    }
}
