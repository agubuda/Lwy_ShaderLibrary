Shader "LwyShaders/ClothSimulation_Lambert" {
    Properties {
        _BaseMap ("Texture", 2D) = "white" { }
        [MainColor] _BaseColor ("Base Color", Color) = (1,1,1,1)
    }

    SubShader {
        Tags { "Queue" = "Geometry" "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask 0
            Cull Off 

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            StructuredBuffer<float3> _Pos;

            struct Attributes {
                uint vertexID : SV_VertexID;
            };

            struct Varyings {
                float4 positionCS : SV_POSITION;
            };

            Varyings DepthOnlyVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                float3 positionWS = _Pos[input.vertexID];
                output.positionCS = TransformWorldToHClip(positionWS);
                return output;
            }

            half4 DepthOnlyFragment(Varyings input) : SV_TARGET
            {
                return 0;
            }
            ENDHLSL
        }

        Pass {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            ZWrite On
            Cull Off

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_local _ _RECALC_NORMALS_ON
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            StructuredBuffer<float3> _Pos;
            StructuredBuffer<float3> _Normals;
            
            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            CBUFFER_END

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            struct Attributes {
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                uint vertexID : SV_VertexID;
            };

            struct Varyings {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            Varyings vert(Attributes input) {
                Varyings output = (Varyings)0;

                // Position always from Buffer
                float3 positionWS = _Pos[input.vertexID];
                output.positionWS = positionWS;
                output.positionCS = TransformWorldToHClip(positionWS);
                
                #if _RECALC_NORMALS_ON
                    // High Quality: Read calculated normal from Compute Shader
                    float3 normalWS = _Normals[input.vertexID];
                    output.normalWS = normalize(normalWS);
                #else
                    // Performance: Use Unity's original normal (skinned or static)
                    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                #endif

                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

                return output;
            }

            half4 frag(Varyings input) : SV_TARGET {
                
                float3 normalWS = normalize(input.normalWS);
                float3 lightDir = normalize(_MainLightPosition.xyz);
                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;

                float NdotL = abs(dot(normalWS, lightDir));
                float3 lighting = albedo.rgb * _MainLightColor.rgb * NdotL;
                lighting += albedo.rgb * 0.1;

                return half4(lighting, albedo.a);
            }
            ENDHLSL
        }
    }
}