Shader "LwyShaders/NPR/NPR_Base" {
    Properties {
        [MainTexture] _BaseMap ("Albedo", 2D) = "white" { }
        [MainColor] _BaseColor ("Base Color", Color) =  (1,1,1,1)
        
        [Toggle(_ENABLENORMALMAP)] _ENABLENORMALMAP (" Enable normal map", float) = 0
        [Normal] _BumpMap ("Normal map", 2D) = "bump" { }

        [Space(20)][Header(Ramp lights)]
        _RampMap ("Ramp Map", 2D) = "White" { }
        _RampColum ("Ramp colum", Range(0,1)) = 0.8

        [Space(20)][Header(Spec)]
        _SpecPower("_SpecPower", Range(8, 15)) = 8.
        _SpecRange("_SpecRange", Range(0, 1)) = 0.1
        _SpacSoftEdge("_SpacSoftEdge", Range(0, 1)) = 0.1
        [HDR]_SpecColor("_SpecColor", color) = (0.0, 0.0, 0.0, 0.0)

        [Space(20)][Header(Outline settings)]
        _OutLineWidth ("Outline width", float) = 1.5
        _OutLineColor ("Outline color", color) = (0.3, 0.3, 0.3, 1)

        [Space(20)][Header(Rim light settings)]
        _OffsetMul ("_RimWidth", Range(0, 0.05)) = 0.0055
        // [已删除] Threshold (未使用)
        _RimColor ("RimColor", color) = (0.8, 0.9, 0.9, 1)
        _FresnelPower ("Fresnel power", Range(1, 10)) = 3

        [Space(20)][Header(Mask Map Settings)]
        // URP Standard: G = Occlusion, A = Smoothness
        _MaskMap ("Mask Map (G=AO, A=Smoothness)", 2D) = "white" { }
        
        [Toggle(_ENABLEAO)] _ENABLEAO ("Enable AO (Green Ch)", float) = 1
        // [已删除] AOPower (逻辑中未使用)
        
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

        Tags { "Queue" = "Geometry" "RenderType" = "Opaque" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }

        // 1. Depth Pass 修改：Cull Off
        Pass {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask 0
            Cull Off 

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

        // 2. Main Pass 修改：Cull Off + 法线翻转逻辑
        Pass {
            Name "NPR skin"
            Tags { "LightMode" = "UniversalForward" }
            ZWrite On
            ZTest On
            Cull Off 

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
            #pragma shader_feature _ENABLEAO
            #pragma shader_feature _ENABLE_SMOOTHNESS_MASK
            #pragma shader_feature _USE_EMISSION

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float _OutLineWidth;
            float _RampColum;
            float _OffsetMul;
            float4 _RimColor, _BaseColor; 
            float _FresnelPower;
            float _LightInfluence;
            float _ShadowEnvMix;
            
            float4 _BumpMap_ST;
            float _SpecPower;
            float _SpecRange;
            float _SpacSoftEdge;
            float4 _SpecColor;

            float4 _EmissionColor;
            float _EmissionStrength;
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

            // 修改：添加 bool isFrontFace : SV_IsFrontFace
            float4 frag(v2f input, bool isFrontFace : SV_IsFrontFace) : SV_TARGET {

                float3 positionVS = TransformWorldToView(input.positionWS);
                
                // 注意：这里先不要 TransformWorldToViewDir 计算 normalVS，因为 normalWS 还没翻转

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

                // 1. 获取归一化后的世界空间法线
                float3 normalWS = NormalizeNormalPerPixel(input.normalWS);

                // 2. 【核心逻辑】判断是否为背面，如果是，翻转法线
                if (!isFrontFace) {
                    normalWS = -normalWS;
                }
                // 注意：之后所有的光照计算都要使用这个局部的 normalWS 变量，而不是 input.normalWS

                float4 MaskMapData = float4(1,1,1,1);
                #if defined(_ENABLEAO) || defined(_ENABLE_SMOOTHNESS_MASK)
                    MaskMapData = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);
                #endif

                //Lambert & ramp
                // 使用 normalWS
                float Lambert = dot(LightDir, normalWS) * MainLight.shadowAttenuation;
                float halfLambert = (Lambert * 0.5 + 0.5);

                #if _ENABLEAO
                    halfLambert *= clamp(MaskMapData.g, 0, 1);
                #endif
                
                float4 rampLambertColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(halfLambert, _RampColum));
                float4 difusse = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                difusse *= _BaseColor;

                //Blinn_phong
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
                float3 HalfWay = normalize(viewDir + LightDir);
                // 使用 normalWS
                half blinnPhong = pow(saturate(max(0, dot(normalWS, HalfWay))), _SpecPower) *  MainLight.shadowAttenuation;

                #if _ENABLEAO
                    blinnPhong *= clamp(MaskMapData.g, 0, 1);
                #endif

                blinnPhong *= blinnPhong;
                half4 blinnPhongNPR = smoothstep(_SpecRange, _SpecRange + _SpacSoftEdge, blinnPhong) * _SpecColor;

                #if _ENABLE_SMOOTHNESS_MASK
                    blinnPhongNPR *= MaskMapData.a;
                #endif

                // Environment Light Logic
                float3 FinalLightColor = LightColor.rgb;
                #if _ENABLEENVIROMENTLIGHT
                    // 使用 normalWS
                    float3 ambient = SampleSH(normalWS);
                    #if _ENABLEAO
                         ambient *= MaskMapData.g;
                    #endif
                    float3 litLight = LightColor.rgb;
                    float3 shadowLight = lerp(ambient, litLight, _ShadowEnvMix);
                    FinalLightColor = lerp(shadowLight, litLight, saturate(halfLambert));
                #endif

                // Fresnel Rim
                // 使用 normalWS
                float fresnelRim = 1 - saturate(dot(normalWS, viewDir));
                float fresnelRimPow = saturate(pow(max(0.001,fresnelRim),_FresnelPower));
                float4 fresnelDepthRim = fresnelRimPow * _RimColor;

                // Combine
                float4 color = lerp(difusse * rampLambertColor, fresnelDepthRim, fresnelRimPow*_RimColor.a);
                color.rgba = max(color.rgba, blinnPhongNPR.rgba * _SpecColor.a);

                // Apply Light Color
                #if _ENABLEENVIROMENTLIGHT
                    color.rgb *= FinalLightColor * _LightInfluence;
                #else
                    color.rgb *= LightColor.rgb * _LightInfluence; 
                #endif

                // Emission
                #if _USE_EMISSION
                    float4 emissionMap = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv);
                    float3 emissionResult = emissionMap.rgb * _EmissionColor.rgb * _EmissionStrength;
                    color.rgb += emissionResult;
                #endif

                return color;
            }

            ENDHLSL
        }

        // Outline Pass 保持不变 (如果物体是封闭的，背面一般不需要描边，或者Cull Front会正常工作)
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
                v2f o;
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

        // 3. ShadowCaster 修改：Cull Off
        Pass {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off // 强制关闭剔除，让背面也能投射阴影
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
