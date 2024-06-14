using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SimpleMovementController : MonoBehaviour
{
    public float speed = 100f;
    public Transform Obj;


    private float rotateSpeed = 30f;
    private float movespeed = 5;
    private bool up = false; 

    public void MoveForward()
    {
        //transform.Translate(Vector3.forward * speed * Time.deltaTime);
        up = true;
    }
    public void StopMoveForward()
    {
        //transform.Translate(Vector3.forward * speed * Time.deltaTime);
        up = false;
    }
    void FixedUpdate()
    {
        if (up) {
            transform.Translate(Vector3.forward * speed * Time.deltaTime);
        }
        //第二种方式控制移动
        if (Input.GetKey(KeyCode.W)) //前进
        {
            transform.Translate(Vector3.forward * speed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.S)) //后退
        {
            transform.Translate(Vector3.back * speed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.A)) //前进
        {
            transform.Rotate(0, -rotateSpeed * Time.deltaTime, 0);
            //transform.Translate(Vector3.left * speed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.D)) //后退
        {
            transform.Rotate(0, rotateSpeed * Time.deltaTime, 0);
            //transform.Translate(Vector3.right * speed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.Q))//左平移
        {
            transform.Translate(Vector3.left * speed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.E))//右平移
        {
            transform.Translate(Vector3.right * speed * Time.deltaTime);
        }
    }
}
