using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering.Universal;
using UnityEngine;

public class CustomPostProcessRenderer : ScriptableRendererFeature
{
    CustomPostProcessPass pass;

    public override void Create()
    {
        pass = new CustomPostProcessPass();

    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
    }
}
