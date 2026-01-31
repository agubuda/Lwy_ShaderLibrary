using UnityEngine;

namespace Lwy.Scripts.Animation
{
    /// <summary>
    /// Controls Inverse Kinematics (IK) for a humanoid Animator.
    /// Allows setting right hand position/rotation and look-at target.
    /// </summary>
    [RequireComponent(typeof(Animator))]
    public class IKController : MonoBehaviour
    {
        [Header("Settings")]
        [Tooltip("Enable or disable IK processing.")]
        public bool ikActive = false;

        [Header("Targets")]
        [Tooltip("The target object for the right hand to reach.")]
        public Transform rightHandObj = null;
        [Tooltip("The target object for the character to look at.")]
        public Transform lookObj = null;

        [Header("Weights")]
        [Range(0, 1)]
        public float ikPositionWeight = 1.0f;
        [Range(0, 1)]
        public float ikRotationWeight = 0.0f;
        [Range(0, 1)]
        public float lookAtWeight = 1.0f;

        private Animator animator;

        private void Start()
        {
            animator = GetComponent<Animator>();
        }

        private void OnAnimatorIK(int layerIndex)
        {
            if (animator == null) return;

            if (ikActive)
            {
                // Look At IK
                if (lookObj != null)
                {
                    animator.SetLookAtWeight(lookAtWeight);
                    animator.SetLookAtPosition(lookObj.position);
                }

                // Right Hand IK
                if (rightHandObj != null)
                {
                    animator.SetIKPositionWeight(AvatarIKGoal.RightHand, ikPositionWeight);
                    animator.SetIKRotationWeight(AvatarIKGoal.RightHand, ikRotationWeight);
                    animator.SetIKPosition(AvatarIKGoal.RightHand, rightHandObj.position);
                    animator.SetIKRotation(AvatarIKGoal.RightHand, rightHandObj.rotation);
                }
            }
            else
            {
                // Reset weights when IK is inactive
                animator.SetIKPositionWeight(AvatarIKGoal.RightHand, 0);
                animator.SetIKRotationWeight(AvatarIKGoal.RightHand, 0);
                animator.SetLookAtWeight(0);
            }
        }
    }
}
