//processing, not finished.

Shader "LwyShaders/BlinnPhongNDF"
{
    Properties
    {
        _BaseMap ("Texture", 2D) = "white" { }
        _BaseColor ("BaseColor", color) = (1.0, 1.0, 1.0, 1.0)
        _SpecularPower ("Specular power", Range(1, 10)) = 8
        _Metallic ("Metallic", Range(0, 1)) = 1
        _Roughness ("_Roughness", Range(0.01, 1)) = 0
        
        _NormalMap ("Normal map", 2D) = "bump" { }
        _NormalScale ("Normal scale", float) = 1

        [Space(20)]
        _cubeMap ("cube map", Cube) = "_Skybox" { }
    }
    SubShader
    {
        Tags { "Queue" = "Geometry" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }

        pass
        {
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Name "BlinnPhong testing"

            ZWrite On
            Cull back

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"

            #pragma target 4.5

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fog

            #pragma multi_compile  _MAIN_LIGHT_SHADOWS
            #pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile  _SHADOWS_SOFT
            // #pragma shader_feature _ENABLEENVIROMENTLIGHT

            CBUFFER_START(UnityPerMaterial)

                float4 _BaseMap_ST;
                float4 _MainTex_ST;
                float4 _NormalMap_ST;
                float4 _BaseColor;
                float _Metallic, _Roughness;
                float _SpecularPower;
                float _NormalScale;

            CBUFFER_END

            
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
            // TEXTURE2D_X_FLOAT(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
            TEXTURECUBE(_cubeMap);SAMPLER(sampler_cubeMap);

            
            // TEXTURECUBE(unity_SpecCube0);
            // SAMPLER(samplerunity_SpecCube0);
            
            struct a2v
            {

                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 texcoord : TEXCOORD0;
                float4 tangent : TANGENT;
                // float2 secondTexcoord : TEXCOORD1;

            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 bitangentWS : TEXCOORD4;
                float2 uv : TEXCOORD1;
                float3 tangentWS : TEXCOORD2;
                float3 normalWS : TEXCOORD3;
                float3 normalOS : TEXCOORD5;
                // float4 scrPos : TEXCOORD6;
                float4 shadowCoord : TEXCOORD7;
                float2 uv2 : TEXCOORD8;
            };

            float D_GGX_TR(half3 N, half3 H, float roughness)
            {
                half a2 = roughness * roughness;
                float NdotH = max(dot(H, N), 0.0001);
                float NdotH2 = NdotH * NdotH;

                float nom = a2;
                float denom = (NdotH2 * (a2 - 1.0) + 1.0);
                denom = PI * denom * denom;
                return nom / denom;
            }

            float GeometrySchlickGGX(float NdotV, float k)
            {
                float nom = NdotV;
                float denom = NdotV * (1.0 - k) + k;

                return nom / denom;
            }

            float GeometrySmith(float3 N, float3 V, float3 L, float roughness)
            {
                float k = pow(_Roughness + 1, 2) * rcp(8);

                float NdotV = max(dot(N, V), 0.0);
                float NdotL = max(dot(N, L), 0.0);
                float ggx1 = GeometrySchlickGGX(NdotV, k);
                float ggx2 = GeometrySchlickGGX(NdotL, k);

                return ggx1 * ggx2;
            }


            float BlinnPhong(half3 h, half3 worldNormal, half n)
            {
                float BlinnPhong = pow(max(dot(h, worldNormal), 0.0001), 5);
                BlinnPhong = pow(BlinnPhong, n) * ((n + 1) / (2 * 3.1415926535));
                // BlinnPhong = (( _Roughness + 2) * ( _Roughness +4)) /
                //               (8 * 3.1415926535 * (pow(2,-_Roughness / 2) + _Roughness))
                //               * BlinnPhong;
                
                return BlinnPhong;
            }

            float Phong(half3 lightDir, half3 viewDir, half3 worldNormal)
            {
                half3 reflectL = reflect(normalize(lightDir), normalize(worldNormal));
                float phong = pow(saturate(dot(normalize(viewDir), -reflectL)), _SpecularPower);
                phong *= (_Metallic + 8) * rcp(25.132741228);
                return phong;
            }

            float Lambert(half3 lightDir, half3 worldNormal)
            {
                float lambert = max(dot(normalize(lightDir), normalize(worldNormal)), 0.0001);
                
                return lambert;
            }

            float3 Fresnel(half3 n, half3 viewdir, half3 f0)
            {
                float3 fresnel = f0 + (1.0 - f0) * pow((1.0 - dot(n, viewdir)), 5.0);

                return fresnel;
            }
            float3 FresnelRoughness(half3 n, half3 viewdir, half3 f0 , float roughness)
            {
                float3 fresnel = f0 + (max(float3(1.0,1.0,1.0) - roughness , f0)) * pow((1.0 - dot(n, viewdir)), 5.0);

                return fresnel;
            }

            float FV(half3 lightDir, half3 viewDir, half3 worldNormal)
            {
                half3 h = normalize(lightDir + viewDir);
                float fv = pow(dot(normalize(lightDir), h), -3) / 4;

                return fv;
            }

            v2f vert(a2v input)
            {
                v2f o;

                o.positionCS = TransformObjectToHClip(input.positionOS);
                o.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(input.normalOS.xyz, true);
                o.tangentWS = TransformObjectToWorldDir(input.tangent.xyz);
                o.bitangentWS = normalize(cross(o.normalWS.xyz, o.tangentWS.xyz) * input.tangent.w);
                // o.positionVS = TransformWorldToView(TransformObjectToWorld(input.positionOS.xyz));
                // normalVS = TransformWorldToViewDir(normalWS, true);

                // //NDC
                // float4 ndc = input.positionOS * 0.5f;
                // o.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
                // o.positionNDC.zw = TransformObjectToHClip(input.positionOS).zw;

                // //scr pos
                // o.scrPos = ComputeScreenPos(o.positionCS);

                //recive shadow
                o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
                o.normalOS = normalize(input.normalOS);
                
                o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                o.uv2 = TRANSFORM_TEX(input.texcoord, _NormalMap);
                // o.uv = TRANSFORM_TEX(input.texcoord, _NormalMap);
                
                return o;
            }

            float4 frag(v2f input) : SV_TARGET
            {
                _Metallic = max(0.04, _Metallic);

                half3 color = half3(0, 0, 0);
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
                float3 positionVS = TransformWorldToView(input.positionWS);
                float3 normalVS = TransformWorldToViewDir(normalize(input.normalWS), true);

                // //initialize main light
                // Light MainLight = GetMainLight(input.shadowCoord);
                // float3 LightDir = normalize(half3(MainLight.direction));
                // float4 LightColor = float4(MainLight.color, 1);

                //albedo
                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 diffuse = _BaseColor * albedo;

                //normal map
                float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv2);
                float3 bump = UnpackNormalScale(normalMap, _NormalScale);
                // input.normalWS = TransformTangentToWorld(bump, float3x3(input.bitangentWS,input.tangentWS, input.normalWS  ));
                float3x3 TBN = {
                    input.bitangentWS, input.tangentWS, input.normalWS
                };
                bump.z = pow(1 - pow(bump.x, 2) - pow(bump.y, 2), 0.5);
                input.normalWS = mul(bump, TBN);

                // float3 derectDiffColor = kd * diffuse * LightColor * Lambert;

                //GI cubemap and mip cul
                half MIP = _Roughness * (1.7 - 0.7 * _Roughness) * UNITY_SPECCUBE_LOD_STEPS;
                float3 reflectDirWS = reflect(-viewDir, input.normalWS);
                half3 cubeMap = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectDirWS, MIP);

                //puntuation lights
                uint pixelLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0; lightIndex < pixelLightCount; ++lightIndex)
                {
                    float4 lightPositionWS = _AdditionalLightsPosition[lightIndex];
                    half distanceAttenuation = _AdditionalLightsAttenuation[lightIndex];
                    half3 lightColor = _AdditionalLightsColor[lightIndex].rgb;

                    //culculate attenuation
                    float3 lightVector = lightPositionWS.xyz - input.positionWS * lightPositionWS.w;
                    // float3 lightVector = lightPositionWS;
                    // float distanceSqr = max(dot(lightVector, lightVector), 0.1);
                    float distanceSqr = max(dot(lightVector, lightVector), 0.5);

                    float lightAtten = rcp(distanceSqr);

                    half factor = half(distanceSqr * distanceAttenuation);
                    half smoothFactor = saturate(half(1.0) - factor * factor);
                    smoothFactor *= smoothFactor;

                    float3 lightDirection = half3(lightVector * rsqrt(distanceSqr));

                    float3 H = normalize(lightDirection + viewDir);

                    //env
                    float kIndirectLight = pow(_Roughness * _Roughness + 1, 2) * rcp(8.0);
                    float kInIBL = pow(_Roughness * _Roughness, 2) * rcp(8.0);

                    // //FV
                    // float fv = FV(lightDirection, viewDir, input.normalWS);

                    //G
                    float G = GeometrySmith(input.normalWS, viewDir, lightDirection, _Roughness);

                    //S
                    // float ks = BlinnPhong(H, input.normalWS, _Roughness);
                    //D_GGX_TR
                    float ks = D_GGX_TR(input.normalWS, H, _Roughness);
                    ks = ks * (lightAtten * smoothFactor);
                    half3 S = ks * lightColor ;

                    //F
                    half3 f0 = half3(0.04, 0.04, 0.04);
                    f0 = lerp(f0, albedo, _Metallic);
                    float3 F = Fresnel(input.normalWS, viewDir, f0);

                    //indirect
                    float3 ambient_contrib = max(0, SampleSH(input.positionWS)) ;
                    float3 AmbientF = FresnelRoughness(input.normalWS, viewDir, f0, _Roughness);
                    float3 AmbientD = float3(1.0,1.0,1.0) - AmbientF;
                    ambient_contrib *= AmbientD;

                    diffuse *= ambient_contrib;

                    //D
                    float lambert = Lambert(lightDirection, input.normalWS) * lightAtten * smoothFactor;
                    float3 kd = float3(1.0, 1.0, 1.0) - F;
                    kd *= (1.0 - _Metallic);
                    // ambient_contrib *=kd;
                    float3 D = diffuse * kd  * lightColor ;


                    // half3 ambient = 0.03 * diffuse;

                    // color += (S * G * fresnel + kd );
                    // color += (D + ambient_contrib + S * F * G) * lambert;
                    color +=  ambient_contrib;
                }
                return half4((color), albedo.a) ;
            }

            ENDHLSL
        }
        
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

            CBUFFER_START(UnityPerMaterial)

                float4 _BaseMap_ST;
                float4 _MainTex_ST;
                float4 _BaseColor;
                float _Darkness;
                float _Metallic;
                float _SpecularPower;

            CBUFFER_END

            // CBUFFER_START(UnityPerMaterial)
            //     // half _Surface;

            //     half4 _BaseColor;
            //     // half4 _AnisotropyColor;
            //     // half _Darkness;
            //     // half _Glossness;
            //     // half _Cutoff;
            //     // half4 _SpecColor;
            //     // half _SpecPower;
            
            //     half4 _BaseMap_ST;
            //     // half4 _NormalMap_ST;
            //     // half4 _NoiseMap_ST;
            //     // half4 _AOMap_ST;
            
            //     // half _NormalScale;
            //     // half _NoisePower;
            //     // half _AnisotropyPower;
            //     // half _FrenelPower;
            //     // half4 _RimColor;
            //     // half _Exponent;
            //     // half _FrenelLightness;
            //     // half _AOContrast;

            //     // float4 _DetailAlbedoMap_ST;
            //     // half4 _EmissionColor;
            //     // half _Roughness;
            //     // half _Metallic;
            //     // half _BumpScale;
            //     // half _Parallax;
            //     // half _OcclusionStrength;
            //     // half _ClearCoatMask;
            //     // half _ClearCoatSmoothness;
            //     // half _DetailAlbedoMapScale;
            //     // half _DetailNormalMapScale;
            // CBUFFER_END

            // -------------------------------------
            // Material Keywords
            // #pragma shader_feature_local_fragment _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            // #pragma multi_compile_instancing
            // #pragma multi_compile _ DOTS_INSTANCING_ON

            // #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
