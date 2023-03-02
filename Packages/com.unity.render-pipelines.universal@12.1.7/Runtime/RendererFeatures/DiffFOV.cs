using System.Collections.Generic;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

namespace UnityEngine.Experimental.Rendering.Universal
{
    public enum DiffCamRenderQueueType
    {
        Opaque,
        Transparent,
    }

    [ExcludeFromPreset]
    [Tooltip("Render Objects simplifies the injection of additional render passes by exposing a selection of commonly used settings.")]
    public class DiffFOV : ScriptableRendererFeature
    {
        [System.Serializable]
        public class DiffCamRenderObjectsSettings
        {
            public string passTag = "DiffCamRenderObjectsFeature";
            public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;

            public DiffFilterSettings DiffFilterSettings = new DiffFilterSettings();

            public Material overrideMaterial = null;
            public int overrideMaterialPassIndex = 0;

            public bool overrideDepthState = false;
            public CompareFunction depthCompareFunction = CompareFunction.LessEqual;
            public bool enableWrite = true;

            public StencilStateData stencilSettings = new StencilStateData();

            public DiffCustomCameraSettings cameraSettings = new DiffCustomCameraSettings();
        }

        [System.Serializable]
        public class DiffFilterSettings
        {
            // TODO: expose opaque, transparent, all ranges as drop down
            public DiffCamRenderQueueType DiffCamRenderQueueType;
            public LayerMask LayerMask;
            public string[] PassNames;

            public DiffFilterSettings()
            {
                DiffCamRenderQueueType = DiffCamRenderQueueType.Opaque;
                LayerMask = 0;
            }
        }

        [System.Serializable]
        public class DiffCustomCameraSettings
        {
            public bool overrideCamera = false;
            public bool restoreCamera = true;
            public Vector4 offset;
            public float cameraFieldOfView = 60.0f;
        }

        public DiffCamRenderObjectsSettings settings = new DiffCamRenderObjectsSettings();

        DiffFOVPass DiffFOVPass;

        public override void Create()
        {
            DiffFilterSettings filter = settings.DiffFilterSettings;

            // Render Objects pass doesn't support events before rendering prepasses.
            // The camera is not setup before this point and all rendering is monoscopic.
            // Events before BeforeRenderingPrepasses should be used for input texture passes (shadow map, LUT, etc) that doesn't depend on the camera.
            // These events are filtering in the UI, but we still should prevent users from changing it from code or
            // by changing the serialized data.
            if (settings.Event < RenderPassEvent.BeforeRenderingPrePasses)
                settings.Event = RenderPassEvent.BeforeRenderingPrePasses;

            DiffFOVPass = new DiffFOVPass(settings.passTag, settings.Event, filter.PassNames,
                filter.DiffCamRenderQueueType, filter.LayerMask, settings.cameraSettings);

            DiffFOVPass.overrideMaterial = settings.overrideMaterial;
            DiffFOVPass.overrideMaterialPassIndex = settings.overrideMaterialPassIndex;

            if (settings.overrideDepthState)
                DiffFOVPass.SetDetphState(settings.enableWrite, settings.depthCompareFunction);

            if (settings.stencilSettings.overrideStencilState)
                DiffFOVPass.SetStencilState(settings.stencilSettings.stencilReference,
                    settings.stencilSettings.stencilCompareFunction, settings.stencilSettings.passOperation,
                    settings.stencilSettings.failOperation, settings.stencilSettings.zFailOperation);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            renderer.EnqueuePass(DiffFOVPass);
        }

        internal override bool SupportsNativeRenderPass()
        {
            return settings.Event <= RenderPassEvent.BeforeRenderingPostProcessing;
        }
    }
}
