Shader "LwyShaders/NPRFace" {
    Properties {
        _BaseMap ("Texture", 2D) = "white" { }
        _BaseColor ("Color", color) = (1, 1, 1, 1)
        [Header(Modify alpha color value for Blush.)]
        _BlushColor("Blush Color", color) = (1,0.5,0.5,0.0)

        [Space(20)][Header(Ramp lights)]
        _RampMap ("Ramp Map", 2D) = "White" { }
        _RampColum ("Ramp colum", Range(0,1)) = 0.8
        _SDFMap ("_SDFMap", 2D) = "White" { }
        _LerpMax("_LerpMax",Range(0,1)) = 0.1
        _SDFRampDarkness("SDF Ramp Darkness", Range(0,1)) = 0.4

        [Space(20)][Header(Outline settings)]
        _OutLineWidth ("Outline width", float) = -0.04
        _OutLineColor ("Outline color", color) = (0.4, 0.3, 0.3, 1)
        _RimColor ("RimColor", color) = (0.8, 0.7, 0.7, 1)

        [Space(20)][Header(Env and dir light)]
        [Toggle(_ENABLEENVIROMENTLIGHT)] _ENABLEENVIROMENTLIGHT ("Enable enviroment light", Float) = 0.0
        _LightInfluence ("Light influence", Range(0.1, 1.5)) = 1

        [Space(20)][Header(Hit Color)]
        _HitColor ("Hit color", color) = (1.0,1.0,1.0,1.0)
        _HitValue("Hit Value",Range(0.0,1.0))= 0.0
    }

    SubShader {

        Tags { "Queue" = "Geometry" "RenderType" = "Opaque" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }

        Pass {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

            // -------------------------------------
            // Material Keywords
            // #pragma shader_feature_local_fragment _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            // #pragma multi_compile_instancing
            // #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        Pass {
            Name "NPR Face"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            ZWrite On

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


            // #pragma multi_compile _ _DEPTH_MSAA_2 _DEPTH_MSAA_4 _DEPTH_MSAA_8


            CBUFFER_START(UnityPerMaterial)

            float4 _BaseMap_ST;
            float4 _MainTex_ST;
            float4 _BlushColor,_RimColor;
            float _OutLineWidth;
            float _RampColum;
            float _OffsetMul;
            float _Threshold;
            float4 _BaseColor;
            float _LerpMax, _SDFRampDarkness;
            float _LightInfluence;

            CBUFFER_END

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_RampMap); SAMPLER(sampler_RampMap);
            TEXTURE2D(_SDFMap); SAMPLER(sampler_SDFMap);
            // TEXTURE2D_FLOAT(_CameraDepthAttachment);
            // SAMPLER(sampler_CameraDepthAttachment);

            struct a2v {

                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 texcoord : TEXCOORD0;
                // float2 secondTexcoord : TEXCOORD1;

            };

            struct v2f {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float4 scrPos : TEXCOORD4;
                float4 shadowCoord : TEXCOORD5;
                float3 tangentWS : TEXCOORD6;
                float3 bitangentWS : TEXCOORD7;
                float3 leftDir : TEXCOORD8;
                float3 frontDir : TEXCOORD9;
            };

            half CalculateSDFShadow(Texture2D SDFMap, SamplerState sampler_SDFMap, half2 uv, half3 light_dir, half3 front_dir, half3 right_dir)
            {
                half RdotL = dot(right_dir, light_dir) ;
                half FdotL = dot(front_dir, light_dir);
                FdotL = ((-FdotL + 1.0) * 0.5) * ((-FdotL + 1.0) * 0.5);

                half sdf_col = RdotL < 0 ? SAMPLE_TEXTURE2D(SDFMap, sampler_SDFMap, uv).r : SAMPLE_TEXTURE2D(SDFMap, sampler_SDFMap, float2(1-uv.x, uv.y)).r;
                return  FdotL < sdf_col;
            }


            v2f vert(a2v input) {
                v2f o;

                o.positionCS = TransformObjectToHClip(input.positionOS);
                o.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(input.normalOS.xyz, true);
                o.tangentWS = TransformObjectToWorldDir(input.tangentOS);

                o.bitangentWS = normalize(cross(o.normalWS, o.tangentWS) * input.tangentOS.w);

                //scr pos
                o.scrPos = ComputeScreenPos(o.positionCS);

                //recive shadow
                o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);

                o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

                return o;
            }

            float4 frag(v2f input) : SV_TARGET {
                //initialize main light
                Light MainLight = GetMainLight(input.shadowCoord);
                float3 LightDir = float3(MainLight.direction);
                float4 LightColor = float4(MainLight.color, 1);

                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
                float3 HalfWay = normalize(viewDir + LightDir);

                float4 difusse = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                difusse *= _BaseColor;
                difusse.rgb = lerp( difusse.rgb , _BlushColor.rgb * difusse.rgb, difusse.a * _BlushColor.a);

                float4 color = difusse;

                // recive shadow
                // color *= (MainLight.shadowAttenuation + 0.5);


                // return fresnelDepthRim;

                //sdf
                float isShadow = 0;

                float4 SDFMap = SAMPLE_TEXTURE2D(_SDFMap, sampler_SDFMap, input.uv);
                float4 SDFMap_R = SAMPLE_TEXTURE2D(_SDFMap, sampler_SDFMap, float2(1-input.uv.x,input.uv.y));

                float3 leftDir = TransformObjectToWorldDir(float3(-1, 0, 0));
                float3 rightDir = TransformObjectToWorldDir(float3(1, 0, 0));
                float3 frontDir = TransformObjectToWorldDir(float3(0, 0, 1));
                float FdotL = dot(frontDir.xz,normalize(LightDir.xz));
                // FdotL = ((-FdotL + 1.0) * 0.5) * ((-FdotL + 1.0) * 0.5);
                FdotL = -FdotL*0.5 + 0.5;
                float ctrl = clamp(0,1,FdotL);
                float ilm = dot(LightDir.xz, leftDir.xz) > 0 ? SDFMap.r : SDFMap_R.r;

                isShadow = step(ilm,ctrl);
                float bias = smoothstep(0, _LerpMax, abs(ctrl - ilm));

                float4 SDFShadowColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(_SDFRampDarkness, _RampColum));

                float SDFFactor = 0;


                if (ctrl > 0.99 || isShadow == 1)
                {

                    SDFFactor = lerp(0,1,bias);
                }

                float SDFFactor2 = 0;

                SDFFactor2 = 1 - CalculateSDFShadow(_SDFMap, sampler_SDFMap,input.uv,LightDir,frontDir,rightDir);

                color = lerp(color,color*SDFShadowColor,SDFFactor);

                //frenel rim
                float fresnelRim = 1 - saturate(dot(normalize(input.normalWS), viewDir));
                float fresnelRimPow = saturate(pow(max(0.001,fresnelRim),5));
                float4 fresnelDepthRim = fresnelRimPow * _RimColor;

                color = lerp(color, fresnelDepthRim, fresnelRimPow);

                //ambient light
                #if _ENABLEENVIROMENTLIGHT
                    float4 ambient = float4(max(float4(0.1,0.1,0.1,1), SampleSH(input.normalWS)), 1) ;
                    // float4 GI = (0, 0, 0, 0);
                    color *= (lerp(LightColor,(ambient),SDFFactor) * _LightInfluence);
                #endif


                return color;
            }

            ENDHLSL
        }

        Pass {
            Name "Outline"
            Tags { "Queue" = "Geometry" "IgnoreProjector" = "True" "LightMode" = "UniversalForward" }
            Cull Front

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
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
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                float3 vertColor : COLOR;
            };

            struct v2f {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                // float2 worldNormal : TEXCOORD1;
                // float2 uv : TEXCOORD2;
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

                // positionOS+=normalOS * _OutLineWidth * input.vertColor.r;
                // o.positionCS=TransformObjectToHClip(positionOS);
                o.positionCS = TransformWorldToHClip(o.positionWS);

                // input.positionOS.xyz += input.tangent * 0.01 *_OutLineWidth;
                // o.positionCS = TransformObjectToHClip(input.positionOS.xyz + input.normal * _OutLineWidth *0.1);
                //o.positionCS = TransformObjectToHClip(input.positionOS);

                //o.positionCS.xy += input.normal.xy * _OutLineWidth * 0.1 * o.positionCS.w ;
                // o.vertColor = input.vertColor;

                // o.uv = input.uv;

                return o;
            }

            half4 frag(v2f input) : SV_TARGET {
                return _OutLineColor;
            }

            ENDHLSL
        }

        // Pass {
        //     Name "ShadowCaster"
        //     Tags { "LightMode" = "ShadowCaster" }

        //     ZWrite On
        //     ZTest LEqual
        //     ColorMask 0
        //     Cull[_Cull]

        //     HLSLPROGRAM
        //     #pragma exclude_renderers gles gles3 glcore
        //     #pragma target 4.5

        //     #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        //     #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
        //     #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
        //     #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"

        //     // -------------------------------------
        //     // Material Keywords
        //     #pragma shader_feature_local_fragment _ALPHATEST_ON
        //     #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

        //     //--------------------------------------
        //     // GPU Instancing
        //     #pragma multi_compile_instancing
        //     #pragma multi_compile _ DOTS_INSTANCING_ON

        //     #pragma vertex ShadowPassVertex
        //     #pragma fragment ShadowPassFragment

        //     #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
        //     #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
        //     ENDHLSL
        // }
    }
}
