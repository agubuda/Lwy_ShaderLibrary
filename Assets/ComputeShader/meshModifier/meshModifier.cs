using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;
using Unity.Mathematics;

public class meshModifier : MonoBehaviour
{
    // Start is called before the first frame update
    public ComputeShader meshComputeShader;
    //public ComputeShader skinnedMeshComputeShader;
    public float _MoveScale = 1.0f;
    public float _Spring = 100.0f;
    public float _Damper = 5.0f;
    private int kernelIndex;
    public Material material;
    private ComputeBuffer computeBuffer = null;
    private ComputeBuffer data = null;
    //private GraphicsBuffer skinnedMeshBuffer = null;

    private Vector3[] verticesPosition;

    private int vertCount = 0;
    //private Vector3[] aaa;

    private int threadGroup;
    private MeshFilter meshFilter;
    private SkinnedMeshRenderer skinnedMeshRenderer;
    private Mesh mesh;
    //bool isAnimated;

    //matrix
    private Matrix4x4 localToWorld;

    void OnEnable()
    {   

        //compute buffer initialize
        meshFilter = GetComponent<MeshFilter>();
        if (meshFilter)
        {
            kernelIndex = meshComputeShader.FindKernel("meshModifier");

            vertCount = meshFilter.sharedMesh.vertexCount;
            mesh = meshFilter.sharedMesh;
            //computeBuffer = new ComputeBuffer(vertCount, 3 * sizeof(float), ComputeBufferType.Default);
        }

        skinnedMeshRenderer = GetComponent<SkinnedMeshRenderer>();
        if (skinnedMeshRenderer)
        {
            kernelIndex = meshComputeShader.FindKernel("skinnedMeshModifier");

            //skinnedMeshRenderer.BakeMesh(mesh);
            vertCount = skinnedMeshRenderer.sharedMesh.vertexCount;
            verticesPosition = skinnedMeshRenderer.sharedMesh.vertices;

            //Debug.Log(skinnedMeshRenderer.GetVertexBuffer().ToString());

            //skinnedMeshBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Vertex, vertCount, 2 * 3 * 4 + 2 * 2 * 4);
            //skinnedMeshComputeShader.SetBuffer(kernelIndex, "_skinnedPos", skinnedMeshRenderer.GetVertexBuffer());

            //Debug.Log(skinnedMeshBuffer.count);
        }

        var renderer = GetComponent<Renderer>();
        if (!renderer) return;

        Debug.Log(vertCount);
        computeBuffer = new ComputeBuffer(vertCount, 3 * sizeof(float), ComputeBufferType.Default);
        data = new ComputeBuffer(vertCount, 3 * 3 * sizeof(float),ComputeBufferType.Default);

        // Debug.Log(computeBuffer);

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
        //localToWorld = transform.
        localToWorld = transform.localToWorldMatrix;
        meshComputeShader.SetMatrix("_LocalToWorld", localToWorld);

        meshComputeShader.SetInt("vertCount", vertCount);
        meshComputeShader.SetFloat("_MoveScale", _MoveScale);
        meshComputeShader.SetFloat("_Spring", _Spring);
        meshComputeShader.SetFloat("_Damper", _Damper);

        if (skinnedMeshRenderer)
        {
            mesh = new Mesh();
            //skinnedMeshRenderer.BakeMesh(mesh);
            //verticesPosition = mesh.vertices;
            //computeBuffer.SetData(verticesPosition,0,0,vertCount);
            meshComputeShader.SetBuffer(kernelIndex, "_skinnedPos", skinnedMeshRenderer.GetVertexBuffer());
            meshComputeShader.SetBuffer(kernelIndex, "_pos", computeBuffer);


            //computeBuffer.SetData(verticesPosition);
            //meshComputeShader.SetBuffer(kernelIndex, "_pos", computeBufer);
            skinnedMeshRenderer.GetVertexBuffer().Dispose();


        }

        if (meshFilter)
        {
            verticesPosition = mesh.vertices;
            computeBuffer.SetData(verticesPosition, 0, 0, vertCount);
            meshComputeShader.SetBuffer(kernelIndex, "_pos", computeBuffer);
        }

        meshComputeShader.SetBuffer(kernelIndex, "data", data);
        meshComputeShader.Dispatch(kernelIndex, threadGroup, 1, 1);

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

        if(skinnedMeshRenderer)
        {
            skinnedMeshRenderer.GetVertexBuffer().Dispose();
        }
    }
}
