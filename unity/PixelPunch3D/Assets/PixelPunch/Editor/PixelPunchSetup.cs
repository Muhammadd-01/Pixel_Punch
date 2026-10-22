using System.IO;
using Unity.Netcode;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

namespace PixelPunch3D.EditorTools
{
    /// <summary>
    /// One-click project setup: creates the network prefabs, the boot scene,
    /// build settings and player settings. Runs automatically the first time
    /// the project is opened; re-run any time from PixelPunch → Setup Project.
    /// </summary>
    [InitializeOnLoad]
    public static class PixelPunchSetup
    {
        const string NetFolder = "Assets/PixelPunch/Resources/Net";
        const string ScenePath = "Assets/Scenes/Main.unity";

        static PixelPunchSetup()
        {
            EditorApplication.delayCall += () =>
            {
                if (!File.Exists($"{NetFolder}/NetPlayer.prefab") && !Application.isBatchMode)
                    Setup();
            };
        }

        [MenuItem("PixelPunch/Setup Project")]
        public static void Setup()
        {
            Directory.CreateDirectory(NetFolder);
            Directory.CreateDirectory("Assets/Scenes");

            SavePrefab("NetPlayer", go =>
            {
                ConfigureController(go.AddComponent<CharacterController>());
                go.AddComponent<NetworkObject>();
                go.AddComponent<Combatant>();
                go.AddComponent<CharacterVisual>();
                go.AddComponent<WeaponSystem>();
                go.AddComponent<PlayerController>();
            });
            SavePrefab("NetVillain", go =>
            {
                ConfigureController(go.AddComponent<CharacterController>());
                go.AddComponent<NetworkObject>();
                go.AddComponent<Combatant>();
                go.AddComponent<CharacterVisual>();
                go.AddComponent<WeaponSystem>();
                go.AddComponent<VillainNet>();
            });
            SavePrefab("NetLoot", go =>
            {
                go.AddComponent<NetworkObject>();
                go.AddComponent<LootItem>();
            });
            SavePrefab("NetMatchState", go =>
            {
                go.AddComponent<NetworkObject>();
                go.AddComponent<MatchState>();
            });

            CreateScene();
            ConfigurePlayer();
            AlwaysIncludeShaders("Standard", "Nature/Terrain/Standard", "Sprites/Default");
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log("[PixelPunch] Setup complete. Press Play to start a test match.");
            if (!Application.isBatchMode)
                EditorUtility.DisplayDialog("PixelPunch Royale",
                    "Setup complete!\n\nPress Play to start an offline test match (WASD + mouse, click to capture the mouse).\n\n" +
                    "For online squads, link this project to Unity Gaming Services (Edit → Project Settings → Services).",
                    "Let's go");
        }

        static void ConfigureController(CharacterController cc)
        {
            cc.height = 1.8f;
            cc.radius = 0.38f;
            cc.center = new Vector3(0, 0.9f, 0);
            cc.stepOffset = 0.45f;
            cc.slopeLimit = 50f;
            cc.skinWidth = 0.05f;
        }

        static void SavePrefab(string name, System.Action<GameObject> build)
        {
            var go = new GameObject(name);
            build(go);
            PrefabUtility.SaveAsPrefabAsset(go, $"{NetFolder}/{name}.prefab");
            Object.DestroyImmediate(go);
        }

        static void CreateScene()
        {
            if (File.Exists(ScenePath)) return;
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var cam = new GameObject("Main Camera") { tag = "MainCamera" };
            var camera = cam.AddComponent<Camera>();
            camera.clearFlags = CameraClearFlags.Skybox;
            camera.transform.position = new Vector3(800, 160, 300);
            camera.transform.rotation = Quaternion.Euler(25, 0, 0);
            cam.AddComponent<AudioListener>();
            var sun = new GameObject("Sun").AddComponent<Light>();
            sun.type = LightType.Directional;
            sun.intensity = 1.15f;
            sun.shadows = LightShadows.Soft;
            sun.transform.rotation = Quaternion.Euler(48f, -35f, 0);
            EditorSceneManager.SaveScene(scene, ScenePath);
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
        }

        static void ConfigurePlayer()
        {
            PlayerSettings.companyName = "NexoVate";
            PlayerSettings.productName = "PixelPunch Royale";
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.AutoRotation;
            PlayerSettings.allowedAutorotateToPortrait = false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = true;
            PlayerSettings.allowedAutorotateToLandscapeRight = true;
            PlayerSettings.SetApplicationIdentifier(UnityEditor.Build.NamedBuildTarget.Android, "com.nexovate.pixelpunch.royale");
            PlayerSettings.SetApplicationIdentifier(UnityEditor.Build.NamedBuildTarget.iOS, "com.nexovate.pixelpunch.royale");
            PlayerSettings.SetScriptingBackend(UnityEditor.Build.NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARMv7 | AndroidArchitecture.ARM64;
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel26;
            // flutter_unity_widget_2 extends UnityPlayerActivity, which Unity only
            // exports with the classic Activity entry point (not GameActivity).
            PlayerSettings.Android.applicationEntry = AndroidApplicationEntry.Activity;
            PlayerSettings.runInBackground = true;
        }

        static void AlwaysIncludeShaders(params string[] names)
        {
            var settings = AssetDatabase.LoadAssetAtPath<Object>("ProjectSettings/GraphicsSettings.asset");
            if (settings == null) return;
            var so = new SerializedObject(settings);
            var list = so.FindProperty("m_AlwaysIncludedShaders");
            foreach (var name in names)
            {
                var shader = Shader.Find(name);
                if (shader == null) continue;
                var present = false;
                for (int i = 0; i < list.arraySize; i++)
                    if (list.GetArrayElementAtIndex(i).objectReferenceValue == shader) present = true;
                if (present) continue;
                list.InsertArrayElementAtIndex(list.arraySize);
                list.GetArrayElementAtIndex(list.arraySize - 1).objectReferenceValue = shader;
            }
            so.ApplyModifiedProperties();
        }
    }
}
