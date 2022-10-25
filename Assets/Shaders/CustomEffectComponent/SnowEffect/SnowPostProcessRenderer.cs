using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering.Universal;
using UnityEngine;

public class SnowPostProcessRenderer : ScriptableRendererFeature
{
    SnowPostProcessPass pass;
    [SerializeField]
    Material snowEffect;


    public override void Create()
    {
        // _Instance = new CustomPostProcessingMaterials();
        pass = new SnowPostProcessPass(snowEffect);

    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
    }
}

