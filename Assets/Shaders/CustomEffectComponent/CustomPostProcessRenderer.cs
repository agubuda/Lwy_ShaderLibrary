using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering.Universal;
using UnityEngine;

public class CustomPostProcessRenderer : ScriptableRendererFeature
{
    CustomPostProcessPass pass;
    [SerializeField]
    Material customEffect;


    public override void Create()
    {
        // _Instance = new CustomPostProcessingMaterials();
        pass = new CustomPostProcessPass(customEffect);

    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
    }
}
