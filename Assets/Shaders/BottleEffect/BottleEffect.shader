Shader "LwyShaders/BottleEffect_01"
{
    Properties
    {
        // [Space(20)][Header(emissive map)]
        // _EmissiveMap ("_EmissiveMap", 2D) = "white" { }
        // [HDR]_EmissiveColor ("_EmissiveColor", color) = (1,0,0,1)

        [Space(20)][Header(base settings)]
        _BaseMap ("Texture", 2D) = "white" { }
        _InsideColor ("_InsideColor", color) = (0, 0, 0, 1)
        _OutsideColor ("_OutsideColor", color) = (0, 0, 0, 1)


        // [Toggle(_ENABLENORMALMAP)] _ENABLENORMALMAP (" Enable normal map", float) = 0
        _NormalMap ("Normal map", 2D) = "bump" { }
        _NormalScale ("Normal scale", float) = 1

        [Space(20)][Header(Rim light settings)]
        _OffsetMul ("_RimWidth", Range(0, 0.1)) = 0.0055
        _Threshold ("_Threshold", Range(0, 1)) = 0.02
        [HDR]_RimColor ("RimColor", color) = (0.8, 0.7, 0.7, 1)
        _FresnelPower ("Fresnel power", Range(0, 10)) = 3
        _FresnelStepValue ("_FresnelStepValue", Range(0, 1)) = 0.1
        _FresnelStepValue2 ("_FresnelStepValue2", Range(0, 1)) = 0.2
        
        [Space(20)][Header(AO map)]
        _MaskMap ("Mask Map", 2D) = "white" { }//as urp default settings, g = AO, a = Metalic
        _AOPower ("AO power", Range(0, 6)) = 1

        // _Cull ("__cull", Float) = 2.0
        _Min ("min", Range(0, 1)) = 1.0
        _liquidEdge ("_liquidEdge", Range(0, 1)) = 0
        _Cutoff ("_Cutoff", Range(0, 1)) = 0.3
        _WobbleX ("_WobbleX", Range(-1, 1)) = 0.3
        _WobbleZ ("_WobbleZ", Range(-1, 1)) = 0.3
        // [Space(20)][Header(Specular)]
        _SpecPower ("Specular Power", float) = 10
        // _SpecColor ("Specular Color", color) = (0.4, 0.3, 0.3, 1)
        // _SpecRange ("Specular Range", Range(0, 1)) = 0.075
        // _SpacSmoothness ("Specular Edge Smoothness", Range(0, 1)) = 0.58
        // // _SpecStrength ("Specular Range", float) = 0.86
        // _SpecAOPower ("Specular AO power", float) = 0.5
        // _SpecMaskPower ("Specular Mask power", Range(0, 10)) = 1

    }

    SubShader
    {
        // Tags { "Queue" = "AlphaClip" "RenderType" = "Opaque" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }
        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }

        // Pass
        // {
        //     Name "DepthOnly"
        //     Tags { "LightMode" = "DepthOnly" "Queue" = "Geometry" }

        //     // ZWrite On
        //     // ColorMask 0

        //     HLSLPROGRAM
        //     #pragma exclude_renderers gles gles3 glcore
        //     #pragma target 4.5

        //     #pragma vertex DepthOnlyVertex
        //     #pragma fragment DepthOnlyFragment

        //     #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"


        //     CBUFFER_START(UnityPerMaterial)
        //         half _Surface;

        //         half4 _BaseColor;
        //         half4 _AnisotropyColor;
        //         half _Darkness;
        //         half _Glossness;
        //         half _Cutoff;
        //         half4 _SpecColor;
        //         half _SpecPower;
        
        //         half4 _BaseMap_ST;
        //         half4 _NormalMap_ST;
        //         half4 _NoiseMap_ST;
        //         half4 _AOMap_ST;
        
        //         half _NormalScale;
        //         half _NoisePower;
        //         half _AnisotropyPower;
        //         half _FrenelPower;
        //         half4 _RimColor;
        //         half _Exponent;
        //         half _FrenelLightness;
        //         half _AOContrast;

        //         float4 _DetailAlbedoMap_ST;
        //         half4 _EmissionColor;
        //         half _Smoothness;
        //         half _Metallic;
        //         half _BumpScale;
        //         half _Parallax;
        //         half _OcclusionStrength;
        //         half _ClearCoatMask;
        //         half _ClearCoatSmoothness;
        //         half _DetailAlbedoMapScale;
        //         half _DetailNormalMapScale;
        //     CBUFFER_END

        //     // -------------------------------------
        //     // Material Keywords
        //     // #pragma shader_feature_local_fragment _ALPHATEST_ON

        //     //--------------------------------------
        //     // GPU Instancing
        //     // #pragma multi_compile_instancing
        //     // #pragma multi_compile _ DOTS_INSTANCING_ON

        //     // #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
        //     #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
        //     ENDHLSL
        // }

        pass
        {
            Name "BottleEffect"
            Tags { "LightMode" = "UniversalForward" }
            // ZWrite On
            Cull back
            ZTest on
            Blend SrcAlpha OneMinusSrcAlpha
            AlphaToMask On
            // ZWrite On



            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #pragma target 4.5

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fog

            #pragma multi_compile  _MAIN_LIGHT_SHADOWS
            #pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile  _SHADOWS_SOFT
            #pragma shader_feature _ENABLENORMALMAP

            CBUFFER_START(UnityPerMaterial)

                float4 _BaseMap_ST;
                float4 _MainTex_ST;
                // float4 _EmissiveMap_ST;
                // half _SpecPower;
                // float4 _SpecColor;
                // float4 _EmissiveColor;
                float _NormalScale, _FresnelStepValue2;
                float _OutLineWidth;
                float4 _RimColor;
                float _FresnelPower;
                float _AOPower;
                // float _SpacSmoothness;
                // float _SpecAOPower;
                // float _SpecMaskPower;
                float _LightInfluence;
                float _FresnelStepValue;
                half4 _InsideColor, _OutsideColor;
                float4 _NormalMap_ST;
                float _OffsetMul, _Threshold, _Min, _liquidEdge, _Cutoff;

                half _SpecPower;

                float _WobbleX, _WobbleZ;

            CBUFFER_END

            // TEXTURE2D(_EmissiveMap); SAMPLER(sampler_EmissiveMap);
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MaskMap); SAMPLER(sampler_MaskMap);
            TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);

            TEXTURE2D_X_FLOAT(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
            
            struct a2v
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 texcoord : TEXCOORD0;
                float4 color : COLOR;
                // UNITY_VERTEX_INPUT_INSTANCE_ID


            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float4 positionOS : TEXCOORD8;
                float3 positionWS : TEXCOORD0;
                // float3 positionVS : TEXCOORD4;
                float2 uv : TEXCOORD1;
                // float fogCoord : TEXCOORD2;
                float3 normalWS : TEXCOORD3;
                // float3 normalVS : TEXCOORD5;
                float4 positionNDC : TEXCOORD5;
                float4 positionSS : TEXCOORD2;
                float2 screenPos : TEXCOORD6;

                float3 tangentWS : TEXCOORD4;
                float3 bitangentWS : TEXCOORD7;
                float3 axis :TEXCOORD9;

                
                // UNITY_VERTEX_OUTPUT_STEREO

            };


            v2f vert(a2v input)
            {
                v2f o;
                // UNITY_SETUP_INSTANCE_ID(input);
                // UNITY_TRANSFER_INSTANCE_ID(input, output);
                // UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                o.positionCS = TransformObjectToHClip(input.positionOS);
                o.positionWS = TransformObjectToWorld(input.positionOS.xyz);

                
                o.normalWS = TransformObjectToWorldNormal(input.normalOS.xyz, true);
                o.tangentWS = TransformObjectToWorldDir(input.tangentOS);
                o.positionOS = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));

                o.axis = o.positionWS -o.positionOS;
                // o.positionVS = TransformWorldToView(TransformObjectToWorld(input.positionOS.xyz));
                // normalVS = TransformWorldToViewDir(normalWS, true);

                // o.bitangentWS = normalize(cross(o.normalWS,o.tangentWS) * input.tangentOS.w);

                //scr pos
                o.positionSS = ComputeScreenPos(vertexInput.positionCS);
                o.screenPos = o.positionSS.xy / o.positionSS.w;

                // //recive shadow
                // o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
                
                o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                // o.vertexColor = input.color;
                

                return o;
            }

            half4 frag(v2f input, bool vf : SV_ISFRONTFACE) : SV_TARGET
            {
                // UNITY_SETUP_INSTANCE_ID(input);
                // UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float3 positionVS = TransformWorldToView(input.positionWS);
                float3 normalVS = TransformWorldToViewDir(normalize(input.normalWS), true);

                //initialize main light
                Light MainLight = GetMainLight();
                half3 LightDir = normalize(half3(MainLight.direction));
                half3 LightColor = MainLight.color.rgb;


                //Normal map

                float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv);
                float3 bump = UnpackNormalScale(normalMap, _NormalScale);
                input.normalWS = TransformTangentToWorld(bump, float3x3(input.bitangentWS, input.tangentWS, input.normalWS));
                

                // //EmissiveMap
                // float4 EmissiveMap = SAMPLE_TEXTURE2D(_EmissiveMap, sampler_EmissiveMap, input.uv);
                // EmissiveMap *= _EmissiveColor;

                // //Mask map
                // float4 MaskMap = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);

                // //Blinn_phong
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
                float3 HalfWay = normalize(viewDir + LightDir);
                half blinnPhong = (pow(saturate(max(0,dot(input.normalWS, HalfWay))), _SpecPower));


                //Lambert & ramp

                float Lambert = dot(LightDir, input.normalWS)  ;
                float halfLambert = (Lambert * 0.5 + 0.5); // * pow(abs(MaskMap.g), _AOPower)  ;
                
                float4 difusse = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);

                float Depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, input.screenPos);

                input.axis.y += input.axis.x * _WobbleX;
                input.axis.y += input.axis.z * _WobbleZ;

                float liquid = 1 - smoothstep(_Min, _Min + _liquidEdge, input.axis.y*0.5+0.5) ;

                clip(liquid - _Cutoff);

                _OutsideColor.rgb = _OutsideColor.rgb * halfLambert;
                _InsideColor.rgb = _InsideColor.rgb ;
                
                return _OutsideColor;

            }

            ENDHLSL
        }

        pass
        {
            Name "BottleEffect2"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            // ZWrite On
            Cull front
            ZTest on
            Blend SrcAlpha OneMinusSrcAlpha
            AlphaToMask On
            // ZWrite On



            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #pragma target 4.5

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fog

            #pragma multi_compile  _MAIN_LIGHT_SHADOWS
            #pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile  _SHADOWS_SOFT
            #pragma shader_feature _ENABLENORMALMAP

            CBUFFER_START(UnityPerMaterial)

                float4 _BaseMap_ST;
                float4 _MainTex_ST;
                // float4 _EmissiveMap_ST;
                // half _SpecPower;
                // float4 _SpecColor;
                // float4 _EmissiveColor;
                float _NormalScale, _FresnelStepValue2;
                float _OutLineWidth;
                float4 _RimColor;
                float _FresnelPower;
                float _AOPower;
                // float _SpacSmoothness;
                // float _SpecAOPower;
                // float _SpecMaskPower;
                float _LightInfluence;
                float _FresnelStepValue;
                half4 _InsideColor, _OutsideColor;
                float4 _NormalMap_ST;
                float _OffsetMul, _Threshold, _Min, _liquidEdge, _Cutoff;

                half _SpecPower;

                float _WobbleX, _WobbleZ;

            CBUFFER_END

            // TEXTURE2D(_EmissiveMap); SAMPLER(sampler_EmissiveMap);
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MaskMap); SAMPLER(sampler_MaskMap);
            TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);

            TEXTURE2D_X_FLOAT(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
            
            struct a2v
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 texcoord : TEXCOORD0;
                float4 color : COLOR;
                // UNITY_VERTEX_INPUT_INSTANCE_ID


            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float4 positionOS : TEXCOORD8;
                float3 positionWS : TEXCOORD0;
                // float3 positionVS : TEXCOORD4;
                float2 uv : TEXCOORD1;
                // float fogCoord : TEXCOORD2;
                float3 normalWS : TEXCOORD3;
                // float3 normalVS : TEXCOORD5;
                float4 positionNDC : TEXCOORD5;
                float4 positionSS : TEXCOORD2;
                float2 screenPos : TEXCOORD6;

                float3 tangentWS : TEXCOORD4;
                float3 bitangentWS : TEXCOORD7;
                float3 axis :TEXCOORD9;

                
                // UNITY_VERTEX_OUTPUT_STEREO

            };


            v2f vert(a2v input)
            {
                v2f o;
                // UNITY_SETUP_INSTANCE_ID(input);
                // UNITY_TRANSFER_INSTANCE_ID(input, output);
                // UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                o.positionCS = TransformObjectToHClip(input.positionOS);
                o.positionWS = TransformObjectToWorld(input.positionOS.xyz);

                
                o.normalWS = TransformObjectToWorldNormal(input.normalOS.xyz, true);
                o.tangentWS = TransformObjectToWorldDir(input.tangentOS);
                o.positionOS = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));

                o.axis = o.positionWS -o.positionOS;
                // o.positionVS = TransformWorldToView(TransformObjectToWorld(input.positionOS.xyz));
                // normalVS = TransformWorldToViewDir(normalWS, true);

                // o.bitangentWS = normalize(cross(o.normalWS,o.tangentWS) * input.tangentOS.w);

                //scr pos
                o.positionSS = ComputeScreenPos(vertexInput.positionCS);
                o.screenPos = o.positionSS.xy / o.positionSS.w;

                // //recive shadow
                // o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
                
                o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                // o.vertexColor = input.color;
                

                return o;
            }

            half4 frag(v2f input, bool vf : SV_ISFRONTFACE) : SV_TARGET
            {
                // UNITY_SETUP_INSTANCE_ID(input);
                // UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                clip(1 - vf );

                float3 positionVS = TransformWorldToView(input.positionWS);
                float3 normalVS = TransformWorldToViewDir(normalize(input.normalWS), true);

                //initialize main light
                Light MainLight = GetMainLight();
                half3 LightDir = normalize(half3(MainLight.direction));
                half3 LightColor = MainLight.color.rgb;


                //Normal map

                float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv);
                float3 bump = UnpackNormalScale(normalMap, _NormalScale);
                input.normalWS = TransformTangentToWorld(bump, float3x3(input.bitangentWS, input.tangentWS, input.normalWS));
                

                // //EmissiveMap
                // float4 EmissiveMap = SAMPLE_TEXTURE2D(_EmissiveMap, sampler_EmissiveMap, input.uv);
                // EmissiveMap *= _EmissiveColor;

                // //Mask map
                // float4 MaskMap = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);

                // //Blinn_phong
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
                float3 HalfWay = normalize(viewDir + LightDir);
                half blinnPhong = (pow(saturate(max(0,dot(input.normalWS, HalfWay))), _SpecPower));


                //Lambert & ramp

                float Lambert = dot(LightDir, input.normalWS)  ;
                float halfLambert = (Lambert * 0.5 + 0.5); // * pow(abs(MaskMap.g), _AOPower)  ;
                
                float4 difusse = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);

                float Depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, input.screenPos);

                input.axis.y += input.axis.x * _WobbleX;
                input.axis.y += input.axis.z * _WobbleZ;

                float liquid = 1 - smoothstep(_Min, _Min + _liquidEdge, input.axis.y*0.5+0.5) ;

                clip(liquid - _Cutoff);

                _InsideColor.rgb = _InsideColor.rgb * halfLambert;
                
                return half4(_InsideColor.rgb   , _InsideColor.a);

            }

            ENDHLSL
        }


    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
