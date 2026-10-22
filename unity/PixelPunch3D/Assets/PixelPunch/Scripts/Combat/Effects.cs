using System.Collections;
using UnityEngine;

namespace PixelPunch3D
{
    /// <summary>Short-lived visual effects: bullet tracers, muzzle flashes, impacts.</summary>
    public class Effects : MonoBehaviour
    {
        static Effects _runner;

        static Effects Runner
        {
            get
            {
                if (_runner != null) return _runner;
                var go = new GameObject("Effects");
                DontDestroyOnLoad(go);
                _runner = go.AddComponent<Effects>();
                return _runner;
            }
        }

        public static void Tracer(Vector3 from, Vector3 to)
        {
            var go = new GameObject("Tracer");
            var line = go.AddComponent<LineRenderer>();
            line.sharedMaterial = Mats.Transparent(new Color(1f, 0.9f, 0.5f, 0.85f));
            line.positionCount = 2;
            line.SetPosition(0, from);
            line.SetPosition(1, to);
            line.startWidth = 0.025f;
            line.endWidth = 0.01f;
            line.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            Runner.StartCoroutine(Fade(go, line, 0.07f));
        }

        public static void MuzzleFlash(Vector3 at)
        {
            var go = new GameObject("Muzzle");
            go.transform.position = at;
            var light = go.AddComponent<Light>();
            light.type = LightType.Point;
            light.color = new Color(1f, 0.8f, 0.4f);
            light.range = 6f;
            light.intensity = 3f;
            var flash = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            Destroy(flash.GetComponent<Collider>());
            flash.transform.SetParent(go.transform, false);
            flash.transform.localScale = Vector3.one * 0.14f;
            flash.GetComponent<Renderer>().sharedMaterial = Mats.Transparent(new Color(1f, 0.85f, 0.4f, 0.9f));
            Destroy(go, 0.05f);
        }

        /// Spark puff where something got hit. Red-ish for characters.
        public static void Impact(Vector3 at, bool flesh)
        {
            for (int i = 0; i < 5; i++)
            {
                var p = GameObject.CreatePrimitive(PrimitiveType.Cube);
                Destroy(p.GetComponent<Collider>());
                p.transform.position = at;
                p.transform.localScale = Vector3.one * Random.Range(0.03f, 0.07f);
                p.GetComponent<Renderer>().sharedMaterial = Mats.Transparent(flesh
                    ? new Color(0.9f, 0.15f, 0.15f, 0.9f)
                    : new Color(0.9f, 0.85f, 0.7f, 0.9f));
                Runner.StartCoroutine(Fly(p.transform, Random.onUnitSphere * Random.Range(1.5f, 3.5f) + Vector3.up, 0.35f));
            }
        }

        /// Expanding ring on the ground, e.g. when landing a heavy punch.
        public static void Shockwave(Vector3 at, Color color)
        {
            var ring = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            Destroy(ring.GetComponent<Collider>());
            ring.transform.position = at + Vector3.up * 0.05f;
            ring.GetComponent<Renderer>().sharedMaterial = Mats.Transparent(color);
            Runner.StartCoroutine(Grow(ring.transform, 0.3f));
        }

        static IEnumerator Fade(GameObject go, LineRenderer line, float duration)
        {
            yield return new WaitForSeconds(duration);
            if (go != null) Destroy(go);
        }

        static IEnumerator Fly(Transform t, Vector3 velocity, float duration)
        {
            var time = 0f;
            while (time < duration && t != null)
            {
                time += Time.deltaTime;
                velocity += Physics.gravity * Time.deltaTime;
                t.position += velocity * Time.deltaTime;
                t.localScale *= 0.96f;
                yield return null;
            }
            if (t != null) Destroy(t.gameObject);
        }

        static IEnumerator Grow(Transform t, float duration)
        {
            var time = 0f;
            while (time < duration && t != null)
            {
                time += Time.deltaTime;
                var s = Mathf.Lerp(0.2f, 3f, time / duration);
                t.localScale = new Vector3(s, 0.01f, s);
                yield return null;
            }
            if (t != null) Destroy(t.gameObject);
        }
    }
}
