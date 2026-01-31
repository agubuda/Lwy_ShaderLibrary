Shader "LwyShaders/Matcap" {
    Properties {
        [Space(20)][Header(Base Settings)]
        [MainTexture] _BaseMap ("Texture", 2D) = "white" { }
        [MainColor] _BaseColor ("Base Color", Color) = (0, 0, 0, 1)
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull Mode", Float) = 2

        [Space(20)][Header(Matcap Settings)]
        _MatCap ("Mat Cap", 2D) = "black" { }
        _MatCapIntensity ("Matcap Intensity", float) = 1

        [Space(20)][Header(Normal Map)]
        [Toggle(_ENABLENORMALMAP)] _ENABLENORMALMAP ("Enable Normal Map", float) = 0
        [Normal] _NormalMap ("Normal Map", 2D) = "bump" { }
        _NormalScale ("Normal Scale", float) = 1

        [Space(20)][Header(Rim Light)]
        [HDR]_RimColor ("Rim Color", Color) = (0.8, 0.7, 0.7, 1)
        _FresnelPower ("Fresnel Power", Range(0, 10)) = 3
        _FresnelStepValue ("Fresnel Smooth Min", Range(0, 1)) = 0.1
        _FresnelStepValue2 ("Fresnel Smooth Max", Range(0, 1)) = 0.2

        [Space(20)][Header(Mask Map)]
        _MaskMap ("Mask Map (R=Rim Mask, G=AO)", 2D) = "white" { }
        _AOPower ("AO Power", Range(0, 6)) = 1
    }

    SubShader {
        Tags { "Queue" = "Geometry" "RenderType" = "Opaque" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }

        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float4 _MatCap_ST;
                float _MatCapIntensity;
                float4 _NormalMap_ST;
                float _NormalScale;
                float4 _RimColor;
                float _FresnelPower;
                float _FresnelStepValue;
                float _FresnelStepValue2;
                float4 _MaskMap_ST;
                float _AOPower;
                float _Cull;
            CBUFFER_END

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MatCap); SAMPLER(sampler_MatCap);
            TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MaskMap); SAMPLER(sampler_MaskMap);

            // ShadowCaster helper
            half Alpha(float2 uv) {
                return SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv).a * _BaseColor.a;
            }
        ENDHLSL

        Pass {
            Name "MatcapPass"
            Tags { "LightMode" = "UniversalForward" }

            Cull [_Cull]
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma shader_feature _ENABLENORMALMAP

            struct Attributes {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Varyings {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 tangentWS : TEXCOORD2;
                float3 bitangentWS : TEXCOORD3;
                float2 uv : TEXCOORD4;
            };

            Varyings vert(Attributes input) {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                
                // Helper to calculate world normal, tangent, bitangent
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.normalWS = normalInput.normalWS;
                output.tangentWS = normalInput.tangentWS;
                output.bitangentWS = normalInput.bitangentWS;
                
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                return output;
            }

            half4 frag(Varyings input) : SV_TARGET {
                // 1. Normal Processing
                float3 normalWS = normalize(input.normalWS);
                float3 tangentWS = normalize(input.tangentWS);
                float3 bitangentWS = normalize(input.bitangentWS);

                #if _ENABLENORMALMAP
                    float4 normalSample = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv);
                    float3 normalTangent = UnpackNormalScale(normalSample, _NormalScale);
                    // Standard TBN
                    float3x3 tbn = float3x3(tangentWS, bitangentWS, normalWS);
                    normalWS = normalize(mul(normalTangent, tbn));
                #endif

                // 2. Matcap Lookup (View Space Normal)
                // Crucial: Calculate this AFTER normal mapping
                float3 normalVS = TransformWorldToViewNormal(normalWS);
                // Map [-1, 1] to [0, 1]
                float2 matcapUV = normalVS.xy * 0.5 + 0.5;
                half4 matcapColor = SAMPLE_TEXTURE2D(_MatCap, sampler_MatCap, matcapUV);

                // 3. Base Properties
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half4 baseColor = baseMap * _BaseColor;
                
                // 4. Lighting & Rim
                float3 viewDir = normalize(GetWorldSpaceViewDir(input.positionWS));

                // Rim
                float NdotV = saturate(dot(normalWS, viewDir));
                float fresnel = pow(1.0 - NdotV, _FresnelPower);
                float rimMask = smoothstep(_FresnelStepValue, _FresnelStepValue2, fresnel);
                
                // Mask Map (R=Rim Mask, G=AO)
                half4 maskMap = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);
                rimMask *= maskMap.r; 
                
                half3 finalRim = _RimColor.rgb * rimMask;

                // Combine: Base + Matcap + Rim
                // Matcap usually replaces lighting, but here it's added/blended
                half3 finalColor = baseColor.rgb + (matcapColor.rgb * _MatCapIntensity);
                finalColor += finalRim;

                return half4(finalColor, baseColor.a);
            }
            ENDHLSL
        }

        Pass {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            // This include relies on 'Alpha(uv)' being defined in HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
}
