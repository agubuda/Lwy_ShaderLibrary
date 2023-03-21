using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Texturing : MonoBehaviour
{
    public ComputeShader computeShader;
    public Material material;
    // Start is called before the first frame update
    void Start()
    {
        int kernelIndex = computeShader.FindKernel("CSMain");

        RenderTexture mRenderTexture = new RenderTexture(1024,1024,16);
        mRenderTexture.enableRandomWrite = true;
        mRenderTexture.Create();

        

        computeShader.SetTexture(kernelIndex, "Result", mRenderTexture);
        computeShader.Dispatch(kernelIndex,1024/8, 1024/8, 1);

        material.mainTexture = mRenderTexture;
        material.SetTexture("_NormalMap", mRenderTexture);
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
