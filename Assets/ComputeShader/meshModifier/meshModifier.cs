using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class meshModifier : MonoBehaviour
{
    // Start is called before the first frame update
    public ComputeShader computeShader;
    int kernelIndex;
    public Material material;
    ComputeBuffer computeBuffer;

    Vector3[] verticesPosition;

    int vertCount;
    void Start()
    {   
        //matrix
        Matrix4x4 localToWorld = transform.localToWorldMatrix;

        //compute buffer initialize
        var meshFilter = GetComponent<MeshFilter>();
        vertCount = meshFilter.mesh.vertexCount;

        Debug.Log(vertCount);
        computeBuffer = new ComputeBuffer(vertCount,3 * 4 );
        Graphics.SetRandomWriteTarget(1,computeBuffer,true);

        verticesPosition = meshFilter.mesh.vertices;
        for(int i = 0; i<vertCount; i++)
        {
            verticesPosition[i] = localToWorld.MultiplyPoint3x4(verticesPosition[i]);
        }

        computeBuffer.SetData(verticesPosition);
        kernelIndex = computeShader.FindKernel("CSMain");

        foreach(var pos in verticesPosition){
            Debug.Log(pos);
        }
    }

    // Update is called once per frame
    void Update()
    {
        computeShader.SetBuffer(kernelIndex,"pos", computeBuffer); 
        computeShader.SetFloat("time", Time.time); 
        computeShader.SetInt("vertCount",vertCount);
        computeShader.Dispatch(kernelIndex,vertCount,1,1);
        material.SetBuffer("pos", computeBuffer);
    }

    void OnDestroy(){
        // computeBuffer.re
        computeBuffer.Dispose();
    }
}
