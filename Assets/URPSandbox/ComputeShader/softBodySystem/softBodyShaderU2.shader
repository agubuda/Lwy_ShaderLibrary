Shader "ComputeShader/softBodyShaderU2"
{
    Properties
    {
        //_Smooth ("smooth", float) = 1.0
        _Spring ("Sping", float) = 1.0
        _Damper ("_Damper", float) = 5.0
        _MoveScale ("_MoveScale", float) = 1.0
        _SoftBodyMusk ("_SoftBodyMusk", 2D) = "white" { }
        _registerField("_registerField", float) = 1.0

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
        _FrenelPower ("Frenel Power", float) = 1
        // _SoftDepth ("soft depth", float) = 1

    }
    SubShader
    {
        Tags { "Queue" = "Geometry" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            ZWrite On
            Cull back

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
                float4 _SoftBodyMusk_ST;
                half4 _Remap;
                // half3 _LightDebug;
                float _NormalScale;
                float _FrenelPower;
                // float _SoftDepth;
                float _Damper, _Spring, _Gravity, _MoveScale/*, _Smooth*/;
                int _registerField;

            CBUFFER_END



            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
                float4 tangent : TANGENT;
                uint id : SV_VertexID;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float3 worldTangent : TEXCOORD3;
                float3 worlBbitangent : TEXCOORD4;
                float4 screenPos : TEXCOORD5;
                half fogFactor : TEXCOORD6;
                uint id : TEXCOORD7;
            };

            struct MoverData
            {
                float3 posWS;
                float3 dPosWS;
                float3 velocityWS;
                float time;
            };

            RWStructuredBuffer<MoverData> _Buffer : register(u2);

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            
            TEXTURE2D(_SoftBodyMusk);
            SAMPLER(sampler_SoftBodyMusk);


            v2f vert(a2v input)
            {
                MoverData data = _Buffer[input.id];

                float time = _Time.y;

                v2f o;

                // VertexPositionInputs vertexInput = GetVertexPositionInputs(input.vertex.xyz);

                // o.worldNormal = TransformObjectToWorldNormal(input.normal);
                o.positionWS = TransformObjectToWorld(input.vertex.xyz);

                // o.uv = TRANSFORM_TEX(input.texcoord, _RampMap);
                o.uv = TRANSFORM_TEX(input.texcoord, _MainTex);
                o.uv = TRANSFORM_TEX(input.texcoord, _NormalMap);
                o.uv = TRANSFORM_TEX(input.texcoord, _SoftBodyMusk);
                o.worldNormal = TransformObjectToWorldNormal(input.normal, true);


                float4 softBodyMusk = SAMPLE_TEXTURE2D_LOD(_SoftBodyMusk, sampler_SoftBodyMusk, o.uv, 0);

                if (abs(time - data.time) > 1e-3)
                {
                    float3 targetPosWS = TransformObjectToWorld(input.vertex.xyz);
                    float3 dPosWS = targetPosWS - data.posWS;
                    float3 forceWS = _Spring * dPosWS - data.velocityWS * _Damper ;

                    float dt = 1.0 / 60;
                    data.velocityWS += forceWS * dt;
                    data.posWS += data.velocityWS * dt;
                    data.dPosWS = (data.posWS - targetPosWS) * _MoveScale;

                    float move = length(data.dPosWS);
                    data.dPosWS = min(move, 1.0) / max(move, 0.01) * data.dPosWS;
                    // if(move < 0.001){data.dPosWS = 0;}

                    o.positionWS.x += data.dPosWS.x * softBodyMusk;
                    // o.positionWS.y *= abs(1+data.dPosWS.x * softBodyMusk);
                    // o.positionWS.z *= abs(1+data.dPosWS.x * softBodyMusk);

                    o.positionWS.y += data.dPosWS.y * softBodyMusk;
                    o.positionWS.z += data.dPosWS.z * softBodyMusk;

                    data.time = time;

                    _Buffer[input.id] = data;
                }

                // o.pos = TransformObjectToHClip(input.vertex.xyz);
                //弹性影响过的模型的顶点位置，从世界空间转换为裁剪空间
                o.pos = TransformWorldToHClip(o.positionWS);

                o.worldTangent = TransformObjectToWorldDir(input.tangent.xyz);
                


                //for depth tex
                o.screenPos = ComputeScreenPos(o.pos);

                //fog
                o.fogFactor = ComputeFogFactor(o.pos.z);

                return (o);
            };



            float4 frag(v2f inside) : SV_TARGET
            {
                
                //diffuse color
                float4 diffuseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, inside.uv);
                clip(diffuseColor.a - _Cutoff);

                //initialize lighting struct
                Light mlight = GetMainLight();
                // half3 lightDebug = {_LightDebug.xyz};
                half4 lightColor = half4(mlight.color, 0);

                //normal map
                float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, inside.uv);
                float3 bump = SafeNormalize(UnpackNormalScale(normalMap, _NormalScale));
                inside.worldNormal = TransformTangentToWorld(bump, half3x3(inside.worldTangent, inside.worlBbitangent, inside.worldNormal));

                //lambert
                float Lambert = dot(mlight.direction, inside.worldNormal) * 0.5 + _Darkness;

                //Mix with fog
                float3 diffuseColorFog;
                diffuseColorFog = MixFog(diffuseColor.rgb, inside.fogFactor);

                return diffuseColor * Lambert ;
            };



            ENDHLSL
        }
    }
}

