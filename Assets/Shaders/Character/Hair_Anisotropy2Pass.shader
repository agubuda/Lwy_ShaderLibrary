Shader "sfx/Character/Hair_Anisotropy2Pass" {
    Properties {
        _MainColor ("Main Color", Color) = (1, 1, 1, 1)
        _MainTex ("Diffuse (RGB) Alpha (A)", 2D) = "white" { }

        _NormalTex ("Normal Map", 2D) = "Black" { }
        _NormalScale ("Normal Scale", Range(0, 10)) = 1
        _Specular ("Specular Amount", Range(0, 5)) = 1.0
        _SpecularColor ("Specular Color1", Color) = (1, 1, 1, 1)
        _SpecularColor2 ("Specular Color2", Color) = (0.5, 0.5, 0.5, 1)
        _SpecularMultiplier ("Specular Power1", float) = 100.0
        _SpecularMultiplier2 ("Secondary Specular Power", float) = 100.0

        _PrimaryShift ("Specular Primary Shift", float) = 0.0
        _SecondaryShift ("Specular Secondary Shift", float) = .7
        _AnisoDir ("SpecShift(G),Spec Mask (B)", 2D) = "white" { }
        _Cutoff ("Alpha Cut-Off Threshold", float) = 0.5
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull Mode", Float) = 2
    }

    SubShader {
        //在半透明之前渲染
        Tags { "Queue" = "Transparent-10" "IgnoreProjector" = "True" "RenderType" = "TransparentCutout" "RenderPipeline" = "UniversalPipeline" }

        Pass {
            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SpaceTransforms.hlsl"
            #pragma target 3.0

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_AnisoDir);
            SAMPLER(sampler_AnisoDir);
            TEXTURE2D(_NormalTex);
            SAMPLER(sampler_NormalTex);

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST, _AnisoDir_ST, _NormalTex_ST;
            half _SpecularMultiplier, _PrimaryShift, _Specular, _SecondaryShift, _SpecularMultiplier2;
            half4 _SpecularColor, _MainColor, _SpecularColor2;
            half _Cutoff;
            half _NormalScale;
            CBUFFER_END

            struct appdata_full {
                float4 vertex : POSITION;
                float4 tangent : TANGENT;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
                float4 texcoord1 : TEXCOORD1;
                float4 texcoord2 : TEXCOORD2;
                float4 texcoord3 : TEXCOORD3;
                half4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f {

                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float4 worldNormal : TEXCOORD2;
                float4 vertex : SV_POSITION;
            };

            v2f vert(appdata_full v) {
                v2f o = (v2f)0;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);

                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNormal = float4(TransformObjectToWorldNormal(v.normal), 0);
                return o;
            }

            half4 frag(v2f i) : SV_Target {

                // Light mlight =GetMainlight();

                half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                clip(albedo.a - _Cutoff);
                half4 finalColor = half4(0, 0, 0, albedo.a);
                finalColor.rgb += (albedo.rgb * _MainColor.rgb) * _MainLightColor.rgb;
                return finalColor;
            }
            ENDHLSL
        }

        Pass {
            Tags { "LightMode" = "SRPDefaultUnlit" }
            ZWrite Off
            Cull [_Cull]
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #pragma target 3.0

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_AnisoDir);
            SAMPLER(sampler_AnisoDir);
            TEXTURE2D(_NormalTex);
            SAMPLER(sampler_NormalTex);

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST, _AnisoDir_ST, _NormalTex_ST;
            half _SpecularMultiplier, _PrimaryShift, _Specular, _SecondaryShift, _SpecularMultiplier2;
            half4 _SpecularColor, _MainColor, _SpecularColor2;
            half _Cutoff;
            half _NormalScale;
            CBUFFER_END

            struct appdata_full {
                float4 vertex : POSITION;
                float4 tangent : TANGENT;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
                float4 texcoord1 : TEXCOORD1;
                float4 texcoord2 : TEXCOORD2;
                float4 texcoord3 : TEXCOORD3;
                half4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f {
                float4 uv : TEXCOORD0;
                float4 TtoW0 : TEXCOORD1;
                float4 TtoW1 : TEXCOORD2;
                float4 TtoW2 : TEXCOORD3;
                float4 vertex : SV_POSITION;
            };

            //获取头发高光
            half StrandSpecular(half3 T, half3 V, half3 L, half exponent) {
                half3 H = normalize(L + V);
                half dotTH = dot(T, H);
                half sinTH = sqrt(1 - dotTH * dotTH);
                half dirAtten = smoothstep(-1, 0, dotTH);
                return dirAtten * pow(sinTH, exponent);
            }

            inline float3 UnityObjectToWorldDir(in float3 dir) {
                return normalize(mul((float3x3)unity_ObjectToWorld, dir));
            }

            inline float3 UnityWorldSpaceViewDir(in float3 worldPos) {
                return _WorldSpaceCameraPos.xyz - worldPos;
            }

            inline float3 UnityWorldSpaceLightDir(in float3 worldPos) {
                #ifndef USING_LIGHT_MULTI_COMPILE
                    return _MainLightPosition.xyz - worldPos * _MainLightPosition.w;
                #else
                    #ifndef USING_DIRECTIONAL_LIGHT
                        return _WorldSpaceLightPos0.xyz - worldPos;
                    #else
                        return _WorldSpaceLightPos0.xyz;
                    #endif
                #endif
            }

            half3 UnpackScaleNormal(half4 packednormal, half bumpScale) {
                half3 normal;
                normal.xy = (packednormal.wy * 2 - 1);
                #if (SHADER_TARGET >= 30)
                    // SM2.0: instruction count limitation
                    // SM2.0: normal scaler is not supported
                    normal.xy *= bumpScale;
                #endif
                normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
                return normal;

                /*#if defined(UNITY_NO_DXT5nm)
                    return packednormal.xyz * 2 - 1;
                #else
                    half3 normal;
                    normal.xy = (packednormal.wy * 2 - 1);
                    #if (SHADER_TARGET >= 30)
                        // SM2.0: instruction count limitation
                        // SM2.0: normal scaler is not supported
                        normal.xy *= bumpScale;
                    #endif
                    normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
                    return normal;
                #endif
                */
            }

            v2f vert(appdata_full v) {
                v2f o = (v2f)0;

                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.texcoord, _NormalTex);

                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                half3 worldNormal = TransformObjectToWorldNormal(v.normal);
                half3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                half3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;

                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);

                return o;
            }

            half4 frag(v2f i) : SV_Target {
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy);
                half3 diffuseColor = albedo.rgb * _MainColor.rgb;

                //法线相关
                half3 bump = UnpackScaleNormal(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.uv.zw), _NormalScale);
                half3 worldNormal = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));
                float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
                half3 worldTangent = normalize(half3(i.TtoW0.x, i.TtoW1.x, i.TtoW2.x));
                half3 worldBinormal = normalize(half3(i.TtoW0.y, i.TtoW1.y, i.TtoW2.y));

                half3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
                half3 worldLightDir = normalize(UnityWorldSpaceLightDir(worldPos));

                half3 spec = SAMPLE_TEXTURE2D(_AnisoDir, sampler_AnisoDir, i.uv.xy).rgb;
                //计算切线方向的偏移度
                half shiftTex = spec.g;
                half3 t1 = ShiftTangent(worldBinormal, worldNormal, _PrimaryShift + shiftTex);
                half3 t2 = ShiftTangent(worldBinormal, worldNormal, _SecondaryShift + shiftTex);
                //计算高光强度
                half4 spec1 = StrandSpecular(t1, worldViewDir, worldLightDir, _SpecularMultiplier) * _SpecularColor;
                half4 spec2 = StrandSpecular(t2, worldViewDir, worldLightDir, _SpecularMultiplier2) * _SpecularColor2;

                half4 finalColor = 0;
                finalColor.rgb = diffuseColor + spec1.rgb * _Specular;//第一层高光
                finalColor.rgb += spec2.rgb * _SpecularColor2.rgb * spec.b * _Specular;//第二层高光，spec.b用于添加噪点
                finalColor.rgb *= _MainLightColor.rgb;//受灯光影响
                finalColor.a = albedo.a;

                return finalColor;
            };
            ENDHLSL
        }
    }

    FallBack "Universal Render Pipeline/Simple Lit"
}