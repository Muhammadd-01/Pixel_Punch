using System;
using System.Threading.Tasks;
using Unity.Services.Authentication;
using Unity.Services.Core;
using Unity.Services.Multiplayer;
using UnityEngine;

namespace PixelPunch3D
{
    /// <summary>
    /// Online play with friends through Unity Gaming Services: the host creates
    /// a Relay-backed session and gets a short join code; friends join with it.
    /// The Multiplayer SDK starts NetworkManager as host/client by itself.
    /// Requires the Unity project to be linked to a Cloud project
    /// (Edit → Project Settings → Services).
    /// </summary>
    public static class SessionService
    {
        public static ISession Current { get; private set; }

        static async Task EnsureSignedIn(string playerName)
        {
            if (UnityServices.State != ServicesInitializationState.Initialized)
                await UnityServices.InitializeAsync();
            if (!AuthenticationService.Instance.IsSignedIn)
                await AuthenticationService.Instance.SignInAnonymouslyAsync();
            try
            {
                if (!string.IsNullOrWhiteSpace(playerName))
                    await AuthenticationService.Instance.UpdatePlayerNameAsync(SanitizeName(playerName));
            }
            catch (Exception e)
            {
                Debug.LogWarning($"[Session] Could not set player name: {e.Message}");
            }
        }

        /// Creates a session and returns its join code.
        public static async Task<string> HostAsync(int maxPlayers, string playerName)
        {
            await EnsureSignedIn(playerName);
            var options = new SessionOptions
            {
                MaxPlayers = Mathf.Clamp(maxPlayers, 2, 16),
                IsPrivate = true,
            }.WithRelayNetwork();
            var session = await MultiplayerService.Instance.CreateSessionAsync(options);
            Current = session;
            return session.Code;
        }

        public static async Task JoinAsync(string code, string playerName)
        {
            await EnsureSignedIn(playerName);
            Current = await MultiplayerService.Instance.JoinSessionByCodeAsync(code.Trim().ToUpperInvariant());
        }

        public static async Task LeaveAsync()
        {
            var session = Current;
            Current = null;
            if (session == null) return;
            try
            {
                await session.LeaveAsync();
            }
            catch (Exception e)
            {
                Debug.LogWarning($"[Session] Leave failed: {e.Message}");
            }
        }

        // UGS player names allow letters, digits and a few symbols, no spaces.
        static string SanitizeName(string name)
        {
            var chars = name.Trim().Replace(' ', '_').ToCharArray();
            var clean = new System.Text.StringBuilder();
            foreach (var c in chars)
                if (char.IsLetterOrDigit(c) || c == '_' || c == '-') clean.Append(c);
            var result = clean.ToString();
            if (result.Length == 0) result = "Player";
            return result.Length > 30 ? result.Substring(0, 30) : result;
        }
    }
}
