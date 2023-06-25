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
    float3 bitangentWS : TEXCOORD1;
    float2 uv : TEXCOORD2;
    float3 tangentWS : TEXCOORD3;
    float3 normalWS : TEXCOORD4;
    float3 normalOS : TEXCOORD5;
    // float4 scrPos : TEXCOORD6;
    float4 shadowCoord : TEXCOORD6;
    // float2 uv2 : TEXCOORD8;
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


float BlinnPhong(half3 H, half3 normalWS, half N)
{
    float BlinnPhong = pow(max(dot(H, normalWS), 0.0001), 5);
    BlinnPhong = pow(BlinnPhong, N) * ((N + 1) / (2 * 3.1415926535));
    // BlinnPhong = (( _Roughness + 2) * ( _Roughness +4)) /
    //               (8 * 3.1415926535 * (pow(2,-_Roughness / 2) + _Roughness))
    //               * BlinnPhong;
    
    return BlinnPhong;
}

float Lambert(half3 lightDir, half3 normalWS)
{
    float lambert = max(dot(normalize(lightDir), normalize(normalWS)), 0.0001);
    
    return lambert;
}

float3 Fresnel(half3 N, half3 viewDirection, half3 f0)
{
    float3 fresnel = f0 + (1.0 - f0) * pow((1.0 - dot(N, viewDirection)), 5.0);

    return fresnel;
}

float FresnelLerp(half3 N, half3 viewDirection)
{
    float fresnelLerp = pow(1 - dot(N, viewDirection), 4);
    return fresnelLerp;
}

float3 FresnelRoughness(half3 N, half3 viewDirection, half3 f0, float roughness)
{
    float3 fresnel = f0 + (max(float3(1.0, 1.0, 1.0) - roughness, f0))
    * pow((1.0 - dot(N, viewDirection)), 5.0);

    return fresnel;
}

half3 BoxProjection(float3 reflectionWS, float3 positionWS,
float4 cubemapPositionWS, float3 boxMin, float3 boxMax)
{
    if (cubemapPositionWS.w > 0.0f)
    {
        boxMin -= positionWS;
        boxMax -= positionWS;
        float x = (reflectionWS.x > 0 ? boxMax.x : boxMin.x) / reflectionWS.x;
        float y = (reflectionWS.y > 0 ? boxMax.x : boxMin.y) / reflectionWS.y;
        float z = (reflectionWS.z > 0 ? boxMax.x : boxMin.z) / reflectionWS.z;
        float scalar = min(min(x, y), z);

        return reflectionWS * scalar + (positionWS - cubemapPositionWS);
    }
    return reflectionWS;
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

    //receive shadow
    o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
    o.normalOS = normalize(input.normalOS);
    
    o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
    o.uv = TRANSFORM_TEX(input.texcoord, _NormalMap);
    o.uv = TRANSFORM_TEX(input.texcoord, _MaskMap);
    // o.uv2 = TRANSFORM_TEX(input.texcoord, _NormalMap);
    // o.uv = TRANSFORM_TEX(input.texcoord, _NormalMap);
    
    return o;
}

half4 frag(v2f input) : SV_TARGET
{
    uint meshRenderingLayers = GetMeshRenderingLightLayer();
    half rcpPI = rcp(PI);
    _Metallic = max(0.04, _Metallic);

    half surfaceReduction = 1.0 / (_Roughness * _Roughness + 1.0);

    half3 color = half3(0, 0, 0);
    half3 f0 = half3(0.04, 0.04, 0.04);
    float lambert = 0.0;

    float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
    float3 positionVS = TransformWorldToView(input.positionWS);
    float3 normalVS = TransformWorldToViewDir(normalize(input.normalWS), true);

    //albedo
    half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
    half3 diffuse = _BaseColor * albedo;

    //enable mask map
    #if defined(_ENABLE_MASK_MAP)
        _Metallic = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv).r ;
        _Roughness = (1.0 - SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv).a) * _Roughness;
    #endif

    clip(albedo.a - 0.001);

    //normal map
    float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv);
    float3 bump = UnpackNormalScale(normalMap, _NormalScale);
    input.normalWS = TransformTangentToWorld(bump, real3x3(input.tangentWS, input.bitangentWS, input.normalWS));

    //initialize main light
    Light MainLight = GetMainLight(input.shadowCoord);
    float3 mainLightDir = normalize(half3(MainLight.direction));
    float4 mainLightColor = float4(MainLight.color, 1);

    float3 H = normalize(mainLightDir + viewDir);

        #ifdef _LIGHT_LAYERS
            uint lightLayerMask = asuint(MainLight.layerMask);
        #else
            uint lightLayerMask = DEFAULT_LIGHT_LAYERS;
        #endif


