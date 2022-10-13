using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering.Universal;
using UnityEngine;

public class CustomPostProcessRenderer : ScriptableRendererFeature
{
    CustomPostProcessPass pass;

    [SerializeField]
    public Material customEffect;

    public override void Create()
    {
        pass = new CustomPostProcessPass(customEffect);

    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
    }
}
