Shader "Hidden/Custom/SnowEffect" {
    Properties {
        _MainTex ("Main Texture", 2D) = "white" { }
        _EffectTex ("Effect Texture", 2d) = "white" { }
        _MaskMap ("_MaskMap", 2d) = "white" { }
    }
    SubShader {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass {
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_MainTex);
            TEXTURE2D(_EffectTex);
            TEXTURE2D(_MaskMap);
            SAMPLER(sampler_MainTex);
            SAMPLER(sampler_EffectTex);
            SAMPLER(sampler_MaskMap);

            TEXTURE2D_X_FLOAT(_CameraDepthAttachment);
            SAMPLER(sampler_CameraDepthAttachment);
            // SAMPLER()

            float _Intensity;
            float4 _OverlayColor;
            float4 _EffectTex_ST;
            float4 _MaskMap_ST;
            // float4 _CameraDepthAttachment_ST;

            struct Attributes {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                uint vertexID : SV_VERTEXID;
            };

            struct Varyings {
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float4 positionSS : TEXCOORD2;
                float4 vertex : SV_POSITION;
                float2 scrPos : TEXCOORD3;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes input) {
                Varyings output = (Varyings)0;
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.vertex = vertexInput.positionCS;
                output.uv = input.uv;
                output.uv2 = input.uv;
                output.positionSS = ComputeScreenPos(vertexInput.positionCS);
                output.scrPos = output.positionSS.xy / output.positionSS.w;

                return output;
            }

            float4 frag(Varyings input) : SV_Target {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // int2 positionSS  = input.uv * _ScreenSize.xy;

                // input.uv.x *= unity_DeltaTime.w;
                float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);

                input.uv2 = (input.uv2.xy * _MaskMap_ST.xy * 1 + _EffectTex_ST.w + (_EffectTex_ST.zw + frac(_Time.y / 5)));

                float4 Mask = 1 - SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv2);

                input.uv = (input.uv.xy * _EffectTex_ST.xy * (1 + Mask * 0.02) + float2(_EffectTex_ST.z + frac(_Time.y / 3), _EffectTex_ST.w + frac(_Time.y / 3)));
                float4 color2 = SAMPLE_TEXTURE2D(_EffectTex, sampler_EffectTex, input.uv);

                float Depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthAttachment, sampler_CameraDepthAttachment, input.scrPos).r;
                // Depth = smoothstep(0.1,0.12, Depth);
                float linearDepth = LinearEyeDepth(Depth, _ZBufferParams);

                // return lerp(color, color2, _Intensity);
                Mask = clamp(Mask, 0.7, 0.9);
                color2 *= (Mask);
                color2 = pow(smoothstep(0.2, 0, color2), 9);
                color2 *= 0.5;

                color2 *= 1 - Depth;

                // color
                color = max(color, color2);

                return _ZBufferParams.w;
            }

            ENDHLSL
        }
    }
    FallBack "Diffuse"
}