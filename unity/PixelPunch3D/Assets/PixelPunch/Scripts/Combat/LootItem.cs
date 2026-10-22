using System.Collections.Generic;
using Unity.Netcode;
using UnityEngine;

namespace PixelPunch3D
{
    /// <summary>A floating, spinning pickup: weapons, ammo, medkits and armor.</summary>
    public class LootItem : NetworkBehaviour
    {
        public static readonly List<LootItem> All = new();

        public readonly NetworkVariable<LootType> Type = new(LootType.Ammo);

        Transform _visual;
        Vector3 _basePos;
        bool _taken;

        public string Label => LootTable.Label(Type.Value);
        public bool AutoPickup => Type.Value == LootType.Ammo;

        public void ServerSetup(LootType type) => Type.Value = type;

        public override void OnNetworkSpawn()
        {
            All.Add(this);
            _basePos = transform.position;
            BuildVisual();
            Type.OnValueChanged += (_, _) => BuildVisual();
        }

        public override void OnNetworkDespawn() => All.Remove(this);

        void BuildVisual()
        {
            if (_visual != null) Destroy(_visual.gameObject);
            _visual = new GameObject("Visual").transform;
            _visual.SetParent(transform, false);
            var tint = LootTable.Tint(Type.Value);

            // Glowing base ring so loot is easy to spot.
            var ring = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            Destroy(ring.GetComponent<Collider>());
            ring.transform.SetParent(transform, false);
            ring.transform.localPosition = new Vector3(0, -0.3f, 0);
            ring.transform.localScale = new Vector3(0.9f, 0.01f, 0.9f);
            ring.GetComponent<Renderer>().sharedMaterial = Mats.Transparent(new Color(tint.r, tint.g, tint.b, 0.35f));
            ring.transform.SetParent(_visual, true);

            switch (Type.Value)
            {
                case LootType.Ammo:
                    Box(new Vector3(0.35f, 0.22f, 0.25f), tint);
                    Box(new Vector3(0.36f, 0.04f, 0.26f), new Color(0.3f, 0.3f, 0.2f), 0.1f);
                    break;
                case LootType.Medkit:
                    Box(new Vector3(0.38f, 0.26f, 0.16f), Color.white);
                    Box(new Vector3(0.24f, 0.06f, 0.17f), tint);
                    Box(new Vector3(0.06f, 0.2f, 0.17f), tint);
                    break;
                case LootType.Armor:
                    Box(new Vector3(0.4f, 0.45f, 0.14f), tint);
                    break;
                default:
                    var def = Weapons.Get((byte)Type.Value);
                    Box(new Vector3(0.07f, 0.1f, def.Length), def.Color);
                    Box(new Vector3(0.05f, 0.15f, 0.06f), new Color(0.1f, 0.1f, 0.1f), -0.1f, -def.Length * 0.2f);
                    break;
            }
        }

        void Box(Vector3 size, Color color, float y = 0f, float z = 0f)
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Cube);
            Destroy(go.GetComponent<Collider>());
            go.transform.SetParent(_visual, false);
            go.transform.localPosition = new Vector3(0, y, z);
            go.transform.localScale = size;
            go.GetComponent<Renderer>().sharedMaterial = Mats.Color(color, 0.4f);
        }

        void Update()
        {
            if (_visual == null) return;
            _visual.localRotation = Quaternion.Euler(0, Time.time * 70f, 0);
            _visual.localPosition = new Vector3(0, Mathf.Sin(Time.time * 2f + _basePos.x) * 0.08f, 0);
        }

        public static LootItem Nearest(Vector3 position, float maxDistance)
        {
            LootItem best = null;
            var bestDist = maxDistance * maxDistance;
            foreach (var item in All)
            {
                if (item == null || item._taken) continue;
                var d = (item.transform.position - position).sqrMagnitude;
                if (d < bestDist) { bestDist = d; best = item; }
            }
            return best;
        }

        public void ServerTryPickup(Combatant who)
        {
            if (!IsServer || _taken || who == null || who.IsDead.Value) return;
            if (Vector3.Distance(who.transform.position, transform.position) > 3.5f) return;
            _taken = true;
            var amount = Type.Value switch
            {
                LootType.Ammo => 45,
                LootType.Medkit => 50,
                LootType.Armor => 50,
                _ => 1,
            };
            who.ServerGive(Type.Value, amount);
            NetworkObject.Despawn(true);
        }
    }
}
