using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;

public class meshModifier : MonoBehaviour
{
    // Start is called before the first frame update
    public ComputeShader computeShader;
    public float _MoveScale = 1.0f;
    public float _Spring = 5.0f;
    public float _Damper = 1.0f;
    public float m_strength = 0.5f;
    private int kernelIndex;
    public Material material;
    private ComputeBuffer computeBuffer = null;

    private Vector3[] verticesPosition;

    private int vertCount = 0;
    private Vector3[] aaa;

    private int threadGroup;
    private Mesh meshFilter;

    //matrix
    private Matrix4x4 localToWorld;
    private Matrix4x4 worldToLocal;
    void OnEnable()
    {   
        kernelIndex = computeShader.FindKernel("CSMain");

        //compute buffer initialize
        meshFilter = GetComponent<MeshFilter>().mesh;
        vertCount = meshFilter.vertexCount;

        Debug.Log(vertCount);
        computeBuffer = new ComputeBuffer(vertCount * 4, 3 * sizeof(float),ComputeBufferType.Default);
        // Graphics.SetRandomWriteTarget(1,computeBuffer);
        // Debug.Log(computeBuffer);

        // verticesPosition = meshFilter.vertices;
        // for(int i = 0; i<vertCount; i++)
        // {
        //     verticesPosition[i] = localToWorld.MultiplyPoint3x4(verticesPosition[i]);
        // }

        // //debug array
        // aaa = new Vector3[verticesPosition.Length];

        threadGroup = Mathf.CeilToInt(vertCount/128.0f);

    }

    // Update is called once per frames
    void FixedUpdate()
    {
        verticesPosition = meshFilter.vertices;
        computeBuffer.SetData(verticesPosition,0,0,vertCount);

        //matrix
        localToWorld = transform.localToWorldMatrix;
        // worldToLocal = transform.worldToLocalMatrix;
        computeShader.SetMatrix("_LocalToWorld", localToWorld);
        // computeShader.SetMatrix("_WorldToLocal", worldToLocal);

        computeShader.SetBuffer(kernelIndex,"_pos", computeBuffer); 
        computeShader.SetInt("vertCount",vertCount);
        computeShader.SetFloat("_MoveScale",_MoveScale);
        computeShader.SetFloat("_Spring",_Spring);
        computeShader.SetFloat("_Damper",_Damper);
        computeShader.SetFloat("_deltaTime",  Time.deltaTime);
        computeShader.Dispatch(kernelIndex,threadGroup,1,1);

        // // debug part
        // computeBuffer.GetData (aaa, 0, 0, vertCount);
        // for(int i = 0; i < aaa.Length; i++)
        // {
        //     Debug.Log(aaa[i]);
        // }

        material.SetBuffer("_Pos", computeBuffer);
        //set prev vert position
        computeBuffer.SetData(verticesPosition,0,vertCount,vertCount);
    }

    void OnDisable(){
        // computeBuffer.Dispose();
        computeBuffer.Release();
        // computeBuffer.re
    }
}
