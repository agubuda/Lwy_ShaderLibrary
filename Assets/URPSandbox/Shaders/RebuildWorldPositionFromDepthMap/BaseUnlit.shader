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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

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

            half4 frag(Varyings IN) : SV_Target
            {
                float2 UV = IN.positionHCS.xy / _ScaledScreenParams.xy;
                #if UNITY_REVERSED_Z
                    float depth = SampleSceneDepth(UV);
                #else
                    //调整z
                    float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1 ,SampleSceneDepth(UV));
                #endif

                float3 worldPos = ComputeWorldSpacePosition(UV, depth, UNITY_MATRIX_I_VP);
                uint scale = 10;
                // 缩放、镜像和捕捉坐标。
                uint3 worldIntPos = uint3(abs(worldPos.xyz * scale));
                // 将表面划分为正方形。计算颜色 ID 值。
                bool white = ((worldIntPos.x) & 1) ^ (worldIntPos.y & 1) ^ (worldIntPos.z & 1);
                // 根据 ID 值（黑色或白色）为正方形着色。
                half4 color = white ? half4(1,1,1,1) : half4(0,0,0,1);

                // 在远裁剪面附近将颜色设置为
                // 黑色。
                #if UNITY_REVERSED_Z
                    // 具有 REVERSED_Z 的平台（如 D3D）的情况。
                    if(depth < 0.0001)
                        return half4(0,0,0,1);
                #else
                    // 没有 REVERSED_Z 的平台（如 OpenGL）的情况。
                    if(depth > 0.9999)
                        return half4(0,0,0,1);
                #endif

                return half4(worldPos,1.0);
                return color;
            }
            ENDHLSL
        }
    }
}
