using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class CSTesting : MonoBehaviour
{
    public ComputeShader shader;
    void RunShader(){

        int kernelHandle = shader.FindKernel("CSMain");

        RenderTexture tex = new RenderTexture(256,256,24);
        tex.enableRandomWrite = true;
        tex.Create();

        shader.SetTexture(kernelHandle, "Result", tex);
        shader.Dispatch(kernelHandle, 256/8, 256/8, 1);
        AssetDatabase.CreateAsset(tex,"Assets/test.renderTexture");
        
    }



    // Start is called before the first frame update
    void Start()
    {
        RunShader();
        
    }

    // // Update is called once per frame
    void Update()
    {
        
    }
}
