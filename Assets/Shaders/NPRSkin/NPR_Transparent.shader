Shader "LwyShaders/NPR/NPR_Transparent" {
    Properties {
        [Header(Base Settings)]
        [MainTexture] _BaseMap ("Albedo", 2D) = "white" { }
        [MainColor] _BaseColor ("Base Color (Alpha controls Opacity)", Color) =  (1,1,1,1)
        
        // --- [新增] 剔除模式控制 (0=Off双面, 2=Back单面) ---
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull Mode (0=Double, 2=Single)", Float) = 0
        
        // ZWrite 控制
        [Enum(Off, 0, On, 1)] _ZWrite("Z Write", Float) = 1.0

        [Toggle(_ENABLENORMALMAP)] _ENABLENORMALMAP (" Enable normal map", float) = 0
        [Normal] _BumpMap ("Normal map", 2D) = "bump" { }

        [Space(20)][Header(Ramp lights)]
        _RampMap ("Ramp Map", 2D) = "White" { }
        _RampColum ("Ramp colum", Range(0,1)) = 0.8

        // --- Specular Settings ---
        [Space(20)][Header(Spec Settings)]
        [HDR]_SpecColor("_SpecColor", color) = (1.0, 1.0, 1.0, 1.0)
        _SpecWidth ("Specular Width", Range(0, 1)) = 0.05       
        _SpecSoftness ("Specular Softness", Range(0.001, 1)) = 0.01 
        
        // 高光光源偏移 (仅 XZ 轴)
        _SpecLightAlign ("Spec Light -> View Shift (XZ Only)", Range(0, 1)) = 0.0

        // --- Rim Light Settings ---
        [Space(20)][Header(Rim light settings)]
        _RimColor ("RimColor", color) = (0.8, 0.9, 0.9, 1)
        _RimWidth ("Rim Width", Range(0, 1)) = 0.1         
        _RimSoftness ("Rim Softness", Range(0.001, 1)) = 0.01 
        _RimLightAlign ("Light Align Mask", Range(-1, 1)) = 0.0 

        [Space(20)][Header(Mask Map Settings)]
        _MaskMap ("Mask Map (A=Smoothness)", 2D) = "white" { }
        [Toggle(_ENABLE_SMOOTHNESS_MASK)] _ENABLE_SMOOTHNESS_MASK ("Enable Smoothness Mask (Alpha Ch)", float) = 1

        // --- Emission Settings ---
        [Space(20)][Header(Emission Settings)]
        [Toggle(_USE_EMISSION)] _UseEmission ("Enable Emission", Float) = 0
        _EmissionMap ("Emission Map", 2D) = "white" {}
        [HDR] _EmissionColor ("Emission Color", Color) = (1,1,1,1)
        _EmissionStrength ("Emission Strength", Range(0, 10)) = 1

        [Space(20)][Header(Env and dir light)]
        [Toggle(_ENABLEENVIROMENTLIGHT)] _ENABLEENVIROMENTLIGHT ("Enable enviroment light", Float) = 0.0
        _LightInfluence ("Light influence", Range(0.1, 1.5)) = 1
        _ShadowEnvMix ("Shadow Light Mix", Range(0, 1)) = 0.2
    }

    SubShader {
        Tags { 
            "Queue" = "Transparent" 
            "RenderType" = "Transparent" 
            "IgnoreProjector" = "True" 
            "RenderPipeline" = "UniversalPipeline" 
        }

        Pass {
            Name "NPR Transparent SpecAlign XZ"
            Tags { "LightMode" = "UniversalForward" } 
            
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite [_ZWrite]
            ZTest LEqual
            // [修改] 使用变量控制剔除
            Cull [_Cull]

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            
            #pragma shader_feature _ENABLEENVIROMENTLIGHT
            #pragma shader_feature _ENABLENORMALMAP
            #pragma shader_feature _ENABLE_SMOOTHNESS_MASK
            #pragma shader_feature _USE_EMISSION

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float _RampColum;
            float4 _RimColor, _BaseColor; 
            
            // Rim Params
            float _RimWidth;
            float _RimSoftness;
            float _RimLightAlign;

            float _LightInfluence;
            float _ShadowEnvMix;
            
            float4 _BumpMap_ST;
            
            // Spec Params
            float _SpecWidth;
            float _SpecSoftness;
            float4 _SpecColor;
            
            float _SpecLightAlign;

            float4 _EmissionColor;
            float _EmissionStrength;
            
            float _ZWrite;
            // [新增]
            float _Cull;
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
                float4 positionNDC : TEXCOORD4;
                float4 scrPos : TEXCOORD5;
                float4 shadowCoord : TEXCOORD6;
                float4 tangentWS : TEXCOORD7;
                float3 bitangentWS : TEXCOORD8;
            };

            v2f vert(a2v input) {
                v2f o;
                o.positionCS = TransformObjectToHClip(input.positionOS);
                o.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(input.normalOS.xyz, true);
                o.tangentWS = float4(TransformObjectToWorldDir(input.tangentOS.xyz, true), input.tangentOS.w);
                o.bitangentWS = normalize(cross(o.normalWS, o.tangentWS.xyz) * input.tangentOS.w);

                float4 ndc = input.positionOS * 0.5f;
                o.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
                o.positionNDC.zw = TransformObjectToHClip(input.positionOS).zw;

                o.scrPos = ComputeScreenPos(o.positionCS);
                o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
                o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

                return o;
            }

            float4 frag(v2f input, bool isFrontFace : SV_IsFrontFace) : SV_TARGET {

                float3 positionVS = TransformWorldToView(input.positionWS);
                
                // 1. 获取真实光源信息
                Light MainLight = GetMainLight(input.shadowCoord);
                float3 LightDir = normalize(float3(MainLight.direction));
                float4 LightColor = float4(MainLight.color, 1);

                // 2. 准备向量
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
                
                // --- 计算 "高光用" 光源方向 (仅XZ轴跟随) ---
                float3 lightDirXZ = normalize(float3(LightDir.x, 0, LightDir.z) + 1e-5);
                float3 viewDirXZ  = normalize(float3(viewDir.x,  0, viewDir.z)  + 1e-5);
                float3 blendedXZ = lerp(lightDirXZ, viewDirXZ, _SpecLightAlign);
                float3 specLightDir = normalize(float3(blendedXZ.x, LightDir.y, blendedXZ.z));

                #if _ENABLENORMALMAP
                    float sgn = input.tangentWS.w;
                    half4 normalMap = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv.xy);
                    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                    half3 bump = UnpackNormal(normalMap);
                    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
                    input.normalWS = TransformTangentToWorld(bump, tangentToWorld);
                #endif

                float3 normalWS = NormalizeNormalPerPixel(input.normalWS);

                // =========================================================
                // [修复] 双面渲染核心逻辑
                // =========================================================
                if (!isFrontFace) {
                    // 1. 翻转背面法线，确保光照计算正确（否则背面是黑的）
                    normalWS = -normalWS;
                    
                    // 2. [关键修复] 透明物体背面通常会被正面投射阴影（自阴影）。
                    // 这会导致内壁看起来很脏/黑。
                    // 强制取消背面的阴影接收，让内壁显得通透。
                    MainLight.shadowAttenuation = 1.0;
                }
                // =========================================================

                float smoothnessMask = 1.0;
                #if defined(_ENABLE_SMOOTHNESS_MASK)
                    smoothnessMask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv).a;
                #endif

                // --- Base Diffuse (Lambert & Ramp) ---
                float Lambert = dot(LightDir, normalWS) * MainLight.shadowAttenuation;
                float halfLambert = (Lambert * 0.5 + 0.5);

                float4 rampLambertColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(halfLambert, _RampColum));
                float4 difusse = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                difusse *= _BaseColor;

                // ---------------------------------------------------------------------------------
                // [Specular]
                // ---------------------------------------------------------------------------------
                float3 HalfWay = normalize(viewDir + specLightDir);
                
                float NdotH = saturate(dot(normalWS, HalfWay));
                float specThreshold = 1.0 - _SpecWidth; 
                float specShape = smoothstep(specThreshold, specThreshold + _SpecSoftness, NdotH);

                float F0 = 0.04; 
                float LdotH = saturate(dot(specLightDir, HalfWay));
                float fresnelTerm = F0 + (1.0 - F0) * pow(1.0 - LdotH, 5.0);

                float specIntensity = specShape * fresnelTerm;
                specIntensity *= MainLight.shadowAttenuation;
                #if _ENABLE_SMOOTHNESS_MASK
                    specIntensity *= smoothnessMask;
                #endif
                
                float3 finalSpecColor = _SpecColor.rgb * LightColor.rgb * specIntensity; 

                // ---------------------------------------------------------------------------------
                // [Rim Light]
                // ---------------------------------------------------------------------------------
                float NdotV = saturate(dot(normalWS, viewDir));
                float fresnelBase = 1.0 - NdotV; 

                float rimThreshold = 1.0 - _RimWidth;
                float rimIntensity = smoothstep(rimThreshold, rimThreshold + _RimSoftness, fresnelBase);

                float NdotL_Rim = dot(normalWS, specLightDir);
                float rimLightMask = saturate(NdotL_Rim + _RimLightAlign);
                
                rimIntensity *= rimLightMask;
                
                float4 fresnelDepthRim = rimIntensity * _RimColor;
                float3 rimResult = fresnelDepthRim.rgb * rimIntensity * _RimColor.a;

                // ---------------------------------------------------------------------------------
                // Environment Light
                // ---------------------------------------------------------------------------------
                float3 FinalLightColor = LightColor.rgb;
                #if _ENABLEENVIROMENTLIGHT
                    float3 ambient = SampleSH(normalWS);
                    float3 litLight = LightColor.rgb;
                    float3 shadowLight = lerp(ambient, litLight, _ShadowEnvMix);
                    FinalLightColor = lerp(shadowLight, litLight, saturate(halfLambert));
                #endif

                // ---------------------------------------------------------------------------------
                // Final Combine
                // ---------------------------------------------------------------------------------
                
                float3 diffuseColorApplied;
                #if _ENABLEENVIROMENTLIGHT
                    diffuseColorApplied = difusse.rgb * rampLambertColor.rgb * FinalLightColor * _LightInfluence;
                #else
                    diffuseColorApplied = difusse.rgb * rampLambertColor.rgb * LightColor.rgb * _LightInfluence; 
                #endif

                float3 colorRGB = diffuseColorApplied * (1.0 - specIntensity * _SpecColor.a) + finalSpecColor;

                colorRGB += rimResult;

                #if _USE_EMISSION
                    float4 emissionMap = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv);
                    float3 emissionResult = emissionMap.rgb * _EmissionColor.rgb * _EmissionStrength;
                    colorRGB += emissionResult;
                #endif
                
                float finalAlpha = difusse.a; 
                
                return float4(colorRGB, finalAlpha);
            }

            ENDHLSL
        }
    }
}