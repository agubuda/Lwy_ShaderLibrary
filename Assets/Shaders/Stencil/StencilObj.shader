Shader "LwyShaders/StencilObj"
{
    Properties
    {
        [Space(20)][Header(base settings)]
        _BaseMap ("Texture", 2D) = "white" { }
        _BaseColor ("baseColor", color) = (1, 0, 0, 1)

        // _ShadowAlpha ("Shadow alpha", Range(0,1)) = 0.8
        _RefNumber ("Reference Number", Range(0, 255)) = 1
    }

    SubShader
    {

        Tags { "Queue" = "Geometry+1" "RenderType" = "Opaque" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }

        pass
        {
            Name "StencilObj"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            
            // Cull back
            // Blend Zero One
            

            Stencil
            {
                Ref [_RefNumber]       //参考值为2
                Comp NotEqual          //stencil比较方式是相同，只有等于2的才能通过
                Pass keep              //stencil和Zbuffer都测试通过时，选择保持
                Fail decrWrap          //stencil没通过，选择溢出型减1，所以被平面挡住的那层stencil值就变成254
                ZFail keep             //stencil通过，深度测试没通过时，选择保持

            }


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
                half4 _BaseColor;
                // float _ShadowAlpha;

            CBUFFER_END

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

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

            };

            v2f vert(a2v input)
            {
                v2f o;

                o.positionCS = TransformObjectToHClip(input.positionOS);
                o.positionWS = TransformObjectToWorld(input.positionOS.xyz);

                // //recive shadow
                // o.shadowCoord = TransformWorldToShadowCoord(o.positionWS); do not cuculate this in vert, could cause glitch problem.
                
                o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                

                return o;
            }

            float4 frag(v2f input) : SV_TARGET
            {

                float3 positionVS = TransformWorldToView(input.positionWS);

                //initialize main light
                Light MainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
                half3 LightDir = normalize(half3(MainLight.direction));
                half3 LightColor = MainLight.color.rgb;

                float4 difusse = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                
                float4 color = (difusse * _BaseColor) ;

                //recive shadow

                // color *= (1 - MainLight.shadowAttenuation) * _ShadowAlpha ;

                return color;
            }

            ENDHLSL
        }

        Pass
        {
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


            CBUFFER_START(UnityPerMaterial)
                half _Surface;

                half4 _BaseColor;
                half4 _AnisotropyColor;
                half _Darkness;
                half _Glossness;
                half _Cutoff;
                half4 _SpecColor;
                half _SpecPower;
                
                half4 _BaseMap_ST;
                half4 _NormalMap_ST;
                half4 _NoiseMap_ST;
                half4 _AOMap_ST;
                
                half _NormalScale;
                half _NoisePower;
                half _AnisotropyPower;
                half _FrenelPower;
                half4 _RimColor;
                half _Exponent;
                half _FrenelLightness;
                half _AOContrast;

                float4 _DetailAlbedoMap_ST;
                half4 _EmissionColor;
                half _Smoothness;
                half _Metallic;
                half _BumpScale;
                half _Parallax;
                half _OcclusionStrength;
                half _ClearCoatMask;
                half _ClearCoatSmoothness;
                half _DetailAlbedoMapScale;
                half _DetailNormalMapScale;
            CBUFFER_END

            // -------------------------------------
            // Material Keywords
            // #pragma shader_feature_local_fragment _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            // #pragma multi_compile_instancing
            // #pragma multi_compile _ DOTS_INSTANCING_ON

            // #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
}
