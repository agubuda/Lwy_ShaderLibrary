using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Lwy.Scripts.Rendering
{
    /// <summary>
    /// Adjusts the DepthOfField focus distance based on a raycast from the camera.
    /// Simulates an autofocus camera lens.
    /// </summary>
    public class LensFocus : MonoBehaviour
    {
        [Header("Settings")]
        public Volume targetVolume;
        public float focusSpeed = 5f;
        public float maxFocusDistance = 100f;
        public LayerMask hitLayers = -1; // Default to Everything

        private DepthOfField dofComponent;
        private float currentHitDistance;
        private bool isHit;
        private RaycastHit rayHit;

        private void Start()
        {
            if (targetVolume == null)
            {
                Debug.LogError("LensFocus: Target Volume is not assigned.");
                enabled = false;
                return;
            }

            if (targetVolume.profile.TryGet(out DepthOfField dof))
            {
                dofComponent = dof;
            }
            else
            {
                Debug.LogWarning("LensFocus: DepthOfField override not found in the assigned Volume profile.");
            }
        }

        private void FixedUpdate()
        {
            PerformRaycast();
            UpdateFocus();
        }

        private void PerformRaycast()
        {
            Ray ray = new Ray(transform.position, transform.forward);
            
            if (Physics.Raycast(ray, out rayHit, maxFocusDistance, hitLayers))
            {
                isHit = true;
                currentHitDistance = Vector3.Distance(transform.position, rayHit.point);
            }
            else
            {
                isHit = false;
                // If nothing hit, focus smoothly towards max distance (or infinity)
                if (currentHitDistance < maxFocusDistance)
                {
                    currentHitDistance = Mathf.MoveTowards(currentHitDistance, maxFocusDistance, 1f); // Slowly drift out
                }
            }
        }

        private void UpdateFocus()
        {
            if (dofComponent != null)
            {
                float currentFocus = dofComponent.focusDistance.value;
                dofComponent.focusDistance.value = Mathf.Lerp(currentFocus, currentHitDistance, Time.deltaTime * focusSpeed);
            }
        }

        private void OnDrawGizmos()
        {
            Gizmos.color = isHit ? Color.green : Color.red;
            
            if (isHit)
            {
                Gizmos.DrawLine(transform.position, rayHit.point);
                Gizmos.DrawSphere(rayHit.point, 0.1f);
            }
            else
            {
                Gizmos.DrawRay(transform.position, transform.forward * maxFocusDistance);
            }
        }
    }
}
