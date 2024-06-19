Shader "Hidden/Custom/SobelSharpen" {
    Properties {
        _MainTex ("Main Texture", 2D) = "white" { }
        _Offset ("Offset value", int) = 0
    }
    SubShader {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass {
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_MainTex);
            TEXTURE2D_X_FLOAT(_CameraDepthAttachment);
            SAMPLER(sampler_CameraDepthAttachment);
            SAMPLER(sampler_MainTex);

            float _Intensity;
            int _Offset;

            struct Attributes {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                uint vertexID : SV_VertexID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float2 texcoord : TEXCOORD2;
                float4 positionSS : TEXCOORD3;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes input) {
                Varyings output = (Varyings)0;
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.vertex = vertexInput.positionCS;
                output.uv = input.uv;

                // float4 positionCS = TransformObjectToHClip(input.positionOS);
                output.positionSS = ComputeScreenPos(vertexInput.positionCS);
                // output.texcoord = TransformStereoScreenSpaceTex();

                return output;
            }

            float2 offsetResult(float2 scrPos, int _OffsetX, int _OffsetY) {
                scrPos.x = scrPos.x + ((_OffsetX) / _ScreenParams.x);
                scrPos.y = scrPos.y + ((_OffsetY) / _ScreenParams.y);
                return scrPos;
            }

            float4 frag(Varyings input) : SV_Target {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float2 scrPos = input.positionSS.xy / input.positionSS.w;

                float4 c0 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, offsetResult(scrPos, -_Offset, _Offset));
                float4 c1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, offsetResult(scrPos, 0, _Offset));
                float4 c2 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, offsetResult(scrPos, _Offset, _Offset));

                float4 c3 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, offsetResult(scrPos, _Offset, 0));
                float4 c4 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, offsetResult(scrPos, 0, 0));
                float4 c5 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, offsetResult(scrPos, 0, _Offset));

                float4 c6 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, offsetResult(scrPos, _Offset, -_Offset));
                float4 c7 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, offsetResult(scrPos, 0, -_Offset));
                float4 c8 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, offsetResult(scrPos, _Offset, -_Offset));
                // float4 c9 = SAMPLE_TEXTURE2D(_CameraDepthAttachment, sampler_CameraDepthAttachment, scrPos);

                // SampleInput(_CameraDepthAttachment, sampler_CameraDepthAttachment, scrPos);

                float4 sobelX = ((-c0 - c1 * 2 - c2) + c6 + c7 * 2 + c8);
                float4 sobelY = (-c0 - c3 * 2 - c6 + c2 + c5 * 2 + c8);

                sobelX *= sobelX;
                sobelY *= sobelY;

                float4 sobel = sqrt(sobelX + sobelY);

                return sobel.r ;
            }

            ENDHLSL
        }
    }
    FallBack "Diffuse"
}