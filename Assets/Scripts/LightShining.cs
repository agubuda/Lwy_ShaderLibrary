using UnityEngine;

namespace Lwy.Scripts.Rendering
{
    /// <summary>
    /// Pulses the emission color of a list of materials to simulate a glowing/shining effect.
    /// </summary>
    public class LightShining : MonoBehaviour
    {
        [Header("Targets")]
        [Tooltip("List of materials to animate emission.")]
        [SerializeField] private Material[] materials;

        [Header("Settings")]
        [Tooltip("Base emission color.")]
        public Color baseColor = Color.white;

        [Tooltip("Minimum intensity for the pulse.")]
        public float intensityMin = 0f;
        [Tooltip("Maximum intensity for the pulse.")]
        public float intensityMax = 11f;
        
        [Tooltip("Speed of the pulse.")]
        public float pulseSpeed = 7f;

        private float currentIntensityTime;
        private Color originalColor;

        private void Start()
        {
            originalColor = baseColor;
            // Randomize start time to have different phases if multiple scripts are used
            currentIntensityTime = Random.Range(intensityMin, intensityMax);
        }

        private void Update()
        {
            UpdateEmission();
        }

        private void UpdateEmission()
        {
            if (materials == null || materials.Length == 0) return;

            currentIntensityTime += Time.deltaTime;
            
            // Calculate a pulsing factor using Sine wave
            // Abs ensures it stays positive, though standard sine (-1 to 1) mapped to intensity is also fine.
            // Using logic close to original: Abs(Sin(t)) * speed multiplier
            float intensitySine = Mathf.Abs(Mathf.Sin(currentIntensityTime)) * pulseSpeed;

            // Exponential falloff/boost for more dramatic light effect
            float emissionFactor = Mathf.Pow(2, intensitySine);

            Color finalColor = baseColor * emissionFactor;

            foreach (Material mat in materials)
            {
                if (mat != null)
                {
                    mat.SetColor("_EmissionColor", finalColor);
                    // Enable keyword if necessary for standard shader, though usually SetColor is enough if property matches
                    mat.EnableKeyword("_EMISSION"); 
                }
            }
        }
        
        private void OnDestroy()
        {
            // Optional: Reset color on destroy to avoid persistent changes in Editor
            // foreach (Material mat in materials)
            // {
            //     if (mat != null) mat.SetColor("_EmissionColor", originalColor);
            // }
        }
    }
}
