using System.Collections.Generic;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Scripting.APIUpdating;

namespace UnityEngine.Experimental.Rendering.Universal
{
    public class DiffFOVPass : ScriptableRenderPass
    {
        DiffCamRenderQueueType diffCamRenderQueueType;
        FilteringSettings m_FilteringSettings;
        DiffFOV.DiffCustomCameraSettings m_CameraSettings;
        string m_ProfilerTag;
        ProfilingSampler m_ProfilingSampler;

        public Material overrideMaterial { get; set; }
        public int overrideMaterialPassIndex { get; set; }

        List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>();

        public void SetDetphState(bool writeEnabled, CompareFunction function = CompareFunction.Less)
        {
            m_RenderStateBlock.mask |= RenderStateMask.Depth;
            m_RenderStateBlock.depthState = new DepthState(writeEnabled, function);
        }

        public void SetStencilState(int reference, CompareFunction compareFunction, StencilOp passOp, StencilOp failOp, StencilOp zFailOp)
        {
            StencilState stencilState = StencilState.defaultValue;
            stencilState.enabled = true;
            stencilState.SetCompareFunction(compareFunction);
            stencilState.SetPassOperation(passOp);
            stencilState.SetFailOperation(failOp);
            stencilState.SetZFailOperation(zFailOp);

            m_RenderStateBlock.mask |= RenderStateMask.Stencil;
            m_RenderStateBlock.stencilReference = reference;
            m_RenderStateBlock.stencilState = stencilState;
        }

        RenderStateBlock m_RenderStateBlock;

        public DiffFOVPass(string profilerTag, RenderPassEvent renderPassEvent, string[] shaderTags, DiffCamRenderQueueType diffCamRenderQueueType, int layerMask, DiffFOV.DiffCustomCameraSettings cameraSettings)
        {
            base.profilingSampler = new ProfilingSampler(nameof(DiffFOVPass));

            m_ProfilerTag = profilerTag;
            m_ProfilingSampler = new ProfilingSampler(profilerTag);
            this.renderPassEvent = renderPassEvent;
            this.diffCamRenderQueueType = diffCamRenderQueueType;
            this.overrideMaterial = null;
            this.overrideMaterialPassIndex = 0;
            RenderQueueRange renderQueueRange = (diffCamRenderQueueType == DiffCamRenderQueueType.Transparent)
                ? RenderQueueRange.transparent
                : RenderQueueRange.opaque;
            m_FilteringSettings = new FilteringSettings(renderQueueRange, layerMask);

            if (shaderTags != null && shaderTags.Length > 0)
            {
                foreach (var passName in shaderTags)
                    m_ShaderTagIdList.Add(new ShaderTagId(passName));
            }
            else
            {
                m_ShaderTagIdList.Add(new ShaderTagId("SRPDefaultUnlit"));
                m_ShaderTagIdList.Add(new ShaderTagId("UniversalForward"));
                m_ShaderTagIdList.Add(new ShaderTagId("UniversalForwardOnly"));
            }

            m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
            m_CameraSettings = cameraSettings;
        }

        internal DiffFOVPass(URPProfileId profileId, RenderPassEvent renderPassEvent, string[] shaderTags, DiffCamRenderQueueType renderQueueType, int layerMask, DiffFOV.DiffCustomCameraSettings cameraSettings)
            : this(profileId.GetType().Name, renderPassEvent, shaderTags, renderQueueType, layerMask, cameraSettings)
        {
            m_ProfilingSampler = ProfilingSampler.Get(profileId);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            SortingCriteria sortingCriteria = (diffCamRenderQueueType == DiffCamRenderQueueType.Transparent)
                ? SortingCriteria.CommonTransparent
                : renderingData.cameraData.defaultOpaqueSortFlags;

            DrawingSettings drawingSettings = CreateDrawingSettings(m_ShaderTagIdList, ref renderingData, sortingCriteria);
            drawingSettings.overrideMaterial = overrideMaterial;
            drawingSettings.overrideMaterialPassIndex = overrideMaterialPassIndex;

            ref CameraData cameraData = ref renderingData.cameraData;
            Camera camera = cameraData.camera;

            // In case of camera stacking we need to take the viewport rect from base camera
            Rect pixelRect = renderingData.cameraData.pixelRect;
            float cameraAspect = (float)pixelRect.width / (float)pixelRect.height;

            // NOTE: Do NOT mix ProfilingScope with named CommandBuffers i.e. CommandBufferPool.Get("name").
            // Currently there's an issue which results in mismatched markers.
            CommandBuffer cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                if (m_CameraSettings.overrideCamera)
                {
                    if (cameraData.xr.enabled)
                    {
                        Debug.LogWarning("DiffFOV pass is configured to override camera matrices. While rendering in stereo camera matrices cannot be overridden.");
                    }
                    else
                    {
                        Matrix4x4 projectionMatrix = Matrix4x4.Perspective(m_CameraSettings.cameraFieldOfView, cameraAspect,
                            camera.nearClipPlane, camera.farClipPlane);
                        projectionMatrix = GL.GetGPUProjectionMatrix(projectionMatrix, cameraData.IsCameraProjectionMatrixFlipped());

                        Matrix4x4 viewMatrix = cameraData.GetViewMatrix();
                        Vector4 cameraTranslation = viewMatrix.GetColumn(3);
                        viewMatrix.SetColumn(3, cameraTranslation + m_CameraSettings.offset);

                        RenderingUtils.SetViewAndProjectionMatrices(cmd, viewMatrix, projectionMatrix, false);
                    }
                }

                var activeDebugHandler = GetActiveDebugHandler(renderingData);
                if (activeDebugHandler != null)
                {
                    activeDebugHandler.DrawWithDebugRenderState(context, cmd, ref renderingData, ref drawingSettings, ref m_FilteringSettings, ref m_RenderStateBlock,
                        (ScriptableRenderContext ctx, ref RenderingData data, ref DrawingSettings ds, ref FilteringSettings fs, ref RenderStateBlock rsb) =>
                        {
                            ctx.DrawRenderers(data.cullResults, ref ds, ref fs, ref rsb);
                        });
                }
                else
                {
                    // Ensure we flush our command-buffer before we render...
                    context.ExecuteCommandBuffer(cmd);
                    cmd.Clear();

                    // Render the objects...
                    context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref m_FilteringSettings, ref m_RenderStateBlock);
                }

                if (m_CameraSettings.overrideCamera && m_CameraSettings.restoreCamera && !cameraData.xr.enabled)
                {
                    RenderingUtils.SetViewAndProjectionMatrices(cmd, cameraData.GetViewMatrix(), cameraData.GetGPUProjectionMatrix(), false);
                }
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}
