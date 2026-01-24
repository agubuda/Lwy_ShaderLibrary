Shader "LwyShaders/ClothSimulation_Lambert" {
    Properties {
        _BaseMap ("Texture", 2D) = "white" { }
        [MainColor] _BaseColor ("Base Color", Color) = (1,1,1,1)
    }

    SubShader {
        Tags { "Queue" = "Geometry" "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        // 1. Depth Pass
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

        // 2. Main Lighting Pass (Simple Lambert)
        Pass {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            ZWrite On
            Cull Off

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            StructuredBuffer<float3> _Pos;
            
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

                // Read position from Compute Buffer
                float3 positionWS = _Pos[input.vertexID];
                
                output.positionWS = positionWS;
                output.positionCS = TransformWorldToHClip(positionWS);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

                return output;
            }

            half4 frag(Varyings input) : SV_TARGET {
                
                // 1. Basic Data
                float3 normalWS = normalize(input.normalWS);
                float3 lightDir = normalize(_MainLightPosition.xyz);
                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;

                // 2. Simple Lambertian Diffuse
                float NdotL = max(0.0, dot(normalWS, lightDir));
                
                // 3. Lighting calculation
                float3 lighting = albedo.rgb * _MainLightColor.rgb * NdotL;
                
                // Ambient
                lighting += albedo.rgb * 0.1;

                return half4(lighting, albedo.a);
            }
            ENDHLSL
        }
    }
}