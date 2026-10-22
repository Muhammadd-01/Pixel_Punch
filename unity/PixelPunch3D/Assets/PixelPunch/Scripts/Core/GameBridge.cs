using System;
using System.Collections;
using System.Reflection;
using System.Text;
using UnityEngine;

namespace PixelPunch3D
{
    /// <summary>
    /// Message bridge between Flutter (flutter_unity_widget) and the 3D game.
    ///
    /// Flutter → Unity:  unityController.postMessage("GameBridge", "StartMatch", json)
    ///                   methods: StartMatch, SetView ("tpp"/"fpp"), PauseGame, ResumeGame, QuitMatch
    /// Unity → Flutter:  {"type": "...", "data": {...}} strings via UnityMessageManager.
    ///
    /// The bridge creates itself at startup, so no scene setup is needed. When
    /// the game runs without Flutter (Unity editor / standalone build) it starts
    /// a default offline match after a short wait.
    /// </summary>
    public class GameBridge : MonoBehaviour
    {
        public static GameBridge Instance { get; private set; }
        public static MatchConfig CurrentConfig { get; private set; }

        bool _matchRequested;
        static object _flutterManager;
        static MethodInfo _flutterSend;
        static bool _lookedUpFlutter;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Boot()
        {
            if (Instance != null) return;
            var go = new GameObject("GameBridge");
            go.AddComponent<GameBridge>();
        }

        void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
            gameObject.name = "GameBridge"; // Flutter addresses us by this name.
            DontDestroyOnLoad(gameObject);
            Application.targetFrameRate = 60;
            QualitySettings.vSyncCount = 0;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
        }

        IEnumerator Start()
        {
            Send("unity_ready", "{}");
            // Give Flutter a moment to send the real match config.
            yield return new WaitForSecondsRealtime(!Application.isEditor && IsEmbeddedInFlutter ? 15f : 0.5f);
            if (!_matchRequested)
            {
                Debug.Log("[GameBridge] No config from Flutter, starting default offline match.");
                StartMatch(JsonUtility.ToJson(MatchConfig.EditorDefault()));
            }
        }

        // ------------------------------------------------------------------
        // Flutter → Unity

        public void StartMatch(string json)
        {
            _matchRequested = true;
            MatchConfig config;
            try
            {
                config = MatchConfig.FromJson(json);
            }
            catch (Exception e)
            {
                Debug.LogError($"[GameBridge] Bad match config: {e.Message}");
                SendError("Invalid match settings.");
                return;
            }
            CurrentConfig = config;
            MatchManager.Begin(config);
        }

        public void SetView(string mode)
        {
            var local = PlayerController.Local;
            if (local != null) local.Camera.SetFirstPerson(mode == "fpp");
        }

        public void PauseGame(string _ = "") => AudioListener.pause = true;
        public void ResumeGame(string _ = "") => AudioListener.pause = false;

        public void QuitMatch(string _ = "") => MatchManager.Quit();

        // ------------------------------------------------------------------
        // Unity → Flutter

        public static bool IsEmbeddedInFlutter
        {
            get
            {
                LookUpFlutter();
                return _flutterManager != null;
            }
        }

        /// Sends {"type": type, "data": dataJson} to Flutter (or the console).
        public static void Send(string type, string dataJson)
        {
            var message = $"{{\"type\":\"{type}\",\"data\":{(string.IsNullOrEmpty(dataJson) ? "{}" : dataJson)}}}";
            LookUpFlutter();
            if (_flutterManager != null && _flutterSend != null)
            {
                try
                {
                    _flutterSend.Invoke(_flutterManager, new object[] { message });
                    return;
                }
                catch (Exception e)
                {
                    Debug.LogWarning($"[GameBridge] Flutter send failed: {e.Message}");
                }
            }
            Debug.Log($"[GameBridge → Flutter] {message}");
        }

        public static void SendError(string text) =>
            Send("error", $"{{\"message\":\"{Escape(text)}\"}}");

        public static string Escape(string s)
        {
            if (string.IsNullOrEmpty(s)) return "";
            var sb = new StringBuilder(s.Length + 8);
            foreach (var c in s)
            {
                switch (c)
                {
                    case '"': sb.Append("\\\""); break;
                    case '\\': sb.Append("\\\\"); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': break;
                    default: sb.Append(c); break;
                }
            }
            return sb.ToString();
        }

        /// flutter_unity_widget's UnityMessageManager is looked up by reflection
        /// so this project compiles with or without the Flutter integration.
        static void LookUpFlutter()
        {
            if (_lookedUpFlutter) return;
            _lookedUpFlutter = true;
            foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies())
            {
                var type = assembly.GetType("FlutterUnityIntegration.UnityMessageManager");
                if (type == null) continue;
                var instance = type.GetProperty("Instance", BindingFlags.Public | BindingFlags.Static)?.GetValue(null)
                               ?? FindAnyObjectByType(type);
                // The plugin's manager must live in the scene; add it if missing.
                if (instance == null && typeof(Component).IsAssignableFrom(type) && Instance != null)
                    instance = Instance.gameObject.AddComponent(type);
                var method = type.GetMethod("SendMessageToFlutter", new[] { typeof(string) });
                if (instance != null && method != null)
                {
                    _flutterManager = instance;
                    _flutterSend = method;
                }
                return;
            }
        }
    }
}
