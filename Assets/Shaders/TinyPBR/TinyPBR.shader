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
        [Header(UE5 Style PBR)]
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
        _Metallic ("Metallic", Range(0, 1)) = 0
        // UE5 F0 控制: 0.5 -> F0=0.04 (塑料/水), 0.0 -> 0.0 (黑洞), 1.0 -> 0.08 (宝石)
        _Specular ("Specular Level", Range(0, 1)) = 0.5
        
        [Toggle(_ENABLE_MASK_MAP)] _ENABLE_MASK_MAP ("Enable Mask Map", float) = 0.0
        // R=Metallic, G=AO, A=Smoothness
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
        // Pass 1: DepthOnly (Z-Prepass)
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
        // Pass 2: ShadowCaster (投射阴影)
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
        // Pass 3: Forward Rendering (PBR Main)
        // =================================================================================
        Pass
        {
            Tags { "LightMode" = "UniversalForward" } 
            Name "TinyPBR"
            ZWrite On
            ZTest LEqual
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            // URP 14+ 关键字: 主光阴影(包含屏幕空间)、Forward+、额外光、软阴影、光照图
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            #pragma multi_compile _ LIGHTMAP_ON 
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING

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
                float fogFactor : TEXCOORD5;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 6);
            };

            // RNM 法线混合算法
            half3 BlendNormalsRNM(half3 n1, half3 n2) {
                n1 += half3(0, 0, 1);
                n2 *= half3(-1, -1, 1);
                return n1 * dot(n1, n2) / n1.z - n2;
            }
            
            // -------------------------------------------------------------------------
            // PBR 核心数学函数 (UE5 标准)
            // -------------------------------------------------------------------------
            
            // 辅助: 5次方计算
            float Tiny_Pow5(float x) 
            {
                return x * x * x * x * x;
            }

            // Diffuse: Disney/Burley 模型 (考虑边缘粗糙度回射)
            float Tiny_DisneyDiffuse(float NdotV, float NdotL, float LdotH, float perceptualRoughness)
            {
                float fd90 = 0.5 + 2 * LdotH * LdotH * perceptualRoughness;
                float lightScatter = (1 + (fd90 - 1) * Tiny_Pow5(1 - NdotL));
                float viewScatter = (1 + (fd90 - 1) * Tiny_Pow5(1 - NdotV));
                return lightScatter * viewScatter;
            }

            // Specular D: Trowbridge-Reitz GGX (法线分布)
            float Tiny_D_GGX(float NdotH, float roughness)
            {
                float a = roughness * roughness;
                float a2 = a * a;
                float d = (NdotH * a2 - NdotH) * NdotH + 1.0f; 
                return a2 / (PI * d * d);
            }

            // Specular V: Smith Joint GGX Correlated (几何遮蔽)
            float Tiny_V_SmithGGXCorrelated(float NdotL, float NdotV, float roughness)
            {
                float a = roughness * roughness;
                float LambdaV = NdotL * sqrt((-NdotV * a + NdotV) * NdotV + a);
                float LambdaL = NdotV * sqrt((-NdotL * a + NdotL) * NdotL + a);
                return 0.5f / (LambdaV + LambdaL + 1e-5f);
            }

            // PBR 直接光照计算入口
            half3 TinyPBR_DirectLight(Light light, float3 normalWS, float3 viewDirWS, 
                                      float3 albedo, float roughness, float perceptualRoughness, 
                                      float3 F0, float occlusion)
            {
                // 1. 向量准备
                float3 lightDirWS = light.direction;
                float3 halfDir = normalize(lightDirWS + viewDirWS);

                // 2. 点积计算
                float NdotL = saturate(dot(normalWS, lightDirWS));
                float NdotV = saturate(dot(normalWS, viewDirWS));
                float NdotH = saturate(dot(normalWS, halfDir));
                float LdotH = saturate(dot(lightDirWS, halfDir));

                // 3. 辐射率 (颜色 * 衰减 * 阴影)
                float attenuation = light.distanceAttenuation * light.shadowAttenuation;
                float3 radiance = light.color * attenuation;

                // 4. 漫反射项 (Disney)
                float diffuseTerm = Tiny_DisneyDiffuse(NdotV, NdotL, LdotH, perceptualRoughness) * NdotL;

                // 5. 高光项 (Cook-Torrance: D * V * F)
                float D = Tiny_D_GGX(NdotH, roughness);
                float V = Tiny_V_SmithGGXCorrelated(NdotL, NdotV, roughness);
                float3 F = F_Schlick(F0, LdotH); // 菲涅尔

                float3 specularTerm = D * V * F;
                specularTerm = max(0, specularTerm * NdotL);

                // 6. 微表面遮蔽 (AO 抑制缝隙高光)
                float specularOcclusion = lerp(1.0, occlusion, perceptualRoughness);
                specularTerm *= specularOcclusion;

                // 7. 能量守恒合成 (kD + Specular)
                float3 kS = F;
                float3 kD = (1.0 - kS);
                
                return (kD * albedo * diffuseTerm + specularTerm) * radiance;
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
                
                OUTPUT_LIGHTMAP_UV(input.texcoord1, unity_LightmapST, o.lightmapUV);
                OUTPUT_SH(o.normalWS, o.vertexSH);
                
                return o;
            }

            half4 frag(v2f input) : SV_TARGET {
                // ---------------------------------------------------------
                // 1. 数据采样
                // ---------------------------------------------------------
                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 albedo = albedoAlpha.rgb * _BaseColor.rgb;
                half alpha = albedoAlpha.a * _BaseColor.a;

                #if defined(_ALPHATEST_ON)
                    clip(alpha - _Cutoff);
                #endif

                half metallic = _Metallic;
                half smoothness = _Smoothness;
                half occlusion = 1.0;
                
                #if defined(_ENABLE_MASK_MAP)
                    half4 mask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);
                    metallic = mask.r * _Metallic;
                    occlusion = lerp(1.0, mask.g, _OcclusionStrength);
                    smoothness = mask.a * _Smoothness; 
                #endif

                // ---------------------------------------------------------
                // 2. 法线重建 (RNM 混合)
                // ---------------------------------------------------------
                half3 normalBase = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv), _NormalScale);
                half3 normalDetail = UnpackNormalScale(SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailNormalMap, input.uvDetail), _DetailNormalScale);
                half3 normalTS = normalize(BlendNormalsRNM(normalBase, normalDetail));
                half3 bitangent = cross(input.normalWS, input.tangentWS.xyz) * input.tangentWS.w;
                half3x3 TBN = half3x3(input.tangentWS.xyz, bitangent, input.normalWS);
                half3 normalWS = normalize(mul(normalTS, TBN));

                half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

                // ---------------------------------------------------------
                // 3. 物理参数准备 (Roughness & F0)
                // ---------------------------------------------------------
                float perceptualRoughness = 1.0 - smoothness;
                float roughness = max(perceptualRoughness * perceptualRoughness, 0.002);

                // F0: 电介质使用 0.08 * Specular，金属使用 Albedo
                float3 f0 = 0.08 * _Specular;
                f0 = lerp(f0, albedo, metallic);
                
                // 金属没有漫反射颜色
                half3 diffuseColor = albedo * (1.0 - metallic);

                // ---------------------------------------------------------
                // 4. 全局光照 (Indirect Light)
                // ---------------------------------------------------------
                BRDFData brdfData;
                InitializeBRDFData(albedo, metallic, half3(0,0,0), smoothness, alpha, brdfData);
                half3 bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, normalWS);
                half3 color = GlobalIllumination(brdfData, bakedGI, occlusion, input.positionWS, normalWS, viewDirWS);

                // ---------------------------------------------------------
                // 5. 直接光照 (UE5 PBR)
                // ---------------------------------------------------------
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                
                color += TinyPBR_DirectLight(mainLight, normalWS, viewDirWS, diffuseColor, roughness, perceptualRoughness, f0, occlusion);

                // 6. 额外光源 (Forward+)
                #ifdef _ADDITIONAL_LIGHTS
                uint pixelLightCount = GetAdditionalLightsCount();
                for(uint lightIndex = 0; lightIndex < pixelLightCount; ++lightIndex) {
                    Light light = GetAdditionalLight(lightIndex, input.positionWS);
                    color += TinyPBR_DirectLight(light, normalWS, viewDirWS, diffuseColor, roughness, perceptualRoughness, f0, occlusion);
                }
                #endif

                // 7. 自发光与雾
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