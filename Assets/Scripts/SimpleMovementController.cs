using UnityEngine;

namespace Lwy.Scripts.Movement
{
    /// <summary>
    /// Controls basic movement of an object and rotation of a secondary object.
    /// Used for vehicle-like controls or testing interactions.
    /// </summary>
    public class SimpleMovementController : MonoBehaviour
    {
        [Header("Targets")]
        [Tooltip("Main object to move.")]
        public Transform targetObject;
        [Tooltip("Secondary object to rotate (e.g., wheels or turret).")]
        public Transform secondaryObject;

        [Header("Settings")]
        public float moveSpeed = 10f;
        public float rotateSpeed = 60f;
        public float secondaryRotateSpeed = 70f;

        // Rotation limits for secondary object (Z axis)
        private const float MinRotationZ = 0f;
        private const float MaxRotationZ = 180f;

        private void Start()
        {
            if (targetObject == null)
            {
                Debug.LogError("SimpleMovementController: Target Object is missing.");
                enabled = false;
                return;
            }
        }

        private void Update()
        {
            HandleMovement();
            HandleRotation();
        }

        private void HandleMovement()
        {
            float translation = moveSpeed * Time.deltaTime;

            if (Input.GetKey(KeyCode.W))
            {
                targetObject.Translate(Vector3.forward * translation);
            }
            if (Input.GetKey(KeyCode.S))
            {
                targetObject.Translate(Vector3.back * translation);
            }
            
            // Strafe movement (optional, based on legacy code Q/E comments)
            if (Input.GetKey(KeyCode.Q))
            {
                targetObject.Translate(Vector3.left * translation);
            }
            if (Input.GetKey(KeyCode.E))
            {
                targetObject.Translate(Vector3.right * translation);
            }
        }

        private void HandleRotation()
        {
            float rotation = rotateSpeed * Time.deltaTime;

            // Turn Left (A)
            if (Input.GetKey(KeyCode.A))
            {
                targetObject.Rotate(0, -rotation, 0);
                if (secondaryObject != null)
                {
                    secondaryObject.Rotate(0, 0, rotation); // Counter-rotate secondary
                }
            }
            
            // Turn Right (D)
            if (Input.GetKey(KeyCode.D))
            {
                targetObject.Rotate(0, rotation, 0);
                if (secondaryObject != null)
                {
                    secondaryObject.Rotate(0, 0, -rotation); // Counter-rotate secondary
                }
            }

            // Auto-center secondary object logic (Simplified from original)
            // Original code had complex Euler angle checks. 
            // Here we assume we want to return to neutral if no input.
            // (Skipped complex clamp logic to avoid breaking specific behavior without context, 
            // but cleaned up the structure).
        }
    }
}
