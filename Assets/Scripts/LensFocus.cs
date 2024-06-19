using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class LensFocus : MonoBehaviour
{
    private DepthOfField dofComponent;
    // Start is called before the first frame update

    public Volume GetVolume;
    public float focusSpeed;

    private void Start()
    {
        DepthOfField tmp;

        if (GetVolume.profile.TryGet<DepthOfField>(out tmp))
        {
            dofComponent = tmp;
        }
    }

    // Update is called once per frame

    private Ray raycast;
    private RaycastHit hit;
    private bool isHit;
    private float hitDistance;

    private void FixedUpdate()
    {
        //set ray of camera

        raycast = new Ray(transform.position, transform.forward * 100);
        isHit = false;
        Debug.DrawRay(transform.position, Vector3.forward, Color.red);

        if (Physics.Raycast(raycast, out hit, 100f))
        {
            isHit = true;
            hitDistance = Vector3.Distance(transform.position, hit.point);
            Debug.Log("hit");
        }
        else
        {
            if (hitDistance < 100f)
            {
                hitDistance++;
            }
        }

        SetFocus();
    }

    private void OnDrawGizmos()
    {
        if (isHit)
        {
            Gizmos.DrawSphere(hit.point, 0.1f);
            Debug.DrawRay(transform.position, transform.forward * Vector3.Distance(transform.position, hit.point));
        }
        else
        {
            Debug.DrawRay(transform.position, transform.forward * 100f);
        }
    }

    private void SetFocus()
    {
        dofComponent.focusDistance.value = Mathf.Lerp(dofComponent.focusDistance.value, hitDistance, Time.deltaTime * focusSpeed);
    }
}