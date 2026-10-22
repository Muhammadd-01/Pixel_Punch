using System;
using System.Threading.Tasks;
using Unity.Netcode;
using UnityEngine;

namespace PixelPunch3D
{
    /// <summary>
    /// Starts and stops matches: networking (offline / online session / LAN),
    /// then hands over to the synced MatchState object.
    /// </summary>
    public class MatchManager : MonoBehaviour
    {
        public static MatchManager Instance { get; private set; }
        public static MatchConfig Config { get; private set; }
        public static bool IsOnline => Config != null && Config.role != "offline";

        public static void Begin(MatchConfig config)
        {
            if (Instance != null) Quit(notifyFlutter: false);
            Config = config;
            var go = new GameObject("MatchManager");
            DontDestroyOnLoad(go);
            Instance = go.AddComponent<MatchManager>();
            Instance.StartNetworking();
        }

        public static void Quit(bool notifyFlutter = true)
        {
            if (Instance == null) return;
            var instance = Instance;
            Instance = null;
            instance.Cleanup();
            Destroy(instance.gameObject);
            if (notifyFlutter) GameBridge.Send("match_closed", "{}");
        }

        async void StartNetworking()
        {
            AudioBank.EnsureCreated();
            LoadingScreen.Show("Preparing the battleground...");
            // A previous match's NetworkManager is destroyed at the end of the
            // frame; wait for it so we never reuse a shutting-down instance.
            var waited = 0f;
            while (NetworkManager.Singleton != null && waited < 3f)
            {
                await Task.Yield();
                waited += Time.unscaledDeltaTime;
            }
            if (this == null) return;
            if (!NetworkRuntime.EnsureCreated())
            {
                LoadingScreen.Hide();
                return;
            }

            var manager = NetworkManager.Singleton;
            manager.OnServerStarted += OnServerStarted;
            manager.OnClientDisconnectCallback += OnClientDisconnected;

            try
            {
                switch (Config.role)
                {
                    case "host":
                        LoadingScreen.Show("Creating your squad session...");
                        var code = await SessionService.HostAsync(Config.maxPlayers, Config.playerName);
                        GameBridge.Send("session_code", $"{{\"code\":\"{GameBridge.Escape(code)}\"}}");
                        break;
                    case "join":
                        LoadingScreen.Show($"Joining squad {Config.joinCode}...");
                        await SessionService.JoinAsync(Config.joinCode, Config.playerName);
                        break;
                    case "lan_join":
                        NetworkRuntime.UseLocal(Config.lanAddress);
                        if (!manager.StartClient()) throw new Exception("Could not start client.");
                        break;
                    case "lan_host":
                        NetworkRuntime.UseLocal("127.0.0.1", "0.0.0.0");
                        if (!manager.StartHost()) throw new Exception("Could not start host.");
                        break;
                    default:
                        NetworkRuntime.UseLocal("127.0.0.1", "127.0.0.1");
                        if (!manager.StartHost()) throw new Exception("Could not start the match.");
                        break;
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[Match] Networking failed: {e}");
                LoadingScreen.Hide();
                GameBridge.SendError(Config.role == "join"
                    ? "Could not join that squad. Check the code and your connection."
                    : $"Could not start the match: {e.Message}");
                Quit();
            }
        }

        void OnServerStarted()
        {
            var stateObject = Instantiate(NetworkRuntime.MatchStatePrefab);
            var state = stateObject.GetComponent<MatchState>();
            state.ServerConfigure(Config);
            stateObject.GetComponent<NetworkObject>().Spawn();
        }

        void OnClientDisconnected(ulong clientId)
        {
            var manager = NetworkManager.Singleton;
            if (manager == null) return;
            if (!manager.IsServer && clientId == manager.LocalClientId)
            {
                GameBridge.Send("disconnected", "{\"reason\":\"Lost connection to the host.\"}");
                HUD.Instance?.ShowMessage("Disconnected from the host", 4f);
            }
        }

        void Cleanup()
        {
            var manager = NetworkManager.Singleton;
            if (manager != null)
            {
                manager.OnServerStarted -= OnServerStarted;
                manager.OnClientDisconnectCallback -= OnClientDisconnected;
            }
            _ = SessionService.LeaveAsync();
            NetworkRuntime.Shutdown();
            WorldGenerator.Clear();
            FaceLibrary.Clear();
            HUD.Teardown();
            TouchControls.Teardown();
            LoadingScreen.Hide();
            AudioBank.StopMusic();
        }

        void OnApplicationQuit() => Cleanup();
    }
}
