using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering.Universal;
using UnityEngine;
using UnityEngine.Rendering;

public class SSPRRendererFeature : ScriptableRendererFeature
{
    SSPRRenderPass pass;
    [SerializeField]


    public override void Create()
    {
        // _Instance = new CustomPostProcessingMaterials();
        // pass = new SnowPostProcessPass(null);

    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
    }

    public class SSPRRenderPass : ScriptableRenderPass
    {
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            throw new System.NotImplementedException();
        }
    }
}

