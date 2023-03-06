/* You have to change the universal renderer data 
-> Rendering-> Depth priming Mode to FORCED, 
or write a render feature instead. */

Shader "LwyShaders/loongEffect"
{
     Properties
    {
        [Space(20)][Header(emissive map)]
        _EmissiveMap ("_EmissiveMap", 2D) = "white" { }
        [HDR]_EmissiveColor("_EmissiveColor", color) = (1,0,0,1)

        [Space(20)][Header(base settings)]   
        _BaseMap ("Texture", 2D) = "white" { }
        _BaseColor("baseColor", color) = (0,0,0,1)

        _darkness("darkness", Range(0,1)) = 0.05
        _brightness("brightness",  Range(0,1)) = 0.09
        _darkArea("dark area", Range(0,1)) = 0.5
        _darkAreaEdge("dark area edge", Range(0,1)) = 0.55

        [Toggle(_ENABLENORMALMAP)] _ENABLENORMALMAP(" Enable normal map",float) = 0
        _NormalMap("Normal map", 2D) = "bump"{}
        _NormalScale("Normal scale", float) = 1
        
        // [Space(20)][Header(Outline settings)]
        // _OutLineWidth ("Outline width", float) = -0.04
        // _OutLineColor ("Outline color", color) = (0.4, 0.3, 0.3, 1)

        [Space(20)][Header(Rim light settings)]
        _OffsetMul ("_RimWidth", Range(0, 0.1)) = 0.0055
        _Threshold ("_Threshold", Range(0, 1)) = 0.02
        _RimColor ("RimColor", color) = (0.8, 0.7, 0.7, 1)
        // _FresnelPower ("Fresnel power", Range(0, 10)) = 3
        // _FresnelStepValue ("_FresnelStepValue", Range(0, 1)) = 0.1
        
        [Space(20)][Header(AO map)]
        _MaskMap ("Mask Map", 2D) = "white" { }//as urp default settings, g = AO, a = Metalic
        _AOPower ("AO power", Range(0, 6)) = 1

        [Space(20)][Header(Specular)]
        _SpecPower ("Specular Power", float) = 10
        _SpecColor ("Specular Color", color) = (0.4, 0.3, 0.3, 1)
        _SpecRange ("Specular Range", Range(0, 1)) = 0.075
        _SpacSmoothness ("Specular Edge Smoothness", Range(0, 1)) = 0.58
        // _SpecStrength ("Specular Range", float) = 0.86
        _SpecAOPower ("Specular AO power", float) = 0.5
        _SpecMaskPower ("Specular Mask power", Range(0, 10)) = 1

        // [Space(20)][Header(Color adjastment)]
        // _HueRed ("Hue red", Range(-1, 1)) = 0
        // _HueBlue ("Hue blue", Range(-1, 1)) = 0
        // _HueGreen ("Hue green", Range(-1, 1)) = 0
    }

    SubShader
    {

        Tags { "Queue" = "AlphaTest" "RenderType" = "Opaque" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }



        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly"}

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
            
            CBUFFER_START(UnityPerMaterial)

                // float4 _BaseMap_ST;
                float4 _MainTex_ST;
                float4 _EmissiveMap_ST;
                half _SpecPower;
                float4 _SpecColor;
                float4 _EmissiveColor;
                float _SpecRange, _NormalScale , _brightness, _darkness , _darkAreaEdge ,_darkArea;
                // float _SpecStrength;
                float _OutLineWidth;
                float _OffsetMul;
                float _Threshold;
                float4 _RimColor;
                float _FresnelPower;
                float _AOPower;
                float _SpacSmoothness;
                float _SpecAOPower;
                float _SpecMaskPower;
                float _LightInfluence;
                float _HueBlue;
                float _HueRed;
                float _HueGreen;
                float _FresnelStepValue;
                // float4 _BaseColor;
                // float4 _NormalMap;
                float4 _NormalMap_ST;
                // float4 _AOMap;

            CBUFFER_END

            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        pass
        {
            Name "NPR skin"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            // ZWrite On
            Cull off


            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
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
                float4 _EmissiveMap_ST;
                half _SpecPower;
                float4 _SpecColor;
                float4 _EmissiveColor;
                float _SpecRange, _NormalScale , _brightness, _darkness , _darkAreaEdge ,_darkArea;
                // float _SpecStrength;
                float _OutLineWidth;
                float _OffsetMul;
                float _Threshold;
                float4 _RimColor;
                float _FresnelPower;
                float _AOPower;
                float _SpacSmoothness;
                float _SpecAOPower;
                float _SpecMaskPower;
                float _LightInfluence;
                float _HueBlue;
                float _HueRed;
                float _HueGreen;
                float _FresnelStepValue;
                float4 _BaseColor;
                // float4 _NormalMap;
                float4 _NormalMap_ST;
                // float4 _AOMap;

            CBUFFER_END

            TEXTURE2D(_EmissiveMap); SAMPLER(sampler_EmissiveMap);
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
                // float2 secondTexcoord : TEXCOORD1;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                // float3 positionVS : TEXCOORD4;
                float2 uv : TEXCOORD1;
                // float fogCoord : TEXCOORD2;
                float3 normalWS : TEXCOORD3;
                // float3 normalVS : TEXCOORD5;
                float4 positionNDC : TEXCOORD6;
                float4 scrPos : TEXCOORD7;
                float4 shadowCoord : TEXCOORD8;
                float3 tangentWS : TEXCOORD9;
                float3 bitangentWS : TEXCOORD10;
            };

            v2f vert(a2v input)
            {
                v2f o;

                o.positionCS = TransformObjectToHClip(input.positionOS);
                o.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(input.normalOS.xyz, true);
                o.tangentWS = TransformObjectToWorldDir(input.tangentOS);
                // o.positionVS = TransformWorldToView(TransformObjectToWorld(input.positionOS.xyz));
                // normalVS = TransformWorldToViewDir(normalWS, true);

                o.bitangentWS = normalize(cross(o.normalWS,o.tangentWS) * input.tangentOS.w);

                //NDC
                float4 ndc = input.positionOS * 0.5f;
                o.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
                o.positionNDC.zw = TransformObjectToHClip(input.positionOS).zw;

                //scr pos
                o.scrPos = ComputeScreenPos(o.positionCS);

                // //recive shadow
                // o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
                
                o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                

                return o;
            }

            float4 frag(v2f input) : SV_TARGET
            {

                float3 positionVS = TransformWorldToView(input.positionWS);
                float3 normalVS = TransformWorldToViewDir(normalize(input.normalWS), true);

                //initialize main light
                Light MainLight = GetMainLight(input.shadowCoord);
                float3 LightDir = normalize(float3(MainLight.direction));
                float4 LightColor = float4(MainLight.color, 1);


                //Normal map
                #if _ENABLENORMALMAP
                float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv);
                float3 bump  = UnpackNormalScale(normalMap, _NormalScale);
                // input.normalWS = TransformTangentToWorld(bump, float3x3(input.bitangentWS,input.tangentWS, input.normalWS  ));
                float3x3 TBN = {input.bitangentWS,input.tangentWS, input.normalWS };
                bump.z = pow((1- pow(bump.x,2) - pow(bump.y,2)), 0.5);
                input.normalWS = mul(bump, TBN);
                #endif

                //EmissiveMap
                float4 EmissiveMap = SAMPLE_TEXTURE2D(_EmissiveMap, sampler_EmissiveMap, input.uv);
                EmissiveMap *= _EmissiveColor;

                //Mask map
                float4 MaskMap = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);

                //Blinn_phong
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
                float3 HalfWay = normalize(viewDir + LightDir);
                half blinnPhong = (pow(saturate(max(0,dot(input.normalWS, HalfWay))), _SpecPower)) * (MaskMap.a * _SpecMaskPower);
                half4 blinnPhongNPR = smoothstep(_SpecRange, _SpecRange + _SpacSmoothness, blinnPhong) * _SpecColor;


                //Lambert & ramp

                float Lambert = dot(LightDir, input.normalWS)  ;
                float halfLambert = (Lambert * 0.5 + 0.5) * pow(MaskMap.g, _AOPower)  ;

                float stepHalfLambert = smoothstep(_darkArea, _darkAreaEdge, halfLambert);
                stepHalfLambert = clamp(stepHalfLambert, _darkness, _brightness);
                
                float4 difusse = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);

                //rim light

                float depth = input.positionNDC.z / input.positionNDC.w;

                float2 screenPos = input.scrPos.xy / input.scrPos.w;
                float2 RimScreenUV = float2(input.positionCS.x / _ScreenParams.x, input.positionCS.y / _ScreenParams.y);
                float2 RimOffsetUV = RimScreenUV + normalVS * _OffsetMul;
                
                float linearEyeDepth = LinearEyeDepth(depth, _ZBufferParams); // 离相机越近越小
                float offsetDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, RimOffsetUV).r; // _CameraDepthTexture.r = input.positionNDC.z / input.positionNDC.w
                float linearEyeOffsetDepth = LinearEyeDepth(offsetDepth, _ZBufferParams);
                float depthDiff = linearEyeOffsetDepth - linearEyeDepth;
                float rimIntensity = step(_Threshold, depthDiff);

                // //frenel rim
                // float4 fresnelRim = pow(1 - saturate(dot(normalize(input.normalWS), viewDir)), _FresnelPower);
                // float4 fresnelDepthRim = rimIntensity * fresnelRim * _RimColor;
                // fresnelDepthRim = smoothstep(0.1,0.12,fresnelRim);

                // if(((1 - smoothstep(0,0.3,Lambert) ) * ambient) = 0){}
                float4 color = (difusse  * _BaseColor * stepHalfLambert + blinnPhongNPR + rimIntensity * _RimColor + EmissiveMap) ;

                // //hue
                //     color.r = color.r + _HueRed;
                //     color.g = color.g + _HueGreen;
                //     color.b = color.b + _HueBlue;


                return color;
            }

            ENDHLSL
        }


        // Pass
        // {
        //     Name "Outline"
        //     Tags { "Queue" = "Geometry" "IgnoreProjector" = "True" "LightMode" = "SRPDefaultUnlit" }
        //     Cull Front

            
        //     HLSLPROGRAM

            

        //     #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        //     // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        //     #pragma vertex vert
        //     #pragma fragment frag

        //     CBUFFER_START(UnityPerMaterial)

                
        //         float _OutLineWidth;
        //         float4 _OutLineColor;

        //     CBUFFER_END


        //     struct a2v
        //     {
        //         float4 positionOS : POSITION;
        //         float3 normal : NORMAL;
        //         float4 tangent : TANGENT;
        //         float2 uv : TEXCOORD0;
        //         float3 vertColor : COLOR;
        //     };

        //     struct v2f
        //     {
        //         float4 positionCS : SV_POSITION;
        //         // float3 positionWS : TEXCOORD0;
        //         // float2 worldNormal : TEXCOORD1;
        //         // float2 uv : TEXCOORD2;
        //         // float3 vertColor : COLOR;

        //     };

        //     v2f vert(a2v input)
        //     {
        //         v2f o;

        //         // input.positionOS.xyz += input.tangent * 0.01 *_OutLineWidth;
        //         // o.positionCS = TransformObjectToHClip(input.positionOS.xyz + input.normal * _OutLineWidth *0.1);
        //         o.positionCS = TransformObjectToHClip(input.positionOS);

        //         o.positionCS.xy += input.normal.xy * _OutLineWidth * 0.1 * input.vertColor.r;
        //         // o.vertColor = input.vertColor;

                
        //         // o.uv = input.uv;
                

        //         return o;
        //     }
            
        //     half4 frag(v2f input) : SV_TARGET
        //     {
        //         return _OutLineColor;
        //     }

        //     ENDHLSL
        // }
}
}
