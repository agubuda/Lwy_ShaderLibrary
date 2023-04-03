using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;

public class meshModifier : MonoBehaviour
{
    // Start is called before the first frame update
    public ComputeShader computeShader;
    public float _strength = 0.5f;
    private int kernelIndex;
    public Material material;
    private ComputeBuffer computeBuffer = null;

    private Vector3[] verticesPosition;

    private int vertCount;
    private Vector3[] aaa;

    private int threadGroup;
    void OnEnable()
    {   
        kernelIndex = computeShader.FindKernel("CSMain");

        //matrix
        Matrix4x4 localToWorld = transform.localToWorldMatrix;

        //compute buffer initialize
        var meshFilter = GetComponent<MeshFilter>().sharedMesh;
        vertCount = meshFilter.vertexCount;

        Debug.Log(vertCount);
        computeBuffer = new ComputeBuffer(vertCount,3 * sizeof(float),ComputeBufferType.Default);
        // Graphics.SetRandomWriteTarget(1,computeBuffer);
        // Debug.Log(computeBuffer);

        verticesPosition = meshFilter.vertices;
        // for(int i = 0; i<vertCount; i++)
        // {
        //     verticesPosition[i] = localToWorld.MultiplyPoint3x4(verticesPosition[i]);
        // }
        aaa = new Vector3[verticesPosition.Length];

        threadGroup = vertCount / 128 +1 /*Mathf.CeilToInt(vertCount/128+1)*/;

    }

    // Update is called once per frames
    void Update()
    {
        computeBuffer.SetData(verticesPosition);

        computeShader.SetBuffer(kernelIndex,"_pos", computeBuffer); 
        computeShader.SetInt("vertCount",vertCount);
        computeShader.SetFloat("_strength",_strength);
        computeShader.SetFloat("time",  Time.time); 
        computeShader.Dispatch(kernelIndex,threadGroup*10,1,1);

        // computeBuffer.GetData (aaa, 0, 0, vertCount);
        // for(int i = 0; i < aaa.Length; i++)
        // {
        //     Debug.Log(aaa[i]);
        // }

        // material.SetBuffer("_Pos", computeBuffer);
        Debug.Log(_strength);
        material.SetBuffer("_Pos", computeBuffer);
    }

    void OnDisable(){
        // computeBuffer.Dispose();

        computeBuffer.Release();
        // computeBuffer.re
    }
}
