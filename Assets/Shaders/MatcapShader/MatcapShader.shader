Shader "LwyShaders/Matcap"
{
     Properties
    {
        [Space(20)][Header(base settings)]   
        _BaseMap ("Texture", 2D) = "white" { }
        _BaseColor("baseColor", color) = (0,0,0,1)

        [Space(20)][Header(base settings)]   
        _MatCap("Mat Cap", 2D) = "black"{}
        _MatCapIntensity("Matcap intensity", float) = 1


        [Toggle(_ENABLENORMALMAP)] _ENABLENORMALMAP(" Enable normal map",float) = 0
        _NormalMap("Normal map", 2D) = "White"{}
        _NormalScale("Normal scale", float) = 1
        
    
 
        [HDR]_RimColor ("RimColor", color) = (0.8, 0.7, 0.7, 1)
        _FresnelPower ("Fresnel power", Range(0, 10)) = 3
        _FresnelStepValue ("_FresnelStepValue", Range(0, 1)) = 0.1
        _FresnelStepValue2 ("_FresnelStepValue2", Range(0, 1)) = 0.2
        
        [Space(20)][Header(AO map)]
        _MaskMap ("Mask Map", 2D) = "white" { }//as urp default settings, g = AO, a = Metalic
        _AOPower ("AO power", Range(0, 6)) = 1

    }

    SubShader
    {

        Tags { "Queue" = "Geometry" "RenderType" = "Opaque" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }

        pass
        {
            Name "ghostEffect"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            
            Cull back
            ZTest LEqual
            // Blend SrcAlpha OneMinusSrcAlpha


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
                float  _NormalScale , _FresnelStepValue2;
                float _OutLineWidth;
                float4 _RimColor;
                float _FresnelPower;
                float _AOPower;
                float _LightInfluence;
                float _FresnelStepValue;
                float4 _BaseColor;
                float4 _NormalMap_ST;
                float _MatCapIntensity;

            CBUFFER_END

        
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MaskMap); SAMPLER(sampler_MaskMap);
            TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MatCap); SAMPLER(sampler_MatCap);
            
            struct a2v
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 texcoord : TEXCOORD0;
                // float4 color : COLOR;
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
                // float4 positionNDC : TEXCOORD6;
                // float4 scrPos : TEXCOORD7;
                // float4 shadowCoord : TEXCOORD8;
                float3 tangentWS : TEXCOORD9;
                float3 bitangentWS : TEXCOORD10;
                // float4 vertexColor :TEXCOORD11;
            };

            v2f vert(a2v input)
            {
                v2f o;

                o.positionCS = TransformObjectToHClip(input.positionOS.xyzw);
                o.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(input.normalOS.xyz, true);
                o.tangentWS = TransformObjectToWorldDir(input.tangentOS.xyz);

                o.bitangentWS = normalize(cross(o.normalWS,o.tangentWS) * input.tangentOS.w);

                //scr pos
                // o.scrPos = ComputeScreenPos(o.positionCS);

                // //recive shadow
                // o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
                
                o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                // o.vertexColor = input.color;
                

                return o;
            }

            float4 frag(v2f input) : SV_TARGET
            {

                float3 positionVS = TransformWorldToView(input.positionWS);
                float3 normalVS = TransformWorldToViewDir(normalize(input.normalWS), true);

                float3 matCapUV = mul(UNITY_MATRIX_V,float4(input.normalWS.xyz,0));

                //initialize main light
                Light MainLight = GetMainLight();
                half3 LightDir = normalize(half3(MainLight.direction));
                half3 LightColor = MainLight.color.rgb;

                //mat cap
                half4 MatCapColor = SAMPLE_TEXTURE2D(_MatCap,sampler_MatCap,matCapUV.xy*0.49+0.5);


                //Normal map
                #if _ENABLENORMALMAP
                float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv);
                float3 bump  = UnpackNormalScale(normalMap, _NormalScale);

                float3x3 TBN = {input.bitangentWS,input.tangentWS, input.normalWS };
                bump.z = pow((1- pow(bump.x,2) - pow(bump.y,2)), 0.5);
                input.normalWS = mul(bump, TBN);
                #endif

                //Mask map
                float4 MaskMap = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);

                // //Blinn_phong
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);

                //Lambert & ramp

                // float Lambert = dot(LightDir, input.normalWS)  ;
                // float halfLambert = (Lambert * 0.5 + 0.5) * pow(abs(MaskMap.g), _AOPower)  ;

                // float stepHalfLambert = smoothstep(_darkArea, _darkAreaEdge, halfLambert);
                // stepHalfLambert = clamp(stepHalfLambert, _darkness, _brightness);
                
                float4 difusse = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);

                //frenel rim
                float4 fresnelRim = pow(1 - saturate(dot(normalize(input.normalWS), viewDir)), _FresnelPower);
                float4 finalFresnelRim = smoothstep(_FresnelStepValue,_FresnelStepValue2,fresnelRim);
                finalFresnelRim *=  fresnelRim ;
                finalFresnelRim *= _RimColor;
                finalFresnelRim *= MaskMap.r;


                // if(((1 - smoothstep(0,0.3,Lambert) ) * ambient) = 0){}
                float4 color = (difusse  * _BaseColor  ) +  MatCapColor * _MatCapIntensity ;

                return color;
            }

            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
            CBUFFER_START(UnityPerMaterial)

                // float4 _BaseMap_ST;
                float4 _MainTex_ST;
                float  _NormalScale , _FresnelStepValue2;
                float _OutLineWidth;
                float4 _RimColor;
                float _FresnelPower;
                float _AOPower;
                float _LightInfluence;
                float _FresnelStepValue;
                // float4 _BaseColor;
                float4 _NormalMap_ST;
                float _MatCapIntensity;

            CBUFFER_END

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
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
