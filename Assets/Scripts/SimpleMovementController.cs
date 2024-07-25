using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SimpleMovementController : MonoBehaviour
{
    public float speed = 10f;
    public Transform Obj;
    public Transform Obj2;

    public float rotateSpeed = 60f;
    public float rightSpeed = 70f;
    private bool left = false;
    private bool right = false;
    private float rollValue = 0;

    private Vector3 T = new Vector3(0f, 0f, 0f);

    public void MoveLeft()
    {
        left = true;
    }

    public void StopMoveLeft()
    {
        left = false;
    }

    public void MoveRight()
    {
        right = true;
    }

    public void StopMoveRight()
    {
        right = false;
    }

    private void Start()
    {
        Debug.Log(T);
        T = Obj2.transform.localEulerAngles;
    }

    private void FixedUpdate()
    {
        if (left)
        {
            Obj.transform.Translate(Vector3.left * speed * Time.deltaTime);
        }

        if (right)
        {
            Obj.transform.Translate(Vector3.right * speed * Time.deltaTime);
        }
        //这一坨就是控制飞机的
        if (Input.GetKey(KeyCode.W)) //前进
        {
            Obj.transform.Translate(Vector3.forward * speed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.S)) //后退
        {
            Obj.transform.Translate(Vector3.back * speed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.A)) //
        {
            Obj.transform.Rotate(0, -rotateSpeed * Time.deltaTime, 0);
            Obj2.transform.Rotate(0, 0, rotateSpeed * Time.deltaTime);
            Debug.Log(T);
        }
        else if (!Input.GetKey(KeyCode.D) && Obj2.transform.localEulerAngles.z > 0f && 180f > Obj2.transform.localEulerAngles.z)
        {
            //Obj2.transform.localEulerAngles = Vector3.Lerp(Obj2.transform.localEulerAngles, T, 0.1f);
            Obj2.transform.Rotate(0, 0, -rightSpeed * Time.deltaTime);

            //Obj2.transform.eulerAngles = new Vector3(0f, 0f, 0f);
            Debug.Log(Obj2.transform.eulerAngles + " left");
        }

        if (Input.GetKey(KeyCode.D)) //
        {
            Obj.transform.Rotate(0, rotateSpeed * Time.deltaTime, 0);
            Obj2.transform.Rotate(0, 0, -rotateSpeed * Time.deltaTime);
            Debug.Log(Obj2.transform.eulerAngles + " right");
        }
        else if (!Input.GetKey(KeyCode.A) && Obj2.transform.localEulerAngles.z < 359f && 180f < Obj2.transform.localEulerAngles.z)
        {
            //Obj2.transform.localEulerAngles = Vector3.Lerp(Obj2.transform.localEulerAngles, T, 0.1f);
            Obj2.transform.Rotate(0, 0, rightSpeed * Time.deltaTime);

            //Obj2.transform.eulerAngles = new Vector3(0f, 0f, 0f);
            Debug.Log(Obj2.transform.eulerAngles + " right");
        }

        //到这结束

        //if (Input.GetKey(KeyCode.Q))//左平移
        //{
        //    Obj.transform.Translate(Vector3.left * speed * Time.deltaTime);
        //}
        //if (Input.GetKey(KeyCode.E))//右平移
        //{
        //    Obj.transform.Translate(Vector3.right * speed * Time.deltaTime);
        //}
        //if (Input.GetKey(KeyCode.Q))//左桶滚
        //{
        //    Obj2.transform.Rotate(0, 0, rotateSpeed * Time.deltaTime);
        //}
        //if (Input.GetKey(KeyCode.E))//右桶滚
        //{
        //    Obj2.transform.Rotate(0, 0, -rotateSpeed * Time.deltaTime);
        //}
    }
}