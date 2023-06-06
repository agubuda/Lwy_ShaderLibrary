//processing, not finished.

Shader "LwyShaders/BlinnPhongNDF"
{
    Properties
    {
        _BaseMap ("Texture", 2D) = "white" { }
        _BaseColor ("BaseColor", color) = (1.0, 1.0, 1.0, 1.0)
        _SpecularPower ("Specular power", Range(1, 10)) = 8
        _Metalic ("Metalic", Range(0, 1)) = 1
        _Roughness ("_Roughness", Range(0, 1)) = 0
        
        _NormalMap ("Normal map", 2D) = "bump" { }
        _NormalScale ("Normal scale", float) = 1

        [Space(20)]
        _Cubemap ("cube map", Cube) = "_Skybox" { }
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"

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
                float _Metalic, _Roughness;
                float _SpecularPower;
                float _NormalScale;

            CBUFFER_END

            
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
            // TEXTURE2D_X_FLOAT(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
            TEXTURECUBE(_Cubemap);SAMPLER(sampler_Cubemap);

            
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

            float GeometrySchlickGGX(float NdotV, float k)
            {
                float SchGGXNom = NdotV;
                float SchGGXDenom = NdotV * (1 - k) + k;
                return SchGGXNom / SchGGXDenom;
            }

            float GeometrySmith(float3 N, float3 V, float3 L, float k)
            {
                float NdotV = max(dot(N, V), 0.0);
                float NdotL = max(dot(N, L), 0.0);
                float ggx1 = GeometrySchlickGGX(NdotV, k); // 视线方向的几何遮挡
                float ggx2 = GeometrySchlickGGX(NdotL, k); // 光线方向的几何阴影
                
                return ggx1 * ggx2;
            }

            float BlinnPhong(half3 lightDir, half3 viewDir, half3 worldNormal)
            {
                half3 h = normalize(lightDir) + normalize(viewDir);
                float BlinnPhong = pow(max(dot(h, worldNormal), 0.0), _Roughness);
                // BlinnPhong = clamp(0,1,BlinnPhong);
                BlinnPhong = BlinnPhong * ((_Roughness + 1) / (2 * 3.1415926535));
                
                return BlinnPhong;
            }

            float Phong(half3 lightDir, half3 viewDir, half3 worldNormal)
            {
                half3 reflectL = reflect(normalize(lightDir), normalize(worldNormal));
                float phong = pow(saturate(dot(normalize(viewDir), -reflectL)), _SpecularPower);
                phong *= (_Metalic + 8) * rcp(25.132741228);
                return phong;
            }

            float Lambert(half3 lightDir, half3 worldNormal)
            {
                float lambert = max(dot(normalize(lightDir), normalize(worldNormal)), 0.0001);
                // lambert *=  rcp(PI);
                return lambert;
            }

            float3 Fresnel(half3 lightDir, half3 viewDir, half3 worldNormal, half3 f0)
            {
                // float _roughness = 1 - _Roughness;
                half3 h = normalize(lightDir + viewDir);
                float3 fresnel = f0 + (1.0 - f0) * pow((1.0 - dot(h, normalize(worldNormal))), 5.0);

                return fresnel;
            }

            float FV(half3 lightDir, half3 viewDir, half3 worldNormal)
            {
                half3 h = normalize(lightDir + viewDir);
                float fv = pow(dot(h, viewDir), -3) * rcp(4);

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
                _Metalic = max(0.04, _Metalic);
                half3 color = half3(0, 0, 0);
                float3 viewDir = _WorldSpaceCameraPos.xyz - input.positionWS;
                float3 positionVS = TransformWorldToView(input.positionWS);
                float3 normalVS = TransformWorldToViewDir(normalize(input.normalWS), true);

                //initialize main light
                Light MainLight = GetMainLight(input.shadowCoord);
                float3 LightDir = normalize(half3(MainLight.direction));
                float4 LightColor = float4(MainLight.color, 1);

                //albedo
                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 diffuse = _BaseColor * albedo;

                //normal map
                float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv2);
                float3 bump = UnpackNormalScale(normalMap, _NormalScale);
                // input.normalWS = TransformTangentToWorld(bump, float3x3(input.bitangentWS,input.tangentWS, input.normalWS  ));
                float3x3 TBN = {input.bitangentWS, input.tangentWS, input.normalWS};
                bump.z = pow(1 - pow(bump.x, 2) - pow(bump.y, 2), 0.5);
                input.normalWS = mul(bump, TBN);

                // float3 derectDiffColor = kd * diffuse * LightColor * Lambert;

                //GI cubemap and mip cul
                half MIP = _Roughness * (1.7 - 0.7 * _Roughness) * 10;
                float3 reflectDirWS = reflect(-viewDir, input.normalWS);
                // float4 Cubemap = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectDirWS, 10);
                float4 Cubemap = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectDirWS, MIP);

                //puntuation lights
                float enviValue = 1.0;
                uint pixelLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0; lightIndex < pixelLightCount; ++lightIndex)
                {
                    Light AddtionalLight = GetAdditionalLight(lightIndex, input.positionWS);

                    float4 lightPositionWS = _AdditionalLightsPosition[lightIndex];
                    half distanceAttenuation = _AdditionalLightsAttenuation[lightIndex];

                    //culculate attenuation
                    float3 lightVector = lightPositionWS.xyz - input.positionWS * lightPositionWS.w;
                    float distanceSqr = max(dot(lightVector, lightVector), 1.0);

                    float lightAtten = rcp(distanceSqr);

                    half factor = half(distanceSqr * distanceAttenuation);
                    half smoothFactor = saturate(half(1.0) - factor * factor);
                    smoothFactor *= smoothFactor;

                    AddtionalLight.direction = half3(lightVector * rsqrt(distanceSqr));

                    //FV
                    float fv = FV(AddtionalLight.direction, viewDir, input.normalWS);

                    //D
                    float lambert = Lambert(AddtionalLight.direction,input.normalWS);
                    lambert *= lightAtten * smoothFactor;
                    float3 kd = diffuse * lambert  / PI * AddtionalLight.color;

                    //ks
                    float ks = BlinnPhong(AddtionalLight.direction, viewDir, input.normalWS);
                    ks = ks * (lightAtten * smoothFactor);

                    float kIndirectLight = pow(_Roughness * _Roughness + 1 , 2) * rcp(8.0);
                    float kInIBL = pow(_Roughness * _Roughness, 2) * rcp(8.0);

                    float GLeft = dot(input.normalWS , AddtionalLight.direction) / 
                              lerp(dot(input.normalWS , AddtionalLight.direction), 1, kIndirectLight);
                    float GRight = dot(input.normalWS , viewDir) / 
                              lerp(dot(input.normalWS , AddtionalLight.direction), 1, kIndirectLight);
                    float G = GLeft * GRight;
                    // blinn -= lambert;

                    half3 S = ks * AddtionalLight.color ;

                    //F
                    half3 f0 = half3(0.04, 0.04, 0.04);
                    f0 = lerp(f0, kd, _Metalic);
                    float3 fresnel = Fresnel(AddtionalLight.direction, viewDir, input.normalWS, f0);

                    half3 ambient_contrib = SampleSH(input.normalWS);
                    // half3 ambient = 0.03 * diffuse;

                    // color += (ks * G * fresnel + kd );
                    color += ambient_contrib;
                }

                return half4((color.rgb), albedo.a) ;
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
                float _Metalic;
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
