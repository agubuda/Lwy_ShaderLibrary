using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Animator))]
public class IKController : MonoBehaviour
{
    protected Animator animator;
    public bool ikActive = false;
    public Transform rightHandObj = null;
    public Transform lookObj = null;

    public float IKPositionWeight = 1.0f;
    public float IKRotationWeight = 0.0f;

    // Start is called before the first frame update
    private void Start()
    {
        animator = GetComponent<Animator>();
    }

    // Update is called once per frame
    private void OnAnimatorIK()
    {
        if (animator)
        {
            if (ikActive)
            {
                if (lookObj != null)
                {
                    animator.SetLookAtWeight(1);
                    animator.SetLookAtPosition(lookObj.position);
                }
                if (lookObj != null)
                {
                    animator.SetIKPositionWeight(AvatarIKGoal.RightHand, IKPositionWeight);
                    animator.SetIKRotationWeight(AvatarIKGoal.RightHand, IKRotationWeight);
                    animator.SetIKPosition(AvatarIKGoal.RightHand, rightHandObj.position);
                    animator.SetIKRotation(AvatarIKGoal.RightHand, rightHandObj.rotation);
                }
            }
            else
            {
                animator.SetIKPositionWeight(AvatarIKGoal.RightHand, 0);
                animator.SetIKRotationWeight(AvatarIKGoal.RightHand, 0);
                animator.SetLookAtWeight(0);
            }
        }
    }
}