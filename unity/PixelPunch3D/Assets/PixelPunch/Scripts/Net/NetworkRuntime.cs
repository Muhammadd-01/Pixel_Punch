using Unity.Netcode;
using Unity.Netcode.Transports.UTP;
using UnityEngine;

namespace PixelPunch3D
{
    /// <summary>
    /// Builds the NetworkManager at runtime and registers the network prefabs
    /// that "PixelPunch → Setup Project" saved under Resources/Net.
    /// </summary>
    public static class NetworkRuntime
    {
        public const ushort Port = 7777;

        public static GameObject PlayerPrefab { get; private set; }
        public static GameObject VillainPrefab { get; private set; }
        public static GameObject LootPrefab { get; private set; }
        public static GameObject MatchStatePrefab { get; private set; }

        public static NetworkManager Manager => NetworkManager.Singleton;
        public static UnityTransport Transport { get; private set; }

        public static bool EnsureCreated()
        {
            if (NetworkManager.Singleton != null) return true;

            PlayerPrefab = Resources.Load<GameObject>("Net/NetPlayer");
            VillainPrefab = Resources.Load<GameObject>("Net/NetVillain");
            LootPrefab = Resources.Load<GameObject>("Net/NetLoot");
            MatchStatePrefab = Resources.Load<GameObject>("Net/NetMatchState");
            if (PlayerPrefab == null || VillainPrefab == null || LootPrefab == null || MatchStatePrefab == null)
            {
                Debug.LogError("[PixelPunch] Network prefabs missing. In Unity run the menu: PixelPunch → Setup Project.");
                GameBridge.SendError("Game files are incomplete. Run PixelPunch → Setup Project in Unity.");
                return false;
            }

            var go = new GameObject("NetworkManager");
            Object.DontDestroyOnLoad(go);
            Transport = go.AddComponent<UnityTransport>();
            var manager = go.AddComponent<NetworkManager>();
            manager.NetworkConfig = new NetworkConfig
            {
                NetworkTransport = Transport,
                PlayerPrefab = PlayerPrefab,
                ConnectionApproval = false,
                EnableSceneManagement = false,
                TickRate = 30,
            };
            manager.AddNetworkPrefab(PlayerPrefab);
            manager.AddNetworkPrefab(VillainPrefab);
            manager.AddNetworkPrefab(LootPrefab);
            manager.AddNetworkPrefab(MatchStatePrefab);
            return NetworkManager.Singleton != null;
        }

        public static void UseLocal(string address = "127.0.0.1", string listen = "0.0.0.0")
        {
            Transport.SetConnectionData(address, Port, listen);
        }

        public static void Shutdown()
        {
            var manager = NetworkManager.Singleton;
            if (manager == null) return;
            if (manager.IsListening) manager.Shutdown();
            Object.Destroy(manager.gameObject);
        }
    }
}
