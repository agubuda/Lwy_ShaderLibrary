using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SimpleMovementController : MonoBehaviour
{
    public float speed = 100f;
    public Transform Obj;


    // Update is called once per frame
    private float rotateSpeed = 30f;
    private float movespeed = 5;

    void FixedUpdate()
    {
        //�ڶ��ַ�ʽ�����ƶ�
        if (Input.GetKey(KeyCode.W)) //ǰ��
        {
            transform.Translate(Vector3.forward * speed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.S)) //����
        {
            transform.Translate(Vector3.back * speed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.A)) //ǰ��
        {
            transform.Translate(Vector3.left * speed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.D)) //����
        {
            transform.Translate(Vector3.right * speed * Time.deltaTime);
        }
        // if (Input.GetKey(KeyCode.Q))//������ת
        // {
        //     transform.Rotate(0, -rotateSpeed * Time.deltaTime, 0);
        // }
        // if (Input.GetKey(KeyCode.E))//������ת
        //{
        //     transform.Rotate(0, rotateSpeed * Time.deltaTime, 0);
        // }
    }
}
