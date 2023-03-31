using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;

public class meshModifier : MonoBehaviour
{
    // Start is called before the first frame update
    public ComputeShader computeShader;
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
        computeBuffer = new ComputeBuffer(vertCount,3 * sizeof(float),ComputeBufferType.Append);
        // Graphics.SetRandomWriteTarget(1,computeBuffer,true);
        // Debug.Log(computeBuffer);


        verticesPosition = meshFilter.vertices;
        // for(int i = 0; i<vertCount; i++)
        // {
        //     verticesPosition[i] = localToWorld.MultiplyPoint3x4(verticesPosition[i]);
        // }
        // aaa = new Vector3[verticesPosition.Length];

        threadGroup = Mathf.CeilToInt(vertCount/64);

        // computeBuffer.SetData(verticesPosition);

        computeShader.SetBuffer(kernelIndex,"pos", computeBuffer); 
        computeShader.SetInt("vertCount",vertCount);
        // computeShader.Dispatch(kernelIndex,vertCount,1,1);

        // computeBuffer.GetData (aaa, 0, 0, vertCount);
        // for(int i = 0; i < aaa.Length; i++)
        // {
        //     Debug.Log(aaa[i]);
        // }

        // Debug.Log(computeBuffer.GetData<Vector3>() + "dick");
    }

    // Update is called once per frame
    void LateUpdate()
    {
        computeBuffer.SetData(verticesPosition);
        computeShader.SetFloat("time",  Time.time); 
        computeShader.Dispatch(kernelIndex,threadGroup,1,1);

        // computeBuffer.GetData (aaa, 0, 0, vertCount);
        // for(int i = 0; i < aaa.Length; i++)
        // {
        //     Debug.Log(aaa[i]);
        // }

        // material.SetBuffer("_Pos", computeBuffer);
        material.SetBuffer("_Pos", computeBuffer);

    }

    void OnDisable(){
        computeBuffer.Dispose();

        computeBuffer.Release();
        // computeBuffer.re
    }
}
