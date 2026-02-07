#ifndef TINY_PBR_COMMON_INCLUDED
#define TINY_PBR_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// -------------------------------------------------------------------------
// 法线处理
// -------------------------------------------------------------------------

// RNM (Reoriented Normal Mapping) 混合算法
// 比简单的 Linear Blending 效果更好，能保留更多细节
half3 BlendNormalsRNM(half3 n1, half3 n2) {
    n1 += half3(0, 0, 1);
    n2 *= half3(-1, -1, 1);
    return n1 * dot(n1, n2) / n1.z - n2;
}

// -------------------------------------------------------------------------
// PBR 核心数学函数 (基于 UE5 / Disney 标准)
// -------------------------------------------------------------------------

// 辅助: 5次方计算
float Tiny_Pow5(float x) 
{
    return x * x * x * x * x;
}

// Diffuse: Disney/Burley 模型 
// 相比 Lambert，考虑了边缘的粗糙度回射，使得粗糙材质边缘更亮
float Tiny_DisneyDiffuse(float NdotV, float NdotL, float LdotH, float perceptualRoughness)
{
    float fd90 = 0.5 + 2 * LdotH * LdotH * perceptualRoughness;
    float lightScatter = (1 + (fd90 - 1) * Tiny_Pow5(1 - NdotL));
    float viewScatter = (1 + (fd90 - 1) * Tiny_Pow5(1 - NdotV));
    return lightScatter * viewScatter;
}

// Specular D: Trowbridge-Reitz GGX (法线分布函数)
float Tiny_D_GGX(float NdotH, float roughness)
{
    float a = roughness * roughness;
    float a2 = a * a;
    float d = (NdotH * a2 - NdotH) * NdotH + 1.0f; 
    return a2 / (PI * d * d);
}

// Specular V: Smith Joint GGX Correlated (几何遮蔽函数)
// 这种形式合并了 V 和 G 项，计算更高效
float Tiny_V_SmithGGXCorrelated(float NdotL, float NdotV, float roughness)
{
    float a = roughness * roughness;
    float LambdaV = NdotL * sqrt((-NdotV * a + NdotV) * NdotV + a);
    float LambdaL = NdotV * sqrt((-NdotL * a + NdotL) * NdotL + a);
    return 0.5f / (LambdaV + LambdaL + 1e-5f);
}

// -------------------------------------------------------------------------
// 直接光照计算入口
// -------------------------------------------------------------------------
half3 TinyPBR_DirectLight(Light light, float3 normalWS, float3 viewDirWS, 
                          float3 albedo, float roughness, float perceptualRoughness, 
                          float3 F0, float occlusion)
{
    // 1. 向量准备
    float3 lightDirWS = light.direction;
    float3 halfDir = normalize(lightDirWS + viewDirWS);

    // 2. 点积计算
    float NdotL = saturate(dot(normalWS, lightDirWS));
    float NdotV = saturate(dot(normalWS, viewDirWS));
    float NdotH = saturate(dot(normalWS, halfDir));
    float LdotH = saturate(dot(lightDirWS, halfDir));

    // 3. 辐射率 (颜色 * 距离衰减 * 阴影衰减)
    float attenuation = light.distanceAttenuation * light.shadowAttenuation;
    float3 radiance = light.color * attenuation;

    // 4. 漫反射项 (Disney)
    float diffuseTerm = Tiny_DisneyDiffuse(NdotV, NdotL, LdotH, perceptualRoughness) * NdotL;

    // 5. 高光项 (Cook-Torrance Specular BRDF = D * V * F)
    float D = Tiny_D_GGX(NdotH, roughness);
    float V = Tiny_V_SmithGGXCorrelated(NdotL, NdotV, roughness);
    float3 F = F_Schlick(F0, LdotH); // URP 内置菲涅尔近似

    float3 specularTerm = D * V * F;
    
    // 限制高光项，防止除零或过曝 Artifacts
    specularTerm = max(0, specularTerm * NdotL);

    // 6. 微表面遮蔽 (AO 抑制缝隙漏光)
    // 粗糙度越高，AO 对高光的影响越小；这里做一个简单的经验拟合
    float specularOcclusion = lerp(1.0, occlusion, perceptualRoughness);
    specularTerm *= specularOcclusion;

    // 7. 能量守恒合成 (kD + kS)
    // 金属度流程中，kS = F (菲涅尔项直接代表反射比例)
    float3 kS = F;
    float3 kD = (1.0 - kS); // 剩下的能量用于漫反射
    
    // 最终颜色 = (漫反射 + 高光) * 光照强度
    return (kD * albedo * diffuseTerm + specularTerm) * radiance;
}

half3 TinyPBR_AccumulateAdditionalLights(
    float3 positionWS,
    float4 positionCS,
    float3 normalWS,
    float3 viewDirWS,
    float3 diffuseColor,
    float roughness,
    float perceptualRoughness,
    float3 f0,
    float occlusion,
    half4 shadowMask,
    half3 vertexLight)
{
    #if defined(_ADDITIONAL_LIGHTS)
        half3 additionalColor = 0;

        InputData inputData = (InputData)0;
        inputData.positionWS = positionWS;
        inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(positionCS);

        LIGHT_LOOP_BEGIN(GetAdditionalLightsCount())
            Light light = GetAdditionalLight(lightIndex, positionWS, shadowMask);
            additionalColor += TinyPBR_DirectLight(light, normalWS, viewDirWS, diffuseColor, roughness, perceptualRoughness, f0, occlusion);
        LIGHT_LOOP_END

        return additionalColor;
    #elif defined(_ADDITIONAL_LIGHTS_VERTEX)
        return vertexLight * diffuseColor * occlusion;
    #else
        return 0;
    #endif
}

#endif
