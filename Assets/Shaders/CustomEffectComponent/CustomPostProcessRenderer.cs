using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering.Universal;
using UnityEngine;

public class CustomPostProcessRenderer : ScriptableRendererFeature
{
    CustomPostProcessPass pass;

    [SerializeField]
    CustomPostProcessingMaterials mat;

    public override void Create()
    {
        pass = new CustomPostProcessPass(mat);

    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
    }
}
