Shader "LwyShaders/PBR/TinyPBR_Opaque"
{
    Properties
    {
        [Header(Base Settings)]
        [MainTexture] _BaseMap ("Albedo", 2D) = "white" { }
        [MainColor] _BaseColor ("BaseColor", color) = (1.0, 1.0, 1.0, 1.0)
        
        [Toggle(_ALPHATEST_ON)] _AlphaClip("Alpha Clipping", Float) = 0.0
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        [Space(20)]
        [Header(PBR Data)]
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
        _Metallic ("Metallic", Range(0, 1)) = 0
        
        [Toggle(_ENABLE_MASK_MAP)] _ENABLE_MASK_MAP ("Enable Mask Map", float) = 0.0
        // Unity 标准 Mask: R=Metallic, G=AO, A=Smoothness
        _MaskMap ("Mask map (R=Met, G=AO, A=Smooth)", 2D) = "white" { }
        
        // 【新增修复点1】增加 AO 强度控制
        _OcclusionStrength("Occlusion Strength", Range(0.0, 1.0)) = 0.0

        [Space(20)]
        [Header(High Quality Normal)]
        [Normal]_NormalMap ("Normal map", 2D) = "bump" { }
        _NormalScale ("Normal scale", Range(-2, 2)) = 1
        
        _DetailNormalMap ("Detail Normal map", 2D) = "bump" { }
        _DetailNormalScale ("Detail Normal Scale", Range(0, 2)) = 1.0

        [Space(20)]
        [Header(Emission)]
        _EmissionMap ("Emission Map", 2D) = "black" {}
        [HDR] _EmissionColor ("Emission Color", color) = (0, 0, 0, 0)

        [Header(Advanced)]
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull Mode", Float) = 2
    }

    SubShader
    {
        Tags 
        { 
            "RenderType"="Opaque" 
            "Queue"="Geometry" 
            "IgnoreProjector"="True" 
            "RenderPipeline"="UniversalPipeline" 
        }

        // =================================================================================
        // Pass 1: DepthOnly (保持不变)
        // =================================================================================
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}
            ZWrite On
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            #pragma multi_compile_instancing
            #pragma shader_feature_local _ALPHATEST_ON
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half _Cutoff;
            CBUFFER_END

            struct Attributes {
                float4 positionOS : POSITION;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct Varyings {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            Varyings DepthOnlyVertex(Attributes input) {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                return output;
            }
            half4 DepthOnlyFragment(Varyings input) : SV_TARGET {
                UNITY_SETUP_INSTANCE_ID(input);
                #if defined(_ALPHATEST_ON)
                    half alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _BaseColor.a;
                    clip(alpha - _Cutoff);
                #endif
                return 0;
            }
            ENDHLSL
        }

        // =================================================================================
        // Pass 2: ShadowCaster (保持不变)
        // =================================================================================
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #pragma multi_compile_instancing
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #pragma shader_feature_local _ALPHATEST_ON
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float3 _LightDirection;
            float3 _LightPosition;
            float4 _ShadowBias;
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half _Cutoff;
            CBUFFER_END

            struct Attributes {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct Varyings {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            float4 GetShadowPositionHClip(Attributes input) {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                float3 lightDirection = _LightDirection;
                float invNdotL = 1.0 - saturate(dot(lightDirection, normalWS));
                float scale = invNdotL * _ShadowBias.y;
                positionWS += normalWS * scale.xxx;
                positionWS += lightDirection * _ShadowBias.xxx;
                float4 positionCS = TransformWorldToHClip(positionWS);
                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif
                return positionCS;
            }
            Varyings ShadowPassVertex(Attributes input) {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                output.positionCS = GetShadowPositionHClip(input);
                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                return output;
            }
            half4 ShadowPassFragment(Varyings input) : SV_TARGET {
                UNITY_SETUP_INSTANCE_ID(input);
                #if defined(_ALPHATEST_ON)
                    half alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _BaseColor.a;
                    clip(alpha - _Cutoff);
                #endif
                return 0;
            }
            ENDHLSL
        }

        // =================================================================================
        // Pass 3: TinyPBR (Standard Smoothness Workflow)
        // =================================================================================
        Pass
        {
            Tags { "LightMode" = "UniversalForward" } 
            Name "TinyPBR"
            ZWrite On
            ZTest LEqual
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 2.0
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            
            // 如果你的场景有烘焙光照图，一定要加上这个 keyword，否则烘焙后也是黑的
            #pragma multi_compile _ LIGHTMAP_ON 

            #pragma shader_feature_local _ENABLE_MASK_MAP
            #pragma shader_feature_local _ALPHATEST_ON

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _DetailNormalMap_ST;
                half4 _BaseColor;
                half4 _EmissionColor;
                half _Metallic;
                half _Smoothness;
                half _NormalScale;
                half _DetailNormalScale;
                half _Cull;
                half _Cutoff;
                // 【新增修复点2】CBuffer中加入变量
                half _OcclusionStrength; 
            CBUFFER_END

            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);          SAMPLER(sampler_NormalMap);
            TEXTURE2D(_DetailNormalMap);    SAMPLER(sampler_DetailNormalMap);
            TEXTURE2D(_MaskMap);            SAMPLER(sampler_MaskMap);
            TEXTURE2D(_EmissionMap);        SAMPLER(sampler_EmissionMap);

            struct a2v {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 texcoord : TEXCOORD0;
                // 支持 Lightmap UV
                float2 texcoord1 : TEXCOORD1; 
            };

            struct v2f {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
                float2 uv : TEXCOORD3;
                float2 uvDetail : TEXCOORD4;
                float fogFactor : TEXCOORD5;
                // 支持 Lightmap UV
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 6);
            };

            half3 BlendNormalsRNM(half3 n1, half3 n2) {
                n1 += half3(0, 0, 1);
                n2 *= half3(-1, -1, 1);
                return n1 * dot(n1, n2) / n1.z - n2;
            }

            v2f vert(a2v input) {
                v2f o = (v2f)0;
                o.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                o.normalWS = normalInput.normalWS;
                o.tangentWS = float4(normalInput.tangentWS, input.tangentOS.w * GetOddNegativeScale());

                o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                o.uvDetail = TRANSFORM_TEX(input.texcoord, _DetailNormalMap);
                o.fogFactor = ComputeFogFactor(o.positionCS.z);
                
                // 处理 Lightmap 或 SH
                OUTPUT_LIGHTMAP_UV(input.texcoord1, unity_LightmapST, o.lightmapUV);
                OUTPUT_SH(o.normalWS, o.vertexSH);
                
                return o;
            }

            half4 frag(v2f input) : SV_TARGET {
                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 albedo = albedoAlpha.rgb * _BaseColor.rgb;
                half alpha = albedoAlpha.a * _BaseColor.a;

                #if defined(_ALPHATEST_ON)
                    clip(alpha - _Cutoff);
                #endif

                half metallic = _Metallic;
                half smoothness = _Smoothness;
                half occlusion = 1.0; // 默认为1 (不遮蔽)

                #if defined(_ENABLE_MASK_MAP)
                    half4 mask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);
                    metallic = mask.r * _Metallic;
                    // 【新增修复点3】使用 Lerp 安全地计算 AO
                    // 如果 mask.g 是 0，且 OcclusionStrength 是 1，结果是 0 (黑) -> 还是暗
                    // 如果 mask.g 是 0，但 OcclusionStrength 是 0，结果是 1 (亮) -> 修复问题
                    occlusion = lerp(1.0, mask.g, _OcclusionStrength);
                    smoothness = mask.a * _Smoothness; 
                #endif

                half3 normalBase = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv), _NormalScale);
                half3 normalDetail = UnpackNormalScale(SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailNormalMap, input.uvDetail), _DetailNormalScale);
                half3 normalTS = normalize(BlendNormalsRNM(normalBase, normalDetail));

                half3 bitangent = cross(input.normalWS, input.tangentWS.xyz) * input.tangentWS.w;
                half3x3 TBN = half3x3(input.tangentWS.xyz, bitangent, input.normalWS);
                half3 normalWS = normalize(mul(normalTS, TBN));

                half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

                BRDFData brdfData;
                InitializeBRDFData(albedo, metallic, 0, smoothness, alpha, brdfData);

                // GI: 使用 Lightmap 或 SH
                half3 bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, normalWS);
                
                // 计算 GI 时的 occlusion
                half3 color = GlobalIllumination(brdfData, bakedGI, occlusion, input.positionWS, normalWS, viewDirWS);

                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                color += LightingPhysicallyBased(brdfData, mainLight, normalWS, viewDirWS);

                #ifdef _ADDITIONAL_LIGHTS
                uint pixelLightCount = GetAdditionalLightsCount();
                for(uint lightIndex = 0; lightIndex < pixelLightCount; ++lightIndex) {
                    Light light = GetAdditionalLight(lightIndex, input.positionWS);
                    color += LightingPhysicallyBased(brdfData, light, normalWS, viewDirWS);
                }
                #endif

                half3 emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv).rgb * _EmissionColor.rgb;
                color += emission;

                color = MixFog(color, input.fogFactor);

                return half4(color, alpha);
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
