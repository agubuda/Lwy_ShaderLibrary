#ifndef NPR_FUNCTIONS_INCLUDED
#define NPR_FUNCTIONS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// =========================================================================================
// 核心计算函数库
// =========================================================================================

/**
 * 计算修正后的高光光照方向 (XZ平面视线对齐)
 * 用于模拟卡通渲染中为了美观而让高光跟随视角的特性
 */
float3 CalculateReshapedLightDir(float3 lightDir, float3 viewDir, float alignFactor)
{
    float3 lightDirXZ = normalize(float3(lightDir.x, 0, lightDir.z) + 1e-5);
    float3 viewDirXZ  = normalize(float3(viewDir.x,  0, viewDir.z)  + 1e-5);
    float3 blendedXZ = lerp(lightDirXZ, viewDirXZ, alignFactor);
    return normalize(float3(blendedXZ.x, lightDir.y, blendedXZ.z));
}

/**
 * 采样遮罩贴图并获取 AO 和 Smoothness
 * maskMap: 纹理
 * sampler_maskMap: 采样器
 * uv: 坐标
 * enableAO: 是否启用AO
 * enableSmoothness: 是否启用光滑度
 * occlusionStrength: AO强度 (Transparent特有，Base默认为1)
 */
void GetMaskData(TEXTURE2D(maskMap), SAMPLER(sampler_maskMap), float2 uv, 
                 float enableAO, float enableSmoothness, float occlusionStrength,
                 out float ao, out float smoothnessMask)
{
    ao = 1.0;
    smoothnessMask = 1.0;
    
    // 注意：这里假设外部用宏判断，或者传入 float 形式的开关
    if (enableAO > 0.5 || enableSmoothness > 0.5)
    {
        float4 maskSample = SAMPLE_TEXTURE2D(maskMap, sampler_maskMap, uv);
        
        if (enableAO > 0.5)
            ao = lerp(1.0, maskSample.g, occlusionStrength);
            
        if (enableSmoothness > 0.5)
            smoothnessMask = maskSample.a;
    }
}

/**
 * NPR 漫反射计算 (Half Lambert + Ramp)
 */
float3 CalculateNPRDiffuse(float3 albedo, float3 lightColor, float3 lightDir, float3 normalWS, 
                           float shadowAtten, float ao, 
                           TEXTURE2D(rampMap), SAMPLER(sampler_rampMap), float rampColum)
{
    float NdotL = dot(lightDir, normalWS);
    float halfLambert = NdotL * 0.5 + 0.5;
    
    // 应用阴影和AO到采样坐标
    float rampCoord = saturate(halfLambert * shadowAtten * ao);
    
    float3 rampColor = SAMPLE_TEXTURE2D(rampMap, sampler_rampMap, float2(rampCoord, rampColum)).rgb;
    return albedo * rampColor * lightColor;
}

/**
 * NPR 高光计算 (PBR Style with Alignment)
 */
float CalculateNPRSpecularIntensity(float3 normalWS, float3 viewDir, float3 specLightDir,
                                    float specWidth, float specSoftness)
{
    float3 halfWay = normalize(viewDir + specLightDir);
    float NdotH = saturate(dot(normalWS, halfWay));
    
    float specThreshold = 1.0 - specWidth; 
    float specShape = smoothstep(specThreshold, specThreshold + specSoftness, NdotH);
    
    // Fresnel Term
    float LdotH = saturate(dot(specLightDir, halfWay));
    float fresnelTerm = 0.04 + (1.0 - 0.04) * pow(1.0 - LdotH, 5.0);
    
    return specShape * fresnelTerm;
}

/**
 * NPR 边缘光计算 (基础 Fresnel + 方向遮罩)
 */
float CalculateNPRRimIntensity(float3 normalWS, float3 viewDir, float3 lightDirForRim,
                               float rimWidth, float rimSoftness, float rimAlign)
{
    float fresnelBase = 1.0 - saturate(dot(normalWS, viewDir));
    float rimThreshold = 1.0 - rimWidth;
    float rimGradient = smoothstep(rimThreshold, rimThreshold + rimSoftness, fresnelBase);
    
    float NdotL_Rim = dot(normalWS, lightDirForRim);
    float rimLightMask = saturate(NdotL_Rim + rimAlign);
    
    return rimGradient * rimLightMask;
}

/**
 * 深度边缘光计算 (利用深度图产生相交高亮)
 */
float CalculateDepthRimMask(float4 positionNDC, float3 normalWS, float offsetMul, 
                            TEXTURE2D_X(depthTex), SAMPLER(sampler_depthTex))
{
    float3 normalVS = TransformWorldToViewDir(normalWS, true);
    float depth = positionNDC.z / positionNDC.w;
    
    // 假设 positionCS 已经被转换到 ScreenParams 空间 (Frag输入)
    // 这里需要注意，原始代码用的是 input.positionCS，在Frag中直接可用
    // 为了通用性，我们这里简化逻辑，假设外部传进来的是 ScreenUV
    // 但原代码逻辑依赖 ScreenUV + Offset。
    
    // 简化：这里只返回深度遮罩，计算逻辑比较依赖管线变量，建议保留在 Shader 中或传入 ScreenUV
    return 1.0; 
}

#endif
