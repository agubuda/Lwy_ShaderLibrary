using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering.Universal;
using UnityEngine;

public class SobelPostProcessRenderer : ScriptableRendererFeature
{
    SobelPostProcessPass pass;
    [SerializeField]
    Material sobelEffect;


    public override void Create()
    {
        // _Instance = new CustomPostProcessingMaterials();
        pass = new SobelPostProcessPass(sobelEffect);

    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
    }
}
