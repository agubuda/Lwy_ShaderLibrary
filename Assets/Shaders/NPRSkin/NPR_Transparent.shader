Shader "LwyShaders/NPR/NPR_Transparent" {
    Properties {
        [Header(Base Settings)]
        [MainTexture] _BaseMap ("Albedo", 2D) = "white" { }
        [MainColor] _BaseColor ("Base Color", Color) =  (1,1,1,1)
        
        // ZWrite: 头发建议 On (1), 纯特效建议 Off (0)
        [Enum(Off, 0, On, 1)] _ZWrite("Z Write", Float) = 1.0
        [Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows("Receive Shadows", Float) = 1.0

        // Normal
        [Toggle(_ENABLENORMALMAP)] _ENABLENORMALMAP ("Enable normal map", float) = 0
        [Normal] _BumpMap ("Normal map", 2D) = "bump" { }

        // Ramp
        [Space(10)]
        _RampMap ("Ramp Map", 2D) = "White" { }
        _RampColum ("Ramp colum", Range(0,1)) = 0.8

        // Specular
        [Space(10)]
        [HDR]_SpecColor("_SpecColor", color) = (1.0, 1.0, 1.0, 1.0)
        _SpecWidth ("Specular Width", Range(0, 1)) = 0.05       
        _SpecSoftness ("Specular Softness", Range(0.001, 1)) = 0.01 
        _SpecLightAlign ("Spec Light Align (Face/Hair Correction)", Range(0, 1)) = 0.0

        // Rim Light
        [Space(10)]
        _RimColor ("RimColor", color) = (0.8, 0.9, 0.9, 1)
        _RimWidth ("Rim Width", Range(0, 1)) = 0.1         
        _RimSoftness ("Rim Softness", Range(0.001, 1)) = 0.01 
        _RimLightAlign ("Rim Light Align", Range(-1, 1)) = 0.0 

        // Masks (AO & Smoothness)
        [Space(10)]
        _MaskMap ("Mask Map (G=AO, A=Smoothness)", 2D) = "white" { }
        [Toggle(_ENABLEAO)] _ENABLEAO ("Enable AO", float) = 1
        _OcclusionStrength ("AO Strength", Range(0, 1)) = 1.0
        [Toggle(_ENABLE_SMOOTHNESS_MASK)] _ENABLE_SMOOTHNESS_MASK ("Enable Smoothness Mask", float) = 1

        // Emission
        [Space(10)]
        [Toggle(_USE_EMISSION)] _UseEmission ("Enable Emission", Float) = 0
        _EmissionMap ("Emission Map", 2D) = "white" {}
        [HDR] _EmissionColor ("Emission Color", Color) = (1,1,1,1)
        _EmissionStrength ("Emission Strength", Range(0, 10)) = 1

        // Environment
        [Space(10)]
        [Toggle(_ENABLEENVIROMENTLIGHT)] _ENABLEENVIROMENTLIGHT ("Enable enviroment light", Float) = 0.0
        _LightInfluence ("Light influence", Range(0.1, 1.5)) = 1
        _ShadowEnvMix ("Shadow Light Mix", Range(0, 1)) = 0.2
    }

    SubShader {
        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }

        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST, _BaseColor, _RimColor, _SpecColor, _EmissionColor;
                float4 _BumpMap_ST;
                float _RampColum, _RimWidth, _RimSoftness, _RimLightAlign;
                float _SpecWidth, _SpecSoftness, _SpecLightAlign;
                float _LightInfluence, _ShadowEnvMix;
                float _OcclusionStrength, _EmissionStrength;
                float _ZWrite, _ReceiveShadows;
            CBUFFER_END

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_RampMap); SAMPLER(sampler_RampMap);
            TEXTURE2D(_MaskMap); SAMPLER(sampler_MaskMap);
            TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);
            TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);

            struct a2v {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float2 uv : TEXCOORD2;
                float3 normalWS : TEXCOORD3;
                float4 shadowCoord : TEXCOORD4;
                float4 tangentWS : TEXCOORD5;
                float3 bitangentWS : TEXCOORD6;
            };

            v2f vert(a2v input) {
                v2f o;
                o.positionCS = TransformObjectToHClip(input.positionOS);
                o.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(input.normalOS.xyz, true);
                o.tangentWS = float4(TransformObjectToWorldDir(input.tangentOS.xyz, true), input.tangentOS.w);
                o.bitangentWS = normalize(cross(o.normalWS, o.tangentWS.xyz) * input.tangentOS.w);
                o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
                o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                return o;
            }

            float4 frag(v2f input, bool isFrontFace : SV_IsFrontFace) : SV_TARGET {
                float3 positionVS = TransformWorldToView(input.positionWS);
                
                // --- 1. Light & Vectors ---
                Light MainLight;
                #if defined(_RECEIVE_SHADOWS)
                    MainLight = GetMainLight(input.shadowCoord);
                #else
                    MainLight = GetMainLight();
                    MainLight.shadowAttenuation = 1.0;
                #endif
                
                float3 LightDir = normalize(MainLight.direction);
                float3 LightColor = MainLight.color;
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);

                // Specular Correction: Align light to ViewDir (XZ Plane)
                float3 lightDirXZ = normalize(float3(LightDir.x, 0, LightDir.z) + 1e-5);
                float3 viewDirXZ  = normalize(float3(viewDir.x,  0, viewDir.z)  + 1e-5);
                float3 blendedXZ = lerp(lightDirXZ, viewDirXZ, _SpecLightAlign);
                float3 specLightDir = normalize(float3(blendedXZ.x, LightDir.y, blendedXZ.z));

                // --- 2. Normal Mapping ---
                #if _ENABLENORMALMAP
                    float sgn = input.tangentWS.w;
                    half4 normalMap = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv.xy);
                    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                    input.normalWS = TransformTangentToWorld(UnpackNormal(normalMap), half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
                #endif
                float3 normalWS = NormalizeNormalPerPixel(input.normalWS);

                // --- 3. Double Sided Logic ---
                if (!isFrontFace) {
                    normalWS = -normalWS;              // Flip Normal
                    MainLight.shadowAttenuation = 1.0; // Remove Shadow on Backfaces (Cleaner look)
                }

                // --- 4. Sampling Masks (AO / Smoothness) ---
                float ao = 1.0;
                float smoothnessMask = 1.0;
                #if defined(_ENABLEAO) || defined(_ENABLE_SMOOTHNESS_MASK)
                    float4 maskSample = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);
                    #if defined(_ENABLEAO)
                        ao = lerp(1.0, maskSample.g, _OcclusionStrength);
                    #endif
                    #if defined(_ENABLE_SMOOTHNESS_MASK)
                        smoothnessMask = maskSample.a;
                    #endif
                #endif

                // --- 5. Diffuse Calculation (Ramp) ---
                float Lambert = dot(LightDir, normalWS) * MainLight.shadowAttenuation;
                float halfLambert = Lambert * 0.5 + 0.5;
                float rampCoord = saturate(halfLambert * ao); // Apply AO to dark area
                
                float4 rampColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(rampCoord, _RampColum));
                float4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;

                // --- 6. Specular Calculation (Aligned) ---
                float3 HalfWay = normalize(viewDir + specLightDir);
                float NdotH = saturate(dot(normalWS, HalfWay));
                float specShape = smoothstep(1.0 - _SpecWidth, 1.0 - _SpecWidth + _SpecSoftness, NdotH);
                
                // Fresnel term
                float LdotH = saturate(dot(specLightDir, HalfWay));
                float fresnelTerm = 0.04 + (1.0 - 0.04) * pow(1.0 - LdotH, 5.0);
                
                float specIntensity = specShape * fresnelTerm * MainLight.shadowAttenuation * ao; // Mask by AO
                #if _ENABLE_SMOOTHNESS_MASK
                    specIntensity *= smoothnessMask;
                #endif
                float3 finalSpec = _SpecColor.rgb * LightColor * specIntensity;

                // --- 7. Rim Light ---
                float fresnelBase = 1.0 - saturate(dot(normalWS, viewDir));
                float rimIntensity = smoothstep(1.0 - _RimWidth, 1.0 - _RimWidth + _RimSoftness, fresnelBase);
                rimIntensity *= saturate(dot(normalWS, specLightDir) + _RimLightAlign); // Align Mask
                float3 rimResult = rimIntensity * _RimColor.rgb * _RimColor.a;

                // --- 8. Environment & Combine ---
                float3 finalLight = LightColor;
                #if _ENABLEENVIROMENTLIGHT
                    float3 ambient = SampleSH(normalWS) * ao;
                    float3 shadowLight = lerp(ambient, LightColor, _ShadowEnvMix);
                    finalLight = lerp(shadowLight, LightColor, rampCoord);
                #endif

                float3 diffuseResult = albedo.rgb * rampColor.rgb * finalLight * _LightInfluence;
                
                // Energy Conservation Mix
                float3 finalColor = diffuseResult * (1.0 - specIntensity * _SpecColor.a) + finalSpec + rimResult;

                // --- 9. Emission ---
                #if _USE_EMISSION
                    finalColor += SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv).rgb * _EmissionColor.rgb * _EmissionStrength;
                #endif

                return float4(finalColor, albedo.a);
            }
        ENDHLSL

        // ==========================================================
        // Pass 1: Back Faces (Render Inside First)
        // ==========================================================
        Pass {
            Name "NPR BackFace"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite [_ZWrite]
            ZTest LEqual
            Cull Front  // Render Back Faces

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma shader_feature _ENABLEENVIROMENTLIGHT
            #pragma shader_feature _ENABLENORMALMAP
            #pragma shader_feature _ENABLEAO
            #pragma shader_feature _ENABLE_SMOOTHNESS_MASK
            #pragma shader_feature _USE_EMISSION
            #pragma shader_feature_local _RECEIVE_SHADOWS
            ENDHLSL
        }

        // ==========================================================
        // Pass 2: Front Faces (Render Outside Second)
        // ==========================================================
        Pass {
            Name "NPR FrontFace"
            Tags { "LightMode" = "UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite [_ZWrite]
            ZTest LEqual
            Cull Back   // Render Front Faces

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma shader_feature _ENABLEENVIROMENTLIGHT
            #pragma shader_feature _ENABLENORMALMAP
            #pragma shader_feature _ENABLEAO
            #pragma shader_feature _ENABLE_SMOOTHNESS_MASK
            #pragma shader_feature _USE_EMISSION
            #pragma shader_feature_local _RECEIVE_SHADOWS
            ENDHLSL
        }

        // ==========================================================
        // Pass 3: Shadow Caster (Important for Hair Shadows)
        // ==========================================================
        Pass {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull [_Cull] // Optional: Can match Geometry or force Double Sided (0)

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
}
