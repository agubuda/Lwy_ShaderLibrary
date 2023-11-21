Shader "LwyShaders/ShadowOnly"
{
     Properties
    {


        [Space(20)][Header(base settings)]   
        _BaseMap ("Texture", 2D) = "white" { }
        _BaseColor("baseColor", color) = (0,0,0,1)

        _ShadowAlpha("Shadow alpha", Range(0,1)) = 0.8


    }

    SubShader
    {

        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }

        pass
        {
            Name "ghostEffect"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            
            Cull back
            Blend SrcAlpha OneMinusSrcAlpha


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
                float _ShadowAlpha;

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
                
                float4 color = (difusse  * _BaseColor ) ;

                //recive shadow

                color *= (1 - MainLight.shadowAttenuation) * _ShadowAlpha ;

                return color;
            }

            ENDHLSL
        }

    
}
}
