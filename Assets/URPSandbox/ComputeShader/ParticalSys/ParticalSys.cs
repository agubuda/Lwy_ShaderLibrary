using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ParticalSys : MonoBehaviour
{
    public ComputeShader computeShader;
    ComputeBuffer computeBuffer;
    int kernelIndex;
    public Material material;

    const int mParticalCount = 20000;
    struct particalData{
        public Vector3 pos;
        public Color color;
    }
    // Start is called before the first frame update
    void Start()
    {
        computeBuffer = new ComputeBuffer(mParticalCount, 3*4 + 4*4);
        particalData[] particalDatas = new particalData[mParticalCount];

        computeBuffer.SetData(particalDatas);
        kernelIndex = computeShader.FindKernel("CSMain");

        // computeBuffer.SetData(T[]);
        // computeBuffer.SetData(particalDatas);

    }

    // Update is called once per frame
    void FixedUpdate()
    {
        computeShader.SetBuffer(kernelIndex,"particalBuffer", computeBuffer);
        computeShader.SetFloat("time",Time.time);
        computeShader.Dispatch(kernelIndex, mParticalCount/1000,1,1);
        material.SetBuffer("_particleDataBuffer", computeBuffer);        
    }

    private void OnRenderObject() {
        material.SetPass(0);
        Graphics.DrawProceduralNow(MeshTopology.Points, mParticalCount);
    }

    private void OnDestroy() {
        computeBuffer.Release();
        computeBuffer.Dispose();
    }
}
