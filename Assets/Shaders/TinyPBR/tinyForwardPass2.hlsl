#ifndef TINYFORWARDPASS_INCLUDED
#define TINYFORWARDPASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/Debugging3D.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/AmbientOcclusion.hlsl"
// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

struct a2v {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 texcoord : TEXCOORD0;
                // float2 staticLightmapUV   : TEXCOORD1;
                // float2 dynamicLightmapUV  : TEXCOORD2;
                // UNITY_VERTEX_INPUT_INSTANCE_ID

            };

            struct v2f
            {
                float3 positionWS : TEXCOORD0;
                //float3 bitangentWS : TEXCOORD1;
                float4 uv : TEXCOORD2;
                // float2 uv2 : TEXCOORD7;
                float4 tangentWS : TEXCOORD3;
                float3 normalWS : TEXCOORD4;
                float4 positionCS : SV_POSITION;
                float3 normalOS : TEXCOORD6;
                // float4 scrPos : TEXCOORD6;
                // float4 positionCS : SV_POSITION;
                // float2 uv2 : TEXCOORD8;

            };

            float4 RNMCulculate(float4 NormalBase, float4 NormalDetail)
            {
                NormalBase.xyz =NormalBase.xyz*float3( 2,  2, 2) + float3(-1, -1,  0);
                NormalDetail.xyz = NormalDetail.xyz*float3(-2, -2, 2) + float3( 1,  1, -1);
                float4 r = NormalBase*dot(NormalBase, NormalDetail)/NormalBase.z - NormalDetail;
                return r*0.5 + 0.5;
            }

            float D_GGX_TR(float3 N, float3 H, float roughness)
            {
                float a2 = roughness * roughness;
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

            float BlinnPhong(float3 H, float3 normalWS, float N)
            {
                float BlinnPhong = pow(max(dot(H, normalWS), 0.0001), 5);
                BlinnPhong = pow(BlinnPhong, N) * ((N + 1) / (2 * 3.1415926535));
                
                return BlinnPhong;
            }

            float Lambert(float3 lightDir, float3 normalWS)
            {
                float lambert = max(dot(normalize(lightDir), normalize(normalWS)), 0.0001);
                
                return lambert;
            }

            float3 Fresnel(float3 N, float3 viewDirection, float3 f0)
            {
                float3 fresnel = f0 + (1.0 - f0) * pow((1.0 - max(dot(N, viewDirection), 0.0001)), 5.0);

                return fresnel;
            }

            float FresnelLerp(float3 N, float3 viewDirection)
            {
                float fresnelLerp = pow(1 - max(dot(N, viewDirection), 0.0001), 5);
                return fresnelLerp;
            }

            float3 FresnelRoughness(float3 N, float3 viewDirection, float3 f0, float roughness)
            {
                float3 fresnel = f0 + (max(float3(1.0, 1.0, 1.0) - roughness, f0))
                * pow((1.0 - dot(N, viewDirection)), 5.0);

                return fresnel;
            }

            float3 BoxProjection(float3 reflectionWS, float3 positionWS,
            float4 cubemapPositionWS, float3 boxMin, float3 boxMax)
            {
                //UNITY_BRANCH
                if (cubemapPositionWS.w > 0.0f)
                {
                    float3 boxMinMax = (reflectionWS > 0.0f) ? boxMax.xyz : boxMin.xyz;
                    float3 rbMinMax = float3(boxMinMax - positionWS) / reflectionWS;
                    //boxMin -= positionWS;
                    //boxMax -= positionWS;
                    //float x = (reflectionWS.x > 0 ? boxMax.x : boxMin.x) / reflectionWS.x;
                    //float y = (reflectionWS.y > 0 ? boxMax.x : boxMin.y) / reflectionWS.y;
                    //float z = (reflectionWS.z > 0 ? boxMax.x : boxMin.z) / reflectionWS.z;
                    float fa = min(min(rbMinMax.x, rbMinMax.y), rbMinMax.z);
                    float3 worldPos = float3(positionWS - cubemapPositionWS.xyz);

                    return worldPos + reflectionWS * fa;
                }
                return reflectionWS;
            }

            //half4 GetEmissionColor(half4 emissionColor, half4 emissionMap, float4 sampler_BaseMap, float2 uv.zw)
            //{
            //    emissionMap = SAMPLE_TEXTURE2D(emissionMap, sampler_BaseMap, uv.zw);
            //    return emissionMap *= emissionColor;
            //}

            v2f vert(a2v input)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(input.positionOS);
                o.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(input.normalOS, true);
                o.tangentWS = float4(TransformObjectToWorldDir(input.tangentOS, true), input.tangentOS.w);

                //real sign = real(input.tangentOS.w) * GetOddNegativeScale();
                //o.bitangentWS = cross(o.normalWS.xyz, o.tangentWS.xyz) * sign;
                
                // o.positionVS = TransformWorldToView(TransformObjectToWorld(input.positionOS.xyz));
                // normalVS = TransformWorldToViewDir(normalWS, true);

                // //NDC
                // float4 ndc = input.positionOS * 0.5f;
                // o.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
                // o.positionNDC.zw = TransformObjectToHClip(input.positionOS).zw;

                // //scr pos
                // o.scrPos = ComputeScreenPos(o.positionCS);

                o.normalOS = input.normalOS;
                
                o.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);
                o.uv.zw = TRANSFORM_TEX(input.texcoord, _DetailNormalMap);
                
                return o;
            }

            float4 frag(v2f input) : SV_TARGET
            {
                // uint meshRenderingLayers = GetMeshRenderingLightLayer();

                
                // float rcpPI = rcp(PI);
                _Metallic = max(0.04, _Metallic);

                float3 color = float3(0, 0, 0);
                float3 f0 = float3(0.04, 0.04, 0.04);
                float lambert = 0.0;
                float G = 0.0;
                float3 D = float3(0, 0, 0);
                float3 S = float3(0, 0, 0);
                float3 F = float3(0, 0, 0);
                
                //normal map
                float sgn = input.tangentWS.w;
                half3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                
                float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv.xy);
                float4 detailNormalMap = SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailNormalMap, input.uv.zw);

                float4 mixedNormalMap = RNMCulculate(normalMap,detailNormalMap);

                float3 bump = UnpackNormalScale(mixedNormalMap, _NormalScale);
                input.normalWS = TransformObjectToWorldNormal(input.normalOS, true);
                half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
                input.normalWS = TransformTangentToWorld(bump, float3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
                input.normalWS = NormalizeNormalPerPixel(input.normalWS);

                half3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

                float3 positionVS = TransformWorldToView(input.positionWS);
                //float3 normalVS = TransformWorldToViewDir(normalize(input.normalWS), true);

                
                //albedo
                float4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv.xy);
                float4 diffuse = _BaseColor * albedo;

                //enable mask map
                #if defined(_ENABLE_MASK_MAP)
                    _Roughness = 1.0;
                    _Metallic = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv.zw.xy).r ;
                    _Roughness = (1.0 - SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv.xy).a * _Roughness) ;
                #endif

                //initialize main light
                Light MainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
                float3 mainLightDir = normalize(float3(MainLight.direction));
                float3 mainLightColor = MainLight.color;
                // float3 mainLightColor = half3(100,0,0);

                float3 H = normalize(mainLightDir + viewDirectionWS);

                // #ifdef _LIGHT_LAYERS
                //     uint lightLayerMask = asuint(MainLight.layerMask);
                // #else
                //     uint lightLayerMask = DEFAULT_LIGHT_LAYERS;
                // #endif


                // if (IsMatchingLightLayer(lightLayerMask, meshRenderingLayers))
                // {
                    ////main light brdf part
                    //G
                    G = GeometrySmith(input.normalWS, viewDirectionWS, mainLightDir, _Roughness);

                    //D_GGX_TR
                    float ks = D_GGX_TR(input.normalWS, H, _Roughness);
                    S = ks * mainLightColor ;

                    //F
                    f0 = lerp(f0, diffuse, _Metallic);
                    F = Fresnel(input.normalWS, viewDirectionWS, f0);

                    //D
                    lambert = Lambert(mainLightDir, input.normalWS) ;
                    float3 kd = float3(1.0, 1.0, 1.0) - F;
                    kd *= (1.0 - _Metallic);
                    // ambient_contrib *=kd;
                    D = diffuse * kd * mainLightColor ;

                    color += (D * lambert + S * F * G) * MainLight.shadowAttenuation;
                // }
                
                ///GI cube map and mip cul
                // float MIP = _Roughness * (1.7 - 0.7 * _Roughness) * UNITY_SPECCUBE_LOD_STEPS;
                float3 reflectDirWS = reflect(-viewDirectionWS, input.normalWS);

                #if defined(_REFLECTION_PROBE_BOX_PROJECTION)
                    float3 reflectDirWS00 = BoxProjection(reflectDirWS, input.positionWS, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
                    float3 reflectDirWS01 = BoxProjection(reflectDirWS, input.positionWS, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
                    // reflectDirWS = float3(1,1,1);
                #endif
                
                // ///cube map 01
                // float4 cubeMap00 = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectDirWS00, MIP);
                // //you have to decodeHDR, otherwise it will not work at all.
                //     #if defined(UNITY_USE_NATIVE_HDR)
                //         float3 cubeMapHDR = cubeMap.rgb;
                //     #else
                //         float3 cubeMapHDR00 = DecodeHDREnvironment(cubeMap00, unity_SpecCube0_HDR);
                //     #endif
                
                // ///cube map 02
                // float4 cubeMap01 = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube1, samplerunity_SpecCube1, reflectDirWS01, MIP);
                // //you have to decodeHDR, otherwise it will not work at all.
                //     #if defined(UNITY_USE_NATIVE_HDR)
                //             float3 cubeMapHDR = cubeMap.rgb;
                //     #else
                //     float3 cubeMapHDR01 = DecodeHDREnvironment(cubeMap01, unity_SpecCube1_HDR);
                //     #endif
                
                //         //cube map importance part.
                //         half probe0Volume = CalculateProbeVolumeSqrMagnitude(unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
                //         half probe1Volume = CalculateProbeVolumeSqrMagnitude(unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);

                //         half volumeDiff = probe0Volume - probe1Volume;
                
                //         float importanceSign = unity_SpecCube1_BoxMin.w;
                
                //         // A probe is dominant if its importance is higher
                //         // Or have equal importance but smaller volume
                //         bool probe0Dominant = importanceSign > 0.0f || (importanceSign == 0.0f && volumeDiff < -0.0001h);
                //         bool probe1Dominant = importanceSign < 0.0f || (importanceSign == 0.0f && volumeDiff > 0.0001h);

                //         float desiredWeightProbe0 = CalculateProbeWeight(input.positionWS, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
                //         float desiredWeightProbe1 = CalculateProbeWeight(input.positionWS, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);

                //         // Subject the probes weight if the other probe is dominant
                //         float weightProbe0 = probe1Dominant ? min(desiredWeightProbe0, 1.0f - desiredWeightProbe1) : desiredWeightProbe0;
                //         float weightProbe1 = probe0Dominant ? min(desiredWeightProbe1, 1.0f - desiredWeightProbe0) : desiredWeightProbe1;

                //     float totalWeight = weightProbe0 + weightProbe1;
                
                //     weightProbe0 /= max(totalWeight, 1.0f);
                //     weightProbe1 /= max(totalWeight, 1.0f);
                
                // half3 cubeMapHDR = half3(0.0h, 0.0h, 0.0h);
                
                // if(weightProbe0 > 0.01f)
                // {
                //     cubeMapHDR += cubeMapHDR00 * weightProbe0;
                // }
                
                // if (weightProbe1 > 0.01f)
                // {
                //     cubeMapHDR += cubeMapHDR01 * weightProbe1;
                // }
                
                // if(totalWeight < 0.99f)
                // {
                //     cubeMapHDR += DecodeHDREnvironment(cubeMap00, _GlossyEnvironmentCubeMap_HDR);

                // }

                float3 cubeMapHDR = CalculateIrradianceFromReflectionProbes(reflectDirWS, input.positionWS, _Roughness);
                ///end cube map


                // ///punctuation lights
                // uint pixelLightCount = GetAdditionalLightsCount();
                // for (uint lightIndex = 0; lightIndex < pixelLightCount; ++lightIndex)
                // {
                //     #ifdef _LIGHT_LAYERS
                //         lightLayerMask = asuint(_AdditionalLightsLayerMasks[lightIndex]);
                //     #else
                //         lightLayerMask = DEFAULT_LIGHT_LAYERS;
                //     #endif

                //     if (IsMatchingLightLayer(lightLayerMask, meshRenderingLayers))
                //     {
                //         float4 lightPositionWS = _AdditionalLightsPosition[lightIndex];
                //         float distanceAttenuation = _AdditionalLightsAttenuation[lightIndex];
                //         float3 lightColor = _AdditionalLightsColor[lightIndex].rgb;

                //         //calculate attenuation
                //         float3 lightVector = lightPositionWS.xyz - input.positionWS * lightPositionWS.w;
                //         // float3 lightVector = lightPositionWS;
                //         // float distanceSqr = max(dot(lightVector, lightVector), 0.1);
                //         float distanceSqr = max(dot(lightVector, lightVector), 0.5);

                //         float lightAtten = rcp(distanceSqr);

                //         float factor = float(distanceSqr * distanceAttenuation);
                //         float smoothFactor = saturate(float(1.0) - factor * factor);
                //         smoothFactor *= smoothFactor;

                //         float3 lightDirection = float3(lightVector * rsqrt(distanceSqr));

                //         H = normalize(lightDirection + viewDirectionWS);

                //         //G
                //         G = GeometrySmith(input.normalWS, viewDirectionWS, lightDirection, _Roughness);

                //         //S
                //         // float ks = BlinnPhong(H, input.normalWS, _Roughness);
                //         //D_GGX_TR
                //         float ks = D_GGX_TR(input.normalWS, H, _Roughness);
                //         ks = ks * (lightAtten * smoothFactor);
                //         S = ks * lightColor ;

                //         //F
                //         F = Fresnel(input.normalWS, viewDirectionWS, f0);

                //         //D
                //         lambert = Lambert(lightDirection, input.normalWS) * lightAtten * smoothFactor;
                //         float3 kd = float3(1.0, 1.0, 1.0) - F;
                //         kd *= (1.0 - _Metallic);
                //         // ambient_contrib *=kd;
                //         D = diffuse * kd * lightColor ;

                //         color += (D * lambert * _DNormalization + S * F * G);
                //     }
                // }


                
                ///indirect
                float3 ambient_contrib = max(0.001, SampleSH(input.normalWS.xyz)) * diffuse * _DNormalization;

                //Ambient Fresnel
                float3 AmbientKs = FresnelRoughness(input.normalWS, viewDirectionWS, f0, _Roughness);
                float3 AmbientKd = float3(1.0, 1.0, 1.0) - AmbientKs;
                ambient_contrib = ambient_contrib * AmbientKd;

                float fresnelTerm = FresnelLerp(input.normalWS, viewDirectionWS) * (1 - _Roughness);
                cubeMapHDR = lerp(diffuse * cubeMapHDR, cubeMapHDR, fresnelTerm);
                float3 indirectSpecular = cubeMapHDR ;

                float3 envColor = (ambient_contrib * (1 - _Metallic) + indirectSpecular) ;
                
                //half3 emissionColor = GetEmissionColor(_emissiontColor, _EmissionMap, input.uv.zw);
                
                //emmision
                float4 emissionMap = SAMPLE_TEXTURE2D(_EmissionMap, sampler_BaseMap, input.uv.zw);
                emissionMap.rgb *= _EmissionColor;

                // float tempShadow = 1.0 - (1.0 - MainLight.shadowAttenuation) * T;

                // envColor *= tempShadow;

                color += (envColor + emissionMap);
                // color *= ;

                // return half4(envColor, diffuse.a);
                return half4(color, diffuse.a);
                // return MainLight.shadowAttenuation;

            }
            #endif
