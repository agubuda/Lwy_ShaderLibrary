using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;
using Unity.Mathematics;

public class meshModifier : MonoBehaviour
{
    // Start is called before the first frame update
    public ComputeShader computeShader;
    public float _MoveScale = 1.0f;
    public float _Spring = 1000.0f;
    public float _Damper = 10.0f;
    private int kernelIndex;
    public Material material;
    private ComputeBuffer computeBuffer = null;
    private ComputeBuffer data = null;

    private Vector3[] verticesPosition;

    private int vertCount = 0;
    //private Vector3[] aaa;

    private int threadGroup;
    private MeshFilter meshFilter;
    private SkinnedMeshRenderer skinnedMeshRenderer;
    private Mesh mesh;
    bool isAnimated;

    //matrix
    private Matrix4x4 localToWorld;

    void OnEnable()
    {   
        kernelIndex = computeShader.FindKernel("CSMain");

        //compute buffer initialize
        meshFilter = GetComponent<MeshFilter>();
        if (meshFilter)
        {
            vertCount = meshFilter.sharedMesh.vertexCount;
            mesh = meshFilter.sharedMesh;
            Color[] vertColor = meshFilter.sharedMesh.colors;
            isAnimated = false;
        }

        skinnedMeshRenderer = GetComponent<SkinnedMeshRenderer>();
        if (skinnedMeshRenderer)
        {
            //skinnedMeshRenderer.BakeMesh(mesh);
            vertCount = skinnedMeshRenderer.sharedMesh.vertexCount;
            isAnimated = true;

        }

        var renderer = GetComponent<Renderer>();
        if (!renderer) return;


        //Debug.Log(vertCount);
        computeBuffer = new ComputeBuffer(vertCount, 3 * sizeof(float),ComputeBufferType.Default);
        data = new ComputeBuffer(vertCount, 3 * 3 * sizeof(float),ComputeBufferType.Default);

        // Graphics.SetRandomWriteTarget(1,computeBuffer);
        // Debug.Log(computeBuffer);

        // verticesPosition = meshFilter.vertices;
        // for(int i = 0; i<vertCount; i++)
        // {
        //     verticesPosition[i] = localToWorld.MultiplyPoint3x4(verticesPosition[i]);
        // }

        ////debug array
        //aaa = new Vector3[verticesPosition.Length];

        threadGroup = Mathf.CeilToInt(vertCount/128.0f);
    }

    // Update is called once per frames
    void LateUpdate()
    {
        if (skinnedMeshRenderer)
        {
            mesh = new Mesh();
            skinnedMeshRenderer.BakeMesh(mesh);
            verticesPosition = mesh.vertices;
        }
        if(meshFilter)
        {
            verticesPosition = mesh.vertices;
        }

        computeBuffer.SetData(verticesPosition,0,0,vertCount);
        computeShader.SetBuffer(kernelIndex, "_pos", computeBuffer);

        //matrix
        localToWorld = transform.localToWorldMatrix;
        computeShader.SetMatrix("_LocalToWorld", localToWorld);
        computeShader.SetInt("vertCount", vertCount);
        computeShader.SetFloat("_MoveScale", _MoveScale);
        computeShader.SetFloat("_Spring", _Spring);
        computeShader.SetFloat("_Damper", _Damper);

        computeShader.SetBuffer(kernelIndex, "data", data);

        computeShader.Dispatch(kernelIndex,threadGroup,1,1);

        //// debug part

        //computeBuffer.GetData(aaa, 0, 0, vertCount);
        //for (int i = 0; i < aaa.Length; i++)
        //{
        //    Debug.Log(aaa[i]);
        //}

        material.SetBuffer("_Pos", computeBuffer);
        //material.SetConstantBuffer("_Pos", computeBuffer, 0, vertCount * 12);
    }

    void OnDisable()
    {
        computeBuffer.Release();
        data.Release();
    }
}
