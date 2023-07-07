using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class copyPosition : MonoBehaviour
{
    public GameObject root;
    public Light charLight;

    public Vector3 T;
    // Start is called before the first frame update
    void Start()
    {
        root = GameObject.Find("root");
    }


    // Update is called once per frame
    void Update()
    {
        
        charLight.transform.position = root.transform.position;
        charLight.transform.position += T;
    }
}
