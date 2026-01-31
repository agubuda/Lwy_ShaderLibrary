Shader "LwyShaders/NPR/NPR_Base" {
    Properties {
        [MainTexture] _BaseMap ("Albedo", 2D) = "white" { }
        [MainColor] _BaseColor ("Base Color", Color) =  (1,1,1,1)
        
        // Cull Mode
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull Mode (0=Double, 2=Single)", Float) = 2

        // Outline Switch
        [Enum(Off, 0, On, 1)] _EnableOutline ("Enable Outline", Float) = 1.0

        [Toggle(_ENABLENORMALMAP)] _ENABLENORMALMAP (" Enable normal map", float) = 0
        [Normal] _BumpMap ("Normal map", 2D) = "bump" { }

        [Space(20)][Header(Ramp lights)]
        _RampMap ("Ramp Map", 2D) = "White" { }
        _RampColum ("Ramp colum", Range(0,1)) = 0.8

        // Specular
        [Space(20)][Header(Spec Settings)]
        [HDR]_SpecColor("_SpecColor (Set White for Non-Metal)", color) = (1.0, 1.0, 1.0, 1.0)
        _SpecWidth ("Specular Width", Range(0, 1)) = 0.05       
        _SpecSoftness ("Specular Softness", Range(0.001, 1)) = 0.01 
        _SpecLightAlign ("Spec Light -> View Shift (XZ Only)", Range(0, 1)) = 0.0

        [Space(20)][Header(Outline settings)]
        _OutLineWidth ("Outline width", float) = 1.5
        _OutLineColor ("Outline color", color) = (0.3, 0.3, 0.3, 1)

        // Rim Light
        [Space(20)][Header(Rim light settings)]
        _RimColor ("RimColor", color) = (0.8, 0.9, 0.9, 1)
        _OffsetMul ("Depth Offset (Sample Distance)", Range(0, 0.05)) = 0.0055
        _RimWidth ("Rim Width (Fresnel)", Range(0, 1)) = 0.5         
        _RimSoftness ("Rim Softness", Range(0.001, 1)) = 0.01 
        _RimLightAlign ("Light Align Mask", Range(-1, 1)) = 0.0 

        [Space(20)][Header(Mask Map Settings)]
        _MaskMap ("Mask Map (G=AO, A=Smoothness)", 2D) = "white" { }
        [Toggle(_ENABLEAO)] _ENABLEAO ("Enable AO (Green Ch)", float) = 1
        [Toggle(_ENABLE_SMOOTHNESS_MASK)] _ENABLE_SMOOTHNESS_MASK ("Enable Smoothness Mask (Alpha Ch)", float) = 1

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
        Tags { "Queue" = "Geometry" "RenderType" = "Opaque" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }

        // 1. DepthOnly Pass
        Pass {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask 0
            Cull [_Cull] 
            
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        // 2. Main Lighting Pass
        Pass {
            Name "NPR skin"
            Tags { "LightMode" = "UniversalForward" }
            ZWrite On
            ZTest On
            Cull [_Cull]

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "NPRFunctions.hlsl"

            #pragma vertex vert
            #pragma fragment frag
            
            // ... (Keywords remain unchanged) ...
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma shader_feature _ENABLEENVIROMENTLIGHT
            #pragma shader_feature _ENABLENORMALMAP
            #pragma shader_feature _ENABLEAO
            #pragma shader_feature _ENABLE_SMOOTHNESS_MASK
            #pragma shader_feature _USE_EMISSION

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float _OutLineWidth;
            float _RampColum;
            float4 _RimColor, _BaseColor; 
            float _OffsetMul;     
            float _RimWidth;      
            float _RimSoftness;   
            float _RimLightAlign; 
            float _LightInfluence;
            float _ShadowEnvMix;
            float4 _BumpMap_ST;
            float _SpecWidth;
            float _SpecSoftness;
            float4 _SpecColor;
            float _SpecLightAlign;
            float4 _EmissionColor;
            float _EmissionStrength;
            float _Cull;
            float _EnableOutline;
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
                
                // 1. 光照与方向准备
                Light MainLight = GetMainLight(input.shadowCoord);
                float3 LightDir = normalize(float3(MainLight.direction));
                float3 LightColor = MainLight.color;

                // 2. 法线贴图处理
                #if _ENABLENORMALMAP
                    float sgn = input.tangentWS.w;
                    half4 normalMap = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv.xy);
                    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                    half3 bump = UnpackNormal(normalMap);
                    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
                    input.normalWS = TransformTangentToWorld(bump, tangentToWorld);
                #endif

                float3 normalWS = NormalizeNormalPerPixel(input.normalWS);

                // 3. 背面修正
                if (!isFrontFace) {
                    normalWS = -normalWS;
                    MainLight.shadowAttenuation = 1.0; 
                }

                // 4. 遮罩采样 (AO & Smoothness)
                float ao, smoothnessMask;
                float enableAO = 0;
                float enableSmoothness = 0;
                #if defined(_ENABLEAO)
                    enableAO = 1;
                #endif
                #if defined(_ENABLE_SMOOTHNESS_MASK)
                    enableSmoothness = 1;
                #endif
                
                GetMaskData(_MaskMap, sampler_MaskMap, input.uv, enableAO, enableSmoothness, 1.0, ao, smoothnessMask);


                // 5. PBR 高光计算
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
                float3 specLightDir = CalculateReshapedLightDir(LightDir, viewDir, _SpecLightAlign);
                
                float cleanShadowAtten = smoothstep(0.0, 0.25, MainLight.shadowAttenuation);
                
                float specRaw = CalculateNPRSpecularIntensity(normalWS, viewDir, specLightDir, _SpecWidth, _SpecSoftness);
                float specIntensity = specRaw * cleanShadowAtten * ao * smoothnessMask;

                float3 pbrSpecularColor = LightColor * _SpecColor.rgb * specIntensity;

                // 6. NPR 漫反射计算
                float4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
                float3 pbrDiffuseColor = CalculateNPRDiffuse(albedo.rgb, LightColor, LightDir, normalWS, 
                                                             cleanShadowAtten, ao, 
                                                             _RampMap, sampler_RampMap, _RampColum);

                // 7. 高光遮罩漫反射
                float3 lightingResult = pbrDiffuseColor * (1.0 - specIntensity) + pbrSpecularColor;

                // 8. 环境光与阴影混合
                #if _ENABLEENVIROMENTLIGHT
                    float3 ambient = SampleSH(normalWS);
                    float3 envDiffuse = ambient * albedo.rgb * ao;

                    float3 litLight = lightingResult; 
                    float3 shadowLight = lerp(envDiffuse, litLight, _ShadowEnvMix);
                    
                    float NdotL = dot(LightDir, normalWS);
                    float halfLambert = NdotL * 0.5 + 0.5;
                    float rampCoord = saturate(halfLambert * cleanShadowAtten * ao);
                    
                    lightingResult = lerp(shadowLight, litLight, rampCoord);
                    lightingResult *= _LightInfluence;
                #endif

                // 9. 边缘光计算 (含深度修正)
                float3 normalVS = TransformWorldToViewDir(normalWS, true); 
                float depth = input.positionNDC.z / input.positionNDC.w;
                float2 RimScreenUV = float2(input.positionCS.x / _ScreenParams.x, input.positionCS.y / _ScreenParams.y);
                float2 RimOffsetUV = RimScreenUV + normalVS.xy * _OffsetMul;

                float linearEyeDepth = LinearEyeDepth(depth, _ZBufferParams);
                float offsetDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, RimOffsetUV).r;
                float linearEyeOffsetDepth = LinearEyeDepth(offsetDepth, _ZBufferParams);
                
                float depthDiff = linearEyeOffsetDepth - linearEyeDepth; 
                float depthMask = step(0.0001, depthDiff);

                float rimIntensity = CalculateNPRRimIntensity(normalWS, viewDir, specLightDir, _RimWidth, _RimSoftness, _RimLightAlign);
                lightingResult += _RimColor.rgb * (rimIntensity * depthMask) * _RimColor.a;

                // 10. 自发光叠加
                #if _USE_EMISSION
                    float4 emissionMap = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv);
                    lightingResult += emissionMap.rgb * _EmissionColor.rgb * _EmissionStrength;
                #endif

                return float4(lightingResult, 1.0);
            }
            ENDHLSL
        }
        
        // 3. Outline Pass
        Pass {
            Name "Outline"
            Tags { "Queue" = "Geometry" "IgnoreProjector" = "True" "LightMode" = "SRPDefaultUnlit" }
            Cull Front
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "OutlineUtil.hlsl"
            #pragma vertex vert
            #pragma fragment frag
            CBUFFER_START(UnityPerMaterial)
            float _OutLineWidth;
            float4 _OutLineColor;
            float _EnableOutline;
            CBUFFER_END
            struct a2v {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float3 vertColor : COLOR;
            };
            struct v2f {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 vertColor : COLOR;
            };
            v2f vert(a2v input) {
                v2f o = (v2f)0;
                // Outline Toggle
                if (_EnableOutline < 0.5) {
                    o.positionCS = float4(0, 0, 0, 0);
                    return o;
                }
                float4 positionOS = input.positionOS;
                half3 normalOS=normalize(input.normalOS);
                o.positionWS = TransformObjectToWorld(positionOS);
                float3 positionVS = TransformWorldToView(o.positionWS);
                float3 normalWS = TransformObjectToWorldNormal(normalOS);
                o.positionWS = TransformPositionWSToOutlinePositionWS(o.positionWS,positionVS.z,normalWS,_OutLineWidth,input.vertColor.r);
                o.positionCS = TransformWorldToHClip(o.positionWS);
                return o;
            }
            half4 frag(v2f input) : SV_TARGET {
                return _OutLineColor;
            }
            ENDHLSL
        }

        // 4. ShadowCaster
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
}