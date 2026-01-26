Shader "LwyShaders/NPR/Hair_Simple_Anisotropy_IndependentNoise" {
    Properties {
        [Header(Base Settings)]
        [MainTexture] _BaseMap ("Base Map (Albedo)", 2D) = "white" { }
        [MainColor] _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _Cutoff ("Alpha Clip Threshold", Range(0.0, 1.0)) = 0.5

        [Header(NPR Diffuse)]
        [NoScaleOffset] _RampMap ("Ramp Map (Gradient)", 2D) = "white" { }
        _ShadowStrength ("Shadow Influence", Range(0, 1)) = 1

        [Header(Normal)]
        _NormalMap ("Normal Map", 2D) = "bump" { }
        _NormalScale ("Normal Scale", float) = 1.0

        [Header(Anisotropy Specular)]
        // Unity 会自动在此纹理旁显示 Tiling 和 Offset，我们将在代码中应用它
        _NoiseMap ("Flow/Noise Map", 2D) = "white" { }
        _SpecColor ("Specular Color", Color) = (1, 1, 1, 1)
        _SpecPower ("Glossiness", Range(1, 500)) = 100
        _AnisotropyShift ("Highlight Shift", Range(-1, 1)) = 0.1
        _AnisotropyNoisePower ("Noise Strength", Range(0, 1)) = 0.5
        _AnisotropyIntensity ("Intensity", Range(0, 10)) = 1
    }

    SubShader {
        Tags { 
            "RenderType" = "TransparentCutout" 
            "Queue" = "AlphaTest" 
            "RenderPipeline" = "UniversalPipeline" 
            "IgnoreProjector" = "True" 
        }

        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float _Cutoff;
                
                float _ShadowStrength;
                
                float4 _NormalMap_ST;
                float _NormalScale;
                
                // --- 必须声明这个变量来接收面板上的 Tiling/Offset ---
                float4 _NoiseMap_ST; 
                
                float4 _SpecColor;
                float _SpecPower;
                float _AnisotropyShift;
                float _AnisotropyNoisePower; 
                float _AnisotropyIntensity;
            CBUFFER_END
            
            TEXTURE2D(_BaseMap);    SAMPLER(sampler_BaseMap);
            TEXTURE2D(_RampMap);    SAMPLER(sampler_RampMap);
            TEXTURE2D(_NormalMap);  SAMPLER(sampler_NormalMap);
            TEXTURE2D(_NoiseMap);   SAMPLER(sampler_NoiseMap);
        ENDHLSL

        Pass {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" } 
            Cull Off

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fog

            struct a2v {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 tangentWS : TEXCOORD2; 
                float3 bitangentWS : TEXCOORD3;
                float2 uv : TEXCOORD4;
                // --- 新增：专门用于 Noise Map 的 UV ---
                float2 uvNoise : TEXCOORD5; 
                float4 shadowCoord : TEXCOORD6;
                float fogFactor : TEXCOORD7;
            };

            v2f vert(a2v input) {
                v2f o;
                o.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                
                o.normalWS = TransformObjectToWorldNormal(input.normalOS);
                o.tangentWS = TransformObjectToWorldDir(input.tangentOS.xyz);
                
                float sign = input.tangentOS.w * unity_WorldTransformParams.w;
                o.bitangentWS = cross(o.normalWS, o.tangentWS) * sign;

                // 基础 UV (BaseMap, NormalMap 共用)
                o.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                
                // --- 独立计算 Noise UV ---
                // 使用 TRANSFORM_TEX 宏，它会自动读取 _NoiseMap_ST 中的 Tiling 和 Offset
                o.uvNoise = TRANSFORM_TEX(input.uv, _NoiseMap);

                o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
                o.fogFactor = ComputeFogFactor(o.positionCS.z);
                return o;
            }

            float3 KajiyaKaySpecular(float3 tangent, float3 normal, float3 halfDir, float power, float intensity, float shift, float noiseVal, float noisePower) 
            {
                float shiftAmount = shift + (noiseVal - 0.5) * noisePower;
                float3 shiftedTangent = normalize(tangent + normal * shiftAmount);
                float dotTH = dot(shiftedTangent, halfDir);
                float sinTH = sqrt(1.0 - dotTH * dotTH);
                return pow(saturate(sinTH), power) * intensity;
            }

            half4 frag(v2f input) : SV_TARGET {
                float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                clip(baseMap.a - _Cutoff);

                // --- 使用独立的 uvNoise 进行采样 ---
                // 现在你可以通过材质球上 Noise Map 旁边的 Tiling 属性来控制噪点的疏密了
                float noiseVal = SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, input.uvNoise).r;

                float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv), _NormalScale);
                float3x3 tbn = float3x3(normalize(input.tangentWS), normalize(input.bitangentWS), normalize(input.normalWS));
                float3 normalWS = normalize(TransformTangentToWorld(normalTS, tbn));
                
                float3 hairStrandDir = normalize(input.bitangentWS); 
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);

                Light mainLight = GetMainLight(input.shadowCoord);
                float3 lightDir = normalize(mainLight.direction);
                float shadowAtten = mainLight.shadowAttenuation;
                float3 lightColor = mainLight.color * mainLight.distanceAttenuation;
                float3 halfDir = normalize(lightDir + viewDir);

                // --- Ramp Diffuse ---
                float NdotL = dot(normalWS, lightDir);
                float halfLambert = NdotL * 0.5 + 0.5;
                float rampCoord = saturate(halfLambert * lerp(1.0, shadowAtten, _ShadowStrength));
                float3 rampColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(rampCoord, 0.5)).rgb;
                float3 diffuseTerm = baseMap.rgb * _BaseColor.rgb * rampColor * lightColor;

                // --- Specular ---
                float specValue = KajiyaKaySpecular(
                    hairStrandDir, 
                    normalWS, 
                    halfDir, 
                    _SpecPower, 
                    _AnisotropyIntensity, 
                    _AnisotropyShift, 
                    noiseVal, 
                    _AnisotropyNoisePower
                );
                
                float3 specularTerm = specValue * _SpecColor.rgb * lightColor * shadowAtten;

                float3 finalRGB = diffuseTerm + specularTerm;
                finalRGB = MixFog(finalRGB, input.fogFactor);

                return float4(finalRGB, 1.0);
            }
            ENDHLSL
        }

        // DepthOnly Pass 不需要改动 UV，因为它只负责镂空，镂空通常依赖 BaseMap
        Pass {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask 0
            Cull Off
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            struct Attributes {
                float4 position : POSITION;
                float2 texcoord : TEXCOORD0;
            };
            struct Varyings {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            Varyings DepthOnlyVertex(Attributes input) {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.position.xyz);
                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                return output;
            }
            half DepthOnlyFragment(Varyings input) : SV_TARGET {
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                clip(baseColor.a - _Cutoff);
                return input.positionCS.z;
            }
            ENDHLSL
        }

        Pass {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off
            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
}