Shader "LwyShaders/NPR/NPR_Base" {
    Properties {
        [MainTexture] _BaseMap ("Albedo", 2D) = "white" { }
        [MainColor] _BaseColor ("Base Color", Color) =  (1,1,1,1)
        
        // 剔除模式控制 (0=Off双面, 2=Back单面)
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull Mode (0=Double, 2=Single)", Float) = 2

        // --- 描边开关 ---
        [Enum(Off, 0, On, 1)] _EnableOutline ("Enable Outline", Float) = 1.0

        [Toggle(_ENABLENORMALMAP)] _ENABLENORMALMAP (" Enable normal map", float) = 0
        [Normal] _BumpMap ("Normal map", 2D) = "bump" { }

        [Space(20)][Header(Ramp lights)]
        _RampMap ("Ramp Map", 2D) = "White" { }
        _RampColum ("Ramp colum", Range(0,1)) = 0.8

        // --- Specular (Width/Softness) ---
        [Space(20)][Header(Spec Settings)]
        [HDR]_SpecColor("_SpecColor", color) = (1.0, 1.0, 1.0, 1.0)
        _SpecWidth ("Specular Width", Range(0, 1)) = 0.05       
        _SpecSoftness ("Specular Softness", Range(0.001, 1)) = 0.01 

        [Space(20)][Header(Outline settings)]
        _OutLineWidth ("Outline width", float) = 1.5
        _OutLineColor ("Outline color", color) = (0.3, 0.3, 0.3, 1)

        // --- Rim Light (深度检测 + 硬边控制) ---
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

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float _OutLineWidth;
            float _RampColum;
            float4 _RimColor, _BaseColor; 
            
            // Rim Params
            float _OffsetMul;     
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
                
                Light MainLight = GetMainLight(input.shadowCoord);
                float3 LightDir = normalize(float3(MainLight.direction));
                float4 LightColor = float4(MainLight.color, 1);

                #if _ENABLENORMALMAP
                    float sgn = input.tangentWS.w;
                    half4 normalMap = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv.xy);
                    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                    half3 bump = UnpackNormal(normalMap);
                    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
                    input.normalWS = TransformTangentToWorld(bump, tangentToWorld);
                #endif

                float3 normalWS = NormalizeNormalPerPixel(input.normalWS);

                if (!isFrontFace) {
                    normalWS = -normalWS;
                    MainLight.shadowAttenuation = 1.0; 
                }

                float4 MaskMapData = float4(1,1,1,1);
                #if defined(_ENABLEAO) || defined(_ENABLE_SMOOTHNESS_MASK)
                    MaskMapData = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);
                #endif

                // -----------------------------------------------------------------------
                // [修改] 阴影与 Lambert 叠加计算
                // -----------------------------------------------------------------------
                
                // 1. 计算纯几何 Lambert (0.0 ~ 1.0)
                float NdotL = dot(LightDir, normalWS);
                float halfLambert = NdotL * 0.5 + 0.5;

                // 2. 处理阴影衰减 (去斑驳)
                // URP的shadowAttenuation在边缘处可能会有噪点(Shadow Acne)。
                // 使用 smoothstep 对阴影值进行"锐化"或"平滑"，过滤掉低精度的中间值。
                // 这里的 (0.0, 0.25) 可以调节，值越小阴影边缘越硬，但越能去除斑驳。
                float cleanShadowAtten = smoothstep(0.0, 0.25, MainLight.shadowAttenuation);

                // 3. 叠加计算
                // 将几何明暗与处理后的阴影相乘。
                // 结果：如果被阴影覆盖(cleanShadowAtten=0)，RampCoord直接变为0 (采样Ramp最左侧深色)。
                // 结果：如果没有阴影，则由 halfLambert 决定采样位置。
                float rampCoord = saturate(halfLambert * cleanShadowAtten);

                // 4. 应用 AO (如果开启)
                #if _ENABLEAO
                    rampCoord *= clamp(MaskMapData.g, 0, 1);
                #endif
                
                // 5. 采样 Ramp
                float4 rampLambertColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(rampCoord, _RampColum));
                
                float4 difusse = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                difusse *= _BaseColor;
                // -----------------------------------------------------------------------

                // Specular
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
                float3 HalfWay = normalize(viewDir + LightDir);
                
                float NdotH = saturate(dot(normalWS, HalfWay));
                float specThreshold = 1.0 - _SpecWidth; 
                float specShape = smoothstep(specThreshold, specThreshold + _SpecSoftness, NdotH);

                float F0 = 0.04; 
                float LdotH = saturate(dot(LightDir, HalfWay));
                float fresnelTerm = F0 + (1.0 - F0) * pow(1.0 - LdotH, 5.0);

                float specIntensity = specShape * fresnelTerm;
                // 高光也应用处理过的干净阴影
                specIntensity *= cleanShadowAtten;

                #if _ENABLEAO
                    specIntensity *= clamp(MaskMapData.g, 0, 1);
                #endif
                
                #if _ENABLE_SMOOTHNESS_MASK
                    specIntensity *= MaskMapData.a;
                #endif
                
                float3 finalSpecColor = _SpecColor.rgb * LightColor.rgb * specIntensity; 
                
                // Env Light
                float3 FinalLightColor = LightColor.rgb;
                #if _ENABLEENVIROMENTLIGHT
                    float3 ambient = SampleSH(normalWS);
                    #if _ENABLEAO
                         ambient *= MaskMapData.g;
                    #endif
                    float3 litLight = LightColor.rgb;
                    float3 shadowLight = lerp(ambient, litLight, _ShadowEnvMix);
                    // 环境光混合也使用新的 rampCoord
                    FinalLightColor = lerp(shadowLight, litLight, rampCoord);
                #endif

                // Rim Light
                float3 normalVS = TransformWorldToViewDir(normalWS, true); 
                float depth = input.positionNDC.z / input.positionNDC.w;
                float2 RimScreenUV = float2(input.positionCS.x / _ScreenParams.x, input.positionCS.y / _ScreenParams.y);
                float2 RimOffsetUV = RimScreenUV + normalVS.xy * _OffsetMul;

                float linearEyeDepth = LinearEyeDepth(depth, _ZBufferParams);
                float offsetDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, RimOffsetUV).r;
                float linearEyeOffsetDepth = LinearEyeDepth(offsetDepth, _ZBufferParams);
                
                float depthDiff = linearEyeOffsetDepth - linearEyeDepth; 
                float depthMask = step(0.0001, depthDiff);

                float fresnelBase = 1.0 - saturate(dot(normalWS, viewDir));
                float rimThreshold = 1.0 - _RimWidth;
                float rimGradient = smoothstep(rimThreshold, rimThreshold + _RimSoftness, fresnelBase);

                float rimIntensity = depthMask * rimGradient;

                float NdotL_Rim = dot(normalWS, LightDir);
                float rimLightMask = saturate(NdotL_Rim + _RimLightAlign);
                
                rimIntensity *= rimLightMask;
                
                float4 fresnelDepthRim = rimIntensity * _RimColor;
                float3 rimResult = fresnelDepthRim.rgb * rimIntensity * _RimColor.a;

                // Combine
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

                return float4(colorRGB, 1.0);
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