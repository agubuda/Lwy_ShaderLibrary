Shader "LwyShaders/HairShadowSystem/Receiver"
{
    Properties
    {
        _ShadowColor ("Shadow Color", Color) = (0.5, 0.4, 0.4, 0.5)
        _StencilRef ("Stencil Ref ID", Int) = 128
    }
    SubShader
    {
        // 必须晚于 Caster 渲染 (Caster 是 Geometry+10，这里 +20)
        Tags { "RenderType"="Transparent" "Queue"="Geometry+20" "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            Name "HairShadowReceiver"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest LEqual
            Cull Back

            Stencil
            {
                Ref [_StencilRef]
                Comp Equal // 只有 Stencil 匹配的地方才画
                Pass Keep
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _ShadowColor;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            half4 frag(Varyings input) : SV_TARGET
            {
                return _ShadowColor;
            }
            ENDHLSL
        }
    }
}