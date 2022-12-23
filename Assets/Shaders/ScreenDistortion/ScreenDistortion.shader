Shader "LwyShaders/ScreenDistortion"
{
    Properties
    {


        [Space(20)][Header(base settings)]
        _BaseMap ("Texture", 2D) = "white" { }
        _BaseColor ("baseColor", color) = (0, 0, 0, 1)
        _DistortionMap ("_DistortionMap", 2D) = "bump" { }
        _ShadowAlpha ("Shadow alpha", Range(0, 1)) = 0.8
        [Toggle(_VERTEX_COLORS)] _VertexColors ("Vertex Colors", Float) = 0
        _NormalStength("Normal stength", Range(-1,1)) = 0.1
    }

    SubShader
    {

        Tags { "Queue" = "Transparent+1" "RenderType" = "Transparent" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }

        pass
        {
            Name "ScreenDistortion"
            Tags { "LightMode" = "UniversalForward" }
            
            Cull back
            // ZTest off
            Blend SrcAlpha OneMinusSrcAlpha


            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma target 4.5

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fog

            // #pragma multi_compile  _MAIN_LIGHT_SHADOWS
            // #pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
            // #pragma multi_compile  _SHADOWS_SOFT

            #pragma shader_feature _ENABLENORMALMAP
            #pragma shader_feature _VERTEX_COLORS

            CBUFFER_START(UnityPerMaterial)

                float4 _BaseMap_ST;
                float4 _MainTex_ST;
                half4 _BaseColor;
                float _ShadowAlpha, _NormalStength;

            CBUFFER_END

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_CameraOpaqueTexture); SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURE2D(_DistortionMap); SAMPLER(sampler_DistortionMap);

            struct a2v
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float4 texcoord : TEXCOORD0;
                float flipbookBlend : TEXCOORD1;

                // #if  _VERTEX_COLORS
                    float4 color : COLOR;
                // #endif

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                // float3 positionVS : TEXCOORD4;
                float2 uv : TEXCOORD1;
                float4 positionSS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
                float3 normalWS: TEXCOORD5;


                #if  _VERTEX_COLORS
                    float4 color : VAR_COLOR;
                #endif
                // float fogCoord : TEXCOORD2;

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

                // //recive shadow
                // o.shadowCoord = TransformWorldToShadowCoord(o.positionWS); do not cuculate this in vert, could cause glitch problem.
                
                o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

                #if _VERTEX_COLORS
                    o.color = input.color;
                #endif

                o.positionSS = ComputeScreenPos(o.positionCS);

                return o;
            }

            half4 frag(v2f input) : SV_TARGET
            {

                float3 positionVS = TransformWorldToView(input.positionWS);

                float2 srcPos = input.positionSS.xy / input.positionSS.w;

                //initialize main light
                Light MainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
                half3 LightDir = normalize(half3(MainLight.direction));
                half3 LightColor = MainLight.color.rgb;

                half4 distortionMap = SAMPLE_TEXTURE2D(_DistortionMap, sampler_DistortionMap, input.uv);
                half3 bump = UnpackNormalScale(distortionMap, _NormalStength);
                half2 bump2 = UnpackNormalScale(distortionMap, _NormalStength).rg;
                half2 bump3 = UnpackNormalmapRGorAG(distortionMap, _NormalStength).rg;

                float3x3 TBN = {input.bitangentWS, input.tangentWS, input.normalWS};
                bump.z = pow(1 - pow(bump.x,2) - pow(bump.y,2), 0.5);
                input.normalWS = mul(bump,TBN);

                // float2 temp = DecodeNormal(distortionMap, 1);


                half4 difusse = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half4 screenOpaqueColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, srcPos.xy + bump3);

                float4 color = difusse * _BaseColor ;

                //recive shadow

                color *= screenOpaqueColor;
                color.a = difusse.a;
                clip(color.a - 0.01);

                return color;
            }

            ENDHLSL
        }
    }
}
