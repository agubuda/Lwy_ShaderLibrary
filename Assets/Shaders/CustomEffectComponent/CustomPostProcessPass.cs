using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[System.Serializable]
public class CustomPostProcessPass : ScriptableRenderPass
{
    RenderTargetIdentifier source;
    RenderTargetIdentifier destinationA;
    RenderTargetIdentifier destinationB;
    RenderTargetIdentifier latestDest;

    readonly CustomPostProcessingMaterials _mat;

    readonly int temporatyRTIdA = Shader.PropertyToID("_TempRT");
    readonly int temporatyRTIdB = Shader.PropertyToID("_TempRTB");

    public CustomPostProcessPass(CustomPostProcessingMaterials mat)
    {
        //set the render pass event
        renderPassEvent  = RenderPassEvent.BeforeRenderingPostProcessing;
        _mat = mat;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;
        descriptor.depthBufferBits = 0;

        var renderer = renderingData.cameraData.renderer;
        source = renderer.cameraColorTarget;

        //
        cmd.GetTemporaryRT(temporatyRTIdA, descriptor,FilterMode.Bilinear);
        destinationA = new RenderTargetIdentifier(temporatyRTIdA);
        cmd.GetTemporaryRT(temporatyRTIdB, descriptor,FilterMode.Bilinear);
        destinationB = new RenderTargetIdentifier(temporatyRTIdB);

    }

    //



    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if(renderingData.cameraData.isSceneViewCamera)return;

        // var materials = CustomPostProcessingMaterials.Instance;
        // if(materials == null){
        if (_mat == null)
        {
            Debug.LogError("Custom post processing mat instance is null");
            return;
        }

        CommandBuffer cmd = CommandBufferPool.Get("Custom post processing");
        cmd.Clear();

        //
        var stack = VolumeManager.instance.stack;

        #region Local Methods

        void BlitTo(Material mat, int pass = 0){
            var first  = latestDest;
            var last  = first == destinationA ? destinationB : destinationA;
            Blit(cmd,first,last,mat,pass);

            latestDest = last;
        }
        #endregion

        latestDest = source;

        var customEffect  = stack.GetComponent<CustomEffectComponent>();
        if(customEffect.IsActive()){
            // var material = materials.customEffect;
            var material = _mat.customEffect;
            material.SetFloat(Shader.PropertyToID("_Intensity"), customEffect.intensity.value);
            material.SetColor(Shader.PropertyToID("_OverlayColor"), customEffect.overlayColor.value);

            BlitTo(material);
        }

        Blit(cmd, latestDest, source);
        CommandBufferPool.Release(cmd);

    }

    public override void OnCameraCleanup(CommandBuffer cmd)
    {
        cmd.ReleaseTemporaryRT(temporatyRTIdA);
        cmd.ReleaseTemporaryRT(temporatyRTIdB);

    }
}