if(IsMatchingLightLayer(lightLayerMask, meshRenderingLayers))
{
    ///main light pbr part
    //G
    float G = GeometrySmith(input.normalWS, viewDir, mainLightDir, _Roughness);

    //D_GGX_TR
    float ks = D_GGX_TR(input.normalWS, H, _Roughness);
    half3 S = ks * mainLightColor ;

    //F
    float3 F = Fresnel(input.normalWS, viewDir, f0);

    //D
    lambert = Lambert(mainLightDir, input.normalWS);
    float3 kd = float3(1.0, 1.0, 1.0) - F;
    kd *= (1.0 - _Metallic);
    // ambient_contrib *=kd;
    float3 D = diffuse * kd * mainLightColor ;

    // input.shadowCoord  = TransformWorldToShadowCoord(input.positionWS);
    
    color += (D * lambert * _DNormalization + S * F * G) * MainLight.shadowAttenuation;
}
    //GI cubemap and mip cul
    half MIP = _Roughness * (1.7 - 0.7 * _Roughness) * UNITY_SPECCUBE_LOD_STEPS;
    float3 reflectDirWS = reflect(-viewDir, input.normalWS);

    #if defined(_REFLECTION_PROBE_BOX_PROJECTION)
        reflectDirWS = BoxProjection(reflectDirWS, input.positionWS, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
        // reflectDirWS = float3(1,1,1);
    #endif

    half4 cubeMap = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectDirWS, MIP);
    //you have to decodeHDR, otherwise it will not work at all.
    #if defined(UNITY_USE_NATIVE_HDR)
        half3 cubeMapHDR = cubeMap.rgb;
    #else
        half3 cubeMapHDR = DecodeHDREnvironment(cubeMap, unity_SpecCube0_HDR);
    #endif
    //indirect
    float3 ambient_contrib = max(0, SampleSH(input.normalOS.xyz)) ;

    //Ambient Fresnel
    f0 = lerp(f0, diffuse, _Metallic);

    float3 AmbientKs = FresnelRoughness(input.normalWS, viewDir, f0, _Roughness);
    float3 AmbientKd = float3(1.0, 1.0, 1.0) - AmbientKs;
    ambient_contrib = ambient_contrib * diffuse * AmbientKd;

    //punctuation lights
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0; lightIndex < pixelLightCount; ++lightIndex)
    {
        #ifdef _LIGHT_LAYERS
            lightLayerMask = asuint(_AdditionalLightsLayerMasks[lightIndex]);
        #else
            lightLayerMask = DEFAULT_LIGHT_LAYERS;
        #endif

        if(IsMatchingLightLayer(lightLayerMask, meshRenderingLayers))
        {
            float4 lightPositionWS = _AdditionalLightsPosition[lightIndex];
            half distanceAttenuation = _AdditionalLightsAttenuation[lightIndex];
            half3 lightColor = _AdditionalLightsColor[lightIndex].rgb;

            //calculate attenuation
            float3 lightVector = lightPositionWS.xyz - input.positionWS * lightPositionWS.w;
            // float3 lightVector = lightPositionWS;
            // float distanceSqr = max(dot(lightVector, lightVector), 0.1);
            float distanceSqr = max(dot(lightVector, lightVector), HALF_MIN);

            float lightAtten = rcp(distanceSqr);

            half factor = half(distanceSqr * distanceAttenuation);
            half smoothFactor = saturate(half(1.0) - factor * factor);
            smoothFactor *= smoothFactor;

            float3 lightDirection = half3(lightVector * rsqrt(distanceSqr));

            H = normalize(lightDirection + viewDir);

            //G
            float G = GeometrySmith(input.normalWS, viewDir, lightDirection, _Roughness);

            //S
            // float ks = BlinnPhong(H, input.normalWS, _Roughness);
            //D_GGX_TR
            float ks = D_GGX_TR(input.normalWS, H, _Roughness);
            ks = ks * (lightAtten * smoothFactor);
            half3 S = ks * lightColor ;

            //F
            float3 F = Fresnel(input.normalWS, viewDir, f0);

            //D
            lambert = Lambert(lightDirection, input.normalWS) * lightAtten * smoothFactor;
            float3 kd = float3(1.0, 1.0, 1.0) - F;
            kd *= (1.0 - _Metallic);
            // ambient_contrib *=kd;
            float3 D = diffuse * kd * lightColor ;

            // color += (S * G * fresnel + kd );

            // D += ambient_contrib;
            color += (D * lambert * /*rcpPI*/ _DNormalization + S * F * G);
        }
    }
    // f0 = lerp(f0, diffuse, _Metallic);
    half fresnelTerm = FresnelLerp(input.normalWS, viewDir) /* rcp(PI)*/;
    cubeMapHDR *= lerp(_BaseColor, 1.0, fresnelTerm);
    half3 indirectSpecular = cubeMapHDR * rcpPI;

    half3 envColor = ambient_contrib * (1 - _Metallic) + indirectSpecular;

    color += envColor;

    return half4((color), albedo.a) ;
}