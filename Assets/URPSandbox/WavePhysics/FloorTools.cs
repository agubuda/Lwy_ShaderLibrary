using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FloorTools : MonoBehaviour
{
    //这个东西是用于木板和桥梁拼接的
    public int x = 10;
    public int z = 10;
    public GameObject[] res;

    void Start()
    {
        CreateFloor();
    }

    int resIdx = 0;
    void CreateFloor()
    {
        for (int i = 0; i < z; i ++)
        {
            for (int j = 0; j < x; j++)
            {


                resIdx ++;
                if(resIdx == res.Length) resIdx = 0;
            }
        }
    }
}
