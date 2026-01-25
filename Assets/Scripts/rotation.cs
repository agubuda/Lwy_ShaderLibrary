using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class rotation : MonoBehaviour
{
    // Configurable speeds for each axis
    [Header("Rotation Speeds (Per Frame)")]
    public float speedX = 0f;
    public float speedY = 0.5f;
    public float speedZ = 0f;

    private Quaternion initialRotation;
    private float currentX = 0f;
    private float currentY = 0f;
    private float currentZ = 0f;

    private void Start()
    {
        // Record the initial rotation
        initialRotation = transform.rotation;
    }

    // Update is called once per frame
    private void Update()
    {
        // Accumulate angles based on speed
        currentX += speedX;
        currentY += speedY;
        currentZ += speedZ;

        // Create the rotation offset in World Space
        Quaternion offsetRotation = Quaternion.Euler(currentX, currentY, currentZ);

        // Apply the offset relative to the initial rotation
        // Multiplying on the left applies the rotation in World Space
        transform.rotation = offsetRotation * initialRotation;
    }
}
