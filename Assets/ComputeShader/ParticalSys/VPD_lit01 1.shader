Shader "ComputeShader/ParticleSys" {
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

            struct v2f {
                float4 vertex : POSITION;
                float4 color : COLOR0;
            };

            struct particalData {
                float3 pos;
                float4 color;
            };

            StructuredBuffer<particalData> _particleDataBuffer;

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            v2f vert(uint id : SV_VERTEXID) {
                v2f o;

                o.vertex = TransformObjectToHClip(float4(_particleDataBuffer[id].pos, 0));
                o.color = _particleDataBuffer[id].color;

                return o;
            };

            float4 frag(v2f inside) : SV_TARGET {
                return inside.color;
            };

            ENDHLSL
        }
    }
}