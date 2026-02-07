Shader "LwyShaders/PBR/TinyPBR_Transparent"
{
    Properties
    {
        [Header(Base Settings)]
        [MainTexture] _BaseMap ("Albedo", 2D) = "white" { }
        [MainColor] _BaseColor ("BaseColor", color) = (1.0, 1.0, 1.0, 1.0)
        
        [Space(20)]
        [Header(UE5 Style PBR)]
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
        _Metallic ("Metallic", Range(0, 1)) = 0
        _Specular ("Specular Level", Range(0, 1)) = 0.5
        
        [Toggle(_ENABLE_MASK_MAP)] _ENABLE_MASK_MAP ("Enable Mask Map", float) = 0.0
        _MaskMap ("Mask map (R=Met, G=AO, A=Smooth)", 2D) = "white" { }
        
        _OcclusionStrength("Occlusion Strength", Range(0.0, 1.0)) = 1.0

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
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 5 // SrcAlpha
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 10 // OneMinusSrcAlpha
        [Toggle] _ZWrite ("ZWrite", Float) = 1
    }

    SubShader
    {
        Tags 
        { 
            "RenderType"="Transparent" 
            "Queue"="Transparent" 
            "IgnoreProjector"="True" 
            "RenderPipeline"="UniversalPipeline" 
        }

        // =================================================================================
        // Pass 1: Forward Rendering (PBR Main)
        // =================================================================================
        Pass
        {
            Tags { "LightMode" = "UniversalForward" } 
            Name "TinyPBR_Transparent"
            
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            ZTest LEqual
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "TinyPBRCommon.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile_fog
            #pragma multi_compile _ LIGHTMAP_ON 
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING

            #pragma shader_feature_local _ENABLE_MASK_MAP

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
                half _OcclusionStrength;
                half _Specular; 
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
                float2 texcoord1 : TEXCOORD1; 
            };

            struct v2f {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
                float2 uv : TEXCOORD3;
                float2 uvDetail : TEXCOORD4;
                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    half4 fogFactorAndVertexLight : TEXCOORD5;
                #else
                    float fogFactor : TEXCOORD5;
                #endif
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 6);
            };

            v2f vert(a2v input) {
                v2f o = (v2f)0;
                o.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                o.normalWS = normalInput.normalWS;
                o.tangentWS = float4(normalInput.tangentWS, input.tangentOS.w * GetOddNegativeScale());

                o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                o.uvDetail = TRANSFORM_TEX(input.texcoord, _DetailNormalMap);

                half fogFactor = ComputeFogFactor(o.positionCS.z);
                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    half3 vertexLight = VertexLighting(o.positionWS, o.normalWS);
                    o.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
                #else
                    o.fogFactor = fogFactor;
                #endif
                
                OUTPUT_LIGHTMAP_UV(input.texcoord1, unity_LightmapST, o.lightmapUV);
                OUTPUT_SH(o.normalWS, o.vertexSH);
                
                return o;
            }

            half4 frag(v2f input) : SV_TARGET {
                // 1. Data Sampling
                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 albedo = albedoAlpha.rgb * _BaseColor.rgb;
                half alpha = albedoAlpha.a * _BaseColor.a;

                half metallic = _Metallic;
                half smoothness = _Smoothness;
                half occlusion = 1.0;
                
                #if defined(_ENABLE_MASK_MAP)
                    half4 mask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);
                    metallic = mask.r * _Metallic;
                    occlusion = lerp(1.0, mask.g, _OcclusionStrength);
                    smoothness = mask.a * _Smoothness; 
                #endif

                // 2. Normal Reconstruction (RNM Blend)
                half3 normalBase = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv), _NormalScale);
                half3 normalDetail = UnpackNormalScale(SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailNormalMap, input.uvDetail), _DetailNormalScale);
                half3 normalTS = normalize(BlendNormalsRNM(normalBase, normalDetail));
                
                half3 bitangent = cross(input.normalWS, input.tangentWS.xyz) * input.tangentWS.w;
                half3x3 TBN = half3x3(input.tangentWS.xyz, bitangent, input.normalWS);
                half3 normalWS = normalize(mul(normalTS, TBN));

                half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

                // 3. Physical Params
                float perceptualRoughness = 1.0 - smoothness;
                // Clamp roughness to prevent singular highlight at smoothness=1.0
                float roughness = max(perceptualRoughness * perceptualRoughness, 0.01);

                float3 f0 = 0.08 * _Specular;
                f0 = lerp(f0, albedo, metallic);
                half3 diffuseColor = albedo * (1.0 - metallic);

                // 4. GI
                BRDFData brdfData;
                InitializeBRDFData(albedo, metallic, half3(0,0,0), smoothness, alpha, brdfData);
                
                half3 bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, normalWS);
                half3 color = GlobalIllumination(brdfData, bakedGI, occlusion, input.positionWS, normalWS, viewDirWS);

                // 5. Direct Light (PBR)
                half4 shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoord, input.positionWS, shadowMask);
                
                color += TinyPBR_DirectLight(mainLight, normalWS, viewDirWS, diffuseColor, roughness, perceptualRoughness, f0, occlusion);

                // 6. Additional Lights
                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    half3 vertexLight = input.fogFactorAndVertexLight.yzw;
                #else
                    half3 vertexLight = 0;
                #endif

                color += TinyPBR_AccumulateAdditionalLights(
                    input.positionWS,
                    input.positionCS,
                    normalWS,
                    viewDirWS,
                    diffuseColor,
                    roughness,
                    perceptualRoughness,
                    f0,
                    occlusion,
                    shadowMask,
                    vertexLight);

                // 7. Emission & Fog
                half3 emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv).rgb * _EmissionColor.rgb;
                color += emission;

                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    color = MixFog(color, input.fogFactorAndVertexLight.x);
                #else
                    color = MixFog(color, input.fogFactor);
                #endif

                return half4(color, alpha);
            }
            ENDHLSL
        }

        // =================================================================================
        // Pass 2: DepthOnly
        // =================================================================================
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}
            ZWrite [_ZWrite]
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            #pragma multi_compile_instancing
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
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
                return 0;
            }
            ENDHLSL
        }

        // =================================================================================
        // Pass 3: ShadowCaster
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float3 _LightDirection;
            float3 _LightPosition;
            float4 _ShadowBias;
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
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
                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDirection = normalize(_LightPosition - positionWS);
                #else
                    float3 lightDirection = _LightDirection;
                #endif
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
                return 0;
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
