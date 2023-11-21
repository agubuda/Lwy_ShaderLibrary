Shader "LwyShaders/BaseUnlit"
{
    Properties
    { 
        [MainColor] _BaseColor ("BaseColor", color) = (1.0, 1.0, 1.0, 1.0)
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings
            {
                // 此结构中的位置必须具有 SV_POSITION 语义。
                float4 positionHCS  : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)

                half4 _BaseColor;

            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                return OUT;
            }

            half4 frag() : SV_Target
            {
                half4 customColor = _BaseColor;
                return customColor;
            }
            ENDHLSL
        }
    }
}
