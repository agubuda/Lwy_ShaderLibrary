using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SimpleMovementController : MonoBehaviour
{
    public float speed = 1f;
    public Transform Obj;


    // Update is called once per frame
    private float rotateSpeed = 30f;
    private float movespeed = 5;

    void FixedUpdate()
    {
        //第二种方式控制移动
        if (Input.GetKey(KeyCode.W)) //前进
        {
            transform.Translate(Vector3.forward * movespeed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.S)) //后退
        {
            transform.Translate(Vector3.back * movespeed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.A))//向左旋转
        {
            transform.Rotate(0, -rotateSpeed * Time.deltaTime, 0);
        }
        if (Input.GetKey(KeyCode.D))//向右旋转
　　{
            transform.Rotate(0, rotateSpeed * Time.deltaTime, 0);
        }
    }
}
