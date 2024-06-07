using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Floater : MonoBehaviour
{
    public Rigidbody rigidbody;
    public float depthBeforeSubmerged = 1;
    public float displacementAmount = 3;
    public int floaterCont = 1;
    public float waterDrag = 0.99f;
    public float waterAngularDrag = 0.5f;
    // Start is called before the first frame update
    void Start()
    {
        
    }
    [Range(-1f, 1f)]
    public float waveH = 0;
    void FixedUpdate()
    {
        rigidbody.AddForceAtPosition(Physics.gravity / floaterCont, transform.position, ForceMode.Acceleration);

        waveH = WaterWave.inst.GetPointH(this.transform.position.x, this.transform.position.z);
        if (transform.position.y < waveH)
        {
            float displacementMultiplier = Mathf.Clamp01((waveH - transform.position.y) / depthBeforeSubmerged) * displacementAmount;
            //rigidbody.AddForce(new Vector3(0,Mathf.Abs(Physics.gravity.y) * displacementMultiplier, 0), ForceMode.Acceleration);
            rigidbody.AddForceAtPosition(new Vector3(0,Mathf.Abs(Physics.gravity.y) * displacementMultiplier, 0), transform.position, ForceMode.Acceleration);
            rigidbody.AddForce(displacementMultiplier * -rigidbody.velocity * waterDrag * Time.fixedDeltaTime,ForceMode.VelocityChange);
            rigidbody.AddTorque(displacementMultiplier * -rigidbody.angularVelocity * waterAngularDrag * Time.fixedDeltaTime, ForceMode.VelocityChange);
        }
    }
}
