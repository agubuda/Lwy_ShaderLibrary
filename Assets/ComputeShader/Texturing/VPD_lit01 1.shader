Shader "ComputeShader/Texturing" {
    Properties {
        _Spring ("Sping", float) = 1.0
        _Damper ("_Damper", float) = 5.0
        _MoveScale ("_MoveScale", float) = 1.0
        // _Gravity ("_Gravity", float) = 1.0
        [Space(20)]
        _MainTex ("Texture", 2D) = "white" { }
        _NormalMap ("Normal Map", 2D) = "white" { }
        // _RampMap ("Ramp Map", 2D) = "white" { }
        _Remap ("Remap value", vector) = (1, -1, -1, 1)
        _BaseColor ("Color", Color) = (2, 1, 1, 1)
        _SpecColor ("Specular color", Color) = (1, 1, 1, 1)
        _SpecPower ("Specular power", float) = 1
        _Darkness ("Darkness", range(0, 1)) = 0.5
        _Glossness ("Glossness", float) = 8
        _NormalScale ("Normal scale", float) = 1
        _Cutoff ("Alpha Clip threshold", float) = 0.5
        // _LightDebug ("light Debug", vector) = (0,0,0,0)
        _NoiseMap ("Hair Noise", 2D) = "white" { }
        _AnisotropyColor ("anistropy color", color) = (1, 1, 1, 1)
        _AnisotropyPower ("anistropy power", float) = 1
        _NoisePower ("Noise Power", float) = 0.2
        _FrenelPower ("Frenel Power", float) = 1
        // _SoftDepth ("soft depth", float) = 1

    }
    SubShader {
        Tags { "Queue" = "Geometry" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }

        Pass {
            ZWrite On
            Cull off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma target 5.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            // #include "UnityCG.cginc"

            CBUFFER_START(UnityPerMaterial)
            // half4 _MainTex;
            half4 _BaseColor;
            half4 _AnisotropyColor;
            float _Darkness;
            float _Glossness;
            float _Cutoff;
            half4 _SpecColor;
            float _SpecPower;
            // half4 _RampMap;
            // float4 _RampMap_ST;
            float4 _MainTex_ST;
            float4 _NormalMap_ST;
            float4 _NoiseMap_ST;
            half4 _Remap;
            // half3 _LightDebug;
            float _NormalScale;
            float _NoisePower;
            float _AnisotropyPower;
            float _FrenelPower;
            // float _SoftDepth;
            float _Damper, _Spring, _Gravity, _MoveScale;

            CBUFFER_END

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
                float4 tangent : TANGENT;
                uint id : SV_VertexID;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float3 worldTangent : TEXCOORD3;
                float3 worlBbitangent : TEXCOORD4;
                float4 screenPos : TEXCOORD5;
                half fogFactor : TEXCOORD6;
                uint id : TEXCOORD7;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            // TEXTURE2D(_RampMap);
            // SAMPLER(sampler_RampMap);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            TEXTURE2D(_NoiseMap);
            SAMPLER(sampler_NoiseMap);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            v2f vert(a2v input) {

                v2f o;

                // VertexPositionInputs vertexInput = GetVertexPositionInputs(input.vertex.xyz);

                o.pos = TransformObjectToHClip(input.vertex.xyz);

                o.worldNormal = TransformObjectToWorldNormal(input.normal);
                o.worldPos = TransformObjectToWorld(input.vertex.xyz);
                o.worldTangent = TransformObjectToWorldDir(input.tangent.xyz);

                //cul bitangent
                o.worlBbitangent = normalize(cross(o.worldNormal, o.worldTangent) * input.tangent.w);

                // o.uv = TRANSFORM_TEX(input.texcoord, _RampMap);
                o.uv = TRANSFORM_TEX(input.texcoord, _MainTex);
                o.uv = TRANSFORM_TEX(input.texcoord, _NormalMap);

                //for depth tex
                o.screenPos = ComputeScreenPos(o.pos);

                //fog
                o.fogFactor = ComputeFogFactor(o.pos.z);

                return o;
            };

            float4 frag(v2f inside) : SV_TARGET {

                //diffuse color
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, inside.uv);
                // clip(col.a - _Cutoff);

                // //initialize lighting struct
                // Light mlight = GetMainLight();
                // // half3 lightDebug = {_LightDebug.xyz};
                // half4 lightColor = half4(mlight.color, 0);

                // //normal map
                // float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, inside.uv);
                // float3 bump = UnpackNormalScale(normalMap, _NormalScale);
                // inside.worldNormal = TransformTangentToWorld(bump, half3x3(inside.worldTangent, inside.worlBbitangent, inside.worldNormal));

                // //lambert
                // float Lambert = dot(mlight.direction, inside.worldNormal) * 0.5 + _Darkness;

                // //Phong

                // half3 lightDir = normalize(saturate(mlight.direction));
                // half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - inside.worldPos);
                // half3 reflectDir = normalize(reflect(lightDir, inside.worldNormal));

                // float phong = pow(saturate(dot(viewDir, -reflectDir)), _Glossness);

                // half4 phongSpecular = phong * _SpecColor * lightColor * _SpecPower;

                // if(lightDir = 0){return 0;}
                return col;
                // return phongSpecular *(1-LinearDepth);

            };

            ENDHLSL
        }
    }
}