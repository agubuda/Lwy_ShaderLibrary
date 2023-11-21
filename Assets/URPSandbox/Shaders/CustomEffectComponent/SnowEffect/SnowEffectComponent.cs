using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable, VolumeComponentMenuForRenderPipeline("Custom/SnowEffect", typeof(UniversalRenderPipeline))]
public class SnowEffectComponent : VolumeComponent, IPostProcessComponent
{
    public ClampedFloatParameter intensity = new ClampedFloatParameter(value: 0, min: 0, max:1, overrideState:true);
    public IntParameter Offset = new IntParameter(value:0, false);

    public NoInterpColorParameter overlayColor = new NoInterpColorParameter(Color.cyan);

    public bool IsActive() => intensity.value > 0 ;

    public bool IsTileCompatible()=> true;


}
