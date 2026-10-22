using UnityEngine;
using UnityEngine.UI;

namespace PixelPunch3D
{
    /// <summary>Full-screen "building the map / connecting" overlay.</summary>
    public class LoadingScreen : MonoBehaviour
    {
        static LoadingScreen _instance;
        Canvas _canvas;
        Text _text;
        RectTransform _spinner;

        public static void Show(string message)
        {
            if (_instance == null)
            {
                var go = new GameObject("LoadingScreen");
                DontDestroyOnLoad(go);
                _instance = go.AddComponent<LoadingScreen>();
                _instance.Build();
            }
            _instance._text.text = message;
        }

        public static void Hide()
        {
            if (_instance == null) return;
            if (_instance._canvas != null) Destroy(_instance._canvas.gameObject);
            Destroy(_instance.gameObject);
            _instance = null;
        }

        void Build()
        {
            _canvas = UIFactory.Canvas("LoadingCanvas", 100);
            var bg = UIFactory.Rect("Bg", _canvas.transform, Vector2.zero, Vector2.one);
            UIFactory.Image(bg, new Color(0.06f, 0.07f, 0.13f, 1f), null, true);
            var title = UIFactory.Box("Title", _canvas.transform, new Vector2(0.5f, 0.5f), new Vector2(0, 170), new Vector2(1200, 120));
            UIFactory.Text("T", title, "PIXELPUNCH ROYALE", 86, TextAnchor.MiddleCenter, new Color(1f, 0.42f, 0.21f));
            _spinner = UIFactory.Box("Spinner", _canvas.transform, new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(150, 150));
            UIFactory.Image(_spinner, new Color(1f, 0.75f, 0.1f), ProcTex.Sprite(ProcTex.Ring));
            var dot = UIFactory.Box("Dot", _spinner, new Vector2(0.5f, 1f), new Vector2(0, -6), new Vector2(26, 26));
            UIFactory.Image(dot, new Color(1f, 0.42f, 0.21f), ProcTex.Sprite(ProcTex.Circle));
            var text = UIFactory.Box("Text", _canvas.transform, new Vector2(0.5f, 0.5f), new Vector2(0, -150), new Vector2(1200, 60));
            _text = UIFactory.Text("T", text, "", 36, TextAnchor.MiddleCenter, Color.white);
            var tip = UIFactory.Box("Tip", _canvas.transform, new Vector2(0.5f, 0f), new Vector2(0, 90), new Vector2(1500, 60));
            UIFactory.Text("T", tip, "Tip: punches chain into a 3-hit combo — the final hook hits hardest!", 28, TextAnchor.MiddleCenter, new Color(1, 1, 1, 0.6f));
        }

        void Update()
        {
            if (_spinner != null) _spinner.Rotate(0, 0, -240f * Time.unscaledDeltaTime);
        }
    }

    /// <summary>Victory / defeat summary with buttons back to Flutter.</summary>
    public class ResultsScreen : MonoBehaviour
    {
        static ResultsScreen _instance;
        Canvas _canvas;

        public static void Show(bool victory, int kills, int damage, int seconds)
        {
            if (_instance != null) return;
            var go = new GameObject("Results");
            DontDestroyOnLoad(go);
            _instance = go.AddComponent<ResultsScreen>();
            _instance.Build(victory, kills, damage, seconds);
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
        }

        public static void Hide()
        {
            if (_instance == null) return;
            if (_instance._canvas != null) Destroy(_instance._canvas.gameObject);
            Destroy(_instance.gameObject);
            _instance = null;
        }

        void Build(bool victory, int kills, int damage, int seconds)
        {
            _canvas = UIFactory.Canvas("ResultsCanvas", 50);
            var bg = UIFactory.Rect("Bg", _canvas.transform, Vector2.zero, Vector2.one);
            UIFactory.Image(bg, new Color(0, 0, 0, 0.72f), null, true);
            var accent = victory ? new Color(1f, 0.78f, 0.1f) : new Color(1f, 0.33f, 0.3f);

            var title = UIFactory.Box("Title", _canvas.transform, new Vector2(0.5f, 0.5f), new Vector2(0, 230), new Vector2(1400, 140));
            UIFactory.Text("T", title, victory ? "WINNER WINNER, VILLAIN DINNER!" : "SQUAD ELIMINATED", 76, TextAnchor.MiddleCenter, accent);
            var sub = UIFactory.Box("Sub", _canvas.transform, new Vector2(0.5f, 0.5f), new Vector2(0, 140), new Vector2(1400, 60));
            UIFactory.Text("T", sub, victory ? "Every villain on the island has been knocked out." : "The villains win this round. Regroup and try again!", 32, TextAnchor.MiddleCenter, Color.white);

            var stats = UIFactory.Box("Stats", _canvas.transform, new Vector2(0.5f, 0.5f), new Vector2(0, 20), new Vector2(1100, 120));
            UIFactory.Text("T", stats, $"KNOCKOUTS  {kills}        DAMAGE  {damage}        TIME  {seconds / 60}:{seconds % 60:00}", 40, TextAnchor.MiddleCenter, new Color(0.85f, 0.95f, 1f));

            var menu = UIFactory.Box("Menu", _canvas.transform, new Vector2(0.5f, 0.5f), new Vector2(MatchManager.IsOnline ? 0 : -220, -170), new Vector2(380, 100));
            UIFactory.Button("Btn", menu, "BACK TO MENU", new Color(0.2f, 0.3f, 0.55f, 0.95f), () =>
            {
                GameBridge.Send("exit_requested", "{}");
                Hide();
                MatchManager.Quit();
            });

            if (!MatchManager.IsOnline)
            {
                var again = UIFactory.Box("Again", _canvas.transform, new Vector2(0.5f, 0.5f), new Vector2(220, -170), new Vector2(380, 100));
                UIFactory.Button("Btn", again, "PLAY AGAIN", new Color(1f, 0.42f, 0.21f, 0.95f), () =>
                {
                    var config = MatchManager.Config;
                    config.seed = Random.Range(1, int.MaxValue);
                    Hide();
                    MatchManager.Begin(config);
                });
            }
        }
    }
}
