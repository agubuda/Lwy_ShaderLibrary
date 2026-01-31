using UnityEngine;

namespace Lwy.Scripts.Movement
{
    /// <summary>
    /// Rotates the object continuously around its axes.
    /// </summary>
    public class ObjectRotator : MonoBehaviour
    {
        [Header("Rotation Speeds (Degrees per Second)")]
        [Tooltip("Rotation speed around X axis.")]
        public float speedX = 0f;
        [Tooltip("Rotation speed around Y axis.")]
        public float speedY = 30f; // Adjusted default to be visible per second
        [Tooltip("Rotation speed around Z axis.")]
        public float speedZ = 0f;

        [Header("Settings")]
        [Tooltip("If true, rotates in World Space. If false, rotates in Local Space.")]
        public bool useWorldSpace = false;

        private void Update()
        {
            // Calculate rotation for this frame
            Vector3 rotationVector = new Vector3(speedX, speedY, speedZ) * Time.deltaTime;

            // Apply rotation
            transform.Rotate(rotationVector, useWorldSpace ? Space.World : Space.Self);
        }
    }
}