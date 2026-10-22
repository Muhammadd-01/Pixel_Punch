using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace PixelPunch3D
{
    /// <summary>Helpers to build uGUI screens from code (no prefabs needed).</summary>
    public static class UIFactory
    {
        static Font _font;
        public static Font Font => _font ??= Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");

        public static Canvas Canvas(string name, int sortOrder)
        {
            EnsureEventSystem();
            var go = new GameObject(name, typeof(RectTransform));
            Object.DontDestroyOnLoad(go);
            var canvas = go.AddComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = sortOrder;
            var scaler = go.AddComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1920, 1080);
            scaler.matchWidthOrHeight = 0.5f;
            go.AddComponent<GraphicRaycaster>();
            return canvas;
        }

        public static void EnsureEventSystem()
        {
            if (Object.FindAnyObjectByType<EventSystem>() != null) return;
            var es = new GameObject("EventSystem", typeof(EventSystem), typeof(StandaloneInputModule));
            Object.DontDestroyOnLoad(es);
        }

        public static RectTransform Rect(string name, Transform parent, Vector2 anchorMin, Vector2 anchorMax,
            Vector2 offsetMin = default, Vector2 offsetMax = default)
        {
            var go = new GameObject(name, typeof(RectTransform));
            var rt = (RectTransform)go.transform;
            rt.SetParent(parent, false);
            rt.anchorMin = anchorMin;
            rt.anchorMax = anchorMax;
            rt.offsetMin = offsetMin;
            rt.offsetMax = offsetMax;
            return rt;
        }

        /// Rect anchored at a point with a fixed size.
        public static RectTransform Box(string name, Transform parent, Vector2 anchor, Vector2 position, Vector2 size)
        {
            var rt = Rect(name, parent, anchor, anchor);
            rt.pivot = new Vector2(0.5f, 0.5f);
            rt.anchoredPosition = position;
            rt.sizeDelta = size;
            return rt;
        }

        public static Image Image(Transform parent, Color color, Sprite sprite = null, bool raycast = false)
        {
            var img = parent.gameObject.AddComponent<Image>();
            img.color = color;
            img.sprite = sprite;
            img.raycastTarget = raycast;
            return img;
        }

        public static Text Text(string name, Transform parent, string text, int size, TextAnchor align, Color color)
        {
            var rt = Rect(name, parent, Vector2.zero, Vector2.one);
            var t = rt.gameObject.AddComponent<Text>();
            t.font = Font;
            t.text = text;
            t.fontSize = size;
            t.alignment = align;
            t.color = color;
            t.raycastTarget = false;
            t.horizontalOverflow = HorizontalWrapMode.Wrap;
            t.verticalOverflow = VerticalWrapMode.Overflow;
            var shadow = rt.gameObject.AddComponent<Shadow>();
            shadow.effectColor = new Color(0, 0, 0, 0.7f);
            shadow.effectDistance = new Vector2(2, -2);
            return t;
        }

        public static Button Button(string name, Transform parent, string label, Color color, System.Action onClick, bool round = false)
        {
            var rt = Rect(name, parent, Vector2.zero, Vector2.one);
            var img = Image(rt, color, round ? ProcTex.Sprite(ProcTex.Circle) : null, true);
            img.type = UnityEngine.UI.Image.Type.Simple;
            var button = rt.gameObject.AddComponent<Button>();
            button.targetGraphic = img;
            button.onClick.AddListener(() => onClick());
            Text("Label", rt, label, 34, TextAnchor.MiddleCenter, Color.white);
            return button;
        }
    }
}
