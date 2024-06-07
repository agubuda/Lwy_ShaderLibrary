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
        //�ڶ��ַ�ʽ�����ƶ�
        if (Input.GetKey(KeyCode.W)) //ǰ��
        {
            transform.Translate(Vector3.forward * movespeed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.S)) //����
        {
            transform.Translate(Vector3.back * movespeed * Time.deltaTime);
        }
        if (Input.GetKey(KeyCode.A))//������ת
        {
            transform.Rotate(0, -rotateSpeed * Time.deltaTime, 0);
        }
        if (Input.GetKey(KeyCode.D))//������ת
����{
            transform.Rotate(0, rotateSpeed * Time.deltaTime, 0);
        }
    }
}
