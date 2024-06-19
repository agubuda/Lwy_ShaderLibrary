using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class rotation : MonoBehaviour
{
    // Start is called before the first frame update
    private float x = 0;

    private void Start()
    {
    }

    // Update is called once per frame
    private void Update()
    {
        transform.rotation = Quaternion.Euler(0, x += 0.5f, 0);
    }
}