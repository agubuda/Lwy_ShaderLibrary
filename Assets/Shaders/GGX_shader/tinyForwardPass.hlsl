struct a2v
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    // float2 staticLightmapUV   : TEXCOORD1;
    // float2 dynamicLightmapUV  : TEXCOORD2;
    // UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
    float3 positionWS : TEXCOORD0;
    float3 bitangentWS : TEXCOORD1;
    float2 uv : TEXCOORD2;
    float3 tangentWS : TEXCOORD3;
    float3 normalWS : TEXCOORD4;
    float4 shadowCoord : TEXCOORD5;
    float4 positionCS : SV_POSITION;
    // float3 normalOS : TEXCOORD5;
    // float4 scrPos : TEXCOORD6;
    // float4 positionCS : SV_POSITION;
    // float2 uv2 : TEXCOORD8;
};

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
    // BlinnPhong = (( _Roughness + 2) * ( _Roughness +4)) /
    //               (8 * 3.1415926535 * (pow(2,-_Roughness / 2) + _Roughness))
    //               * BlinnPhong;
    
    return BlinnPhong;
}

float Lambert(float3 lightDir, float3 normalWS)
{
    float lambert = max(dot(normalize(lightDir), normalize(normalWS)), 0.0001);
    
    return lambert;
}

float3 Fresnel(float3 N, float3 viewDirection, float3 f0)
{
    float3 fresnel = f0 + (1.0 - f0) * pow((1.0 - max(dot(N, viewDirection),0.001)), 5.0);

    return fresnel;
}

float FresnelLerp(float3 N, float3 viewDirection)
{
    float fresnelLerp = pow(1 - max(dot(N, viewDirection),0.001), 5);
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
    UNITY_BRANCH
    if (cubemapPositionWS.w > 0.0f)
    {
        float3 boxMinMax = (reflectionWS > 0.0f) ? boxMax.xyz : boxMin.xyz; 
        half3 rbMinMax = half3(boxMinMax - positionWS) / reflectionWS;
        //boxMin -= positionWS;
        //boxMax -= positionWS;
        //float x = (reflectionWS.x > 0 ? boxMax.x : boxMin.x) / reflectionWS.x;
        //float y = (reflectionWS.y > 0 ? boxMax.x : boxMin.y) / reflectionWS.y;
        //float z = (reflectionWS.z > 0 ? boxMax.x : boxMin.z) / reflectionWS.z;
        half fa = min(min(rbMinMax.x, rbMinMax.y), rbMinMax.z);
        half3 worldPos = half3(positionWS - cubemapPositionWS.xyz);

        return worldPos +reflectionWS * fa;
    }
    return reflectionWS;
}


v2f vert(a2v input)
{
    v2f o;
    o.positionCS = TransformObjectToHClip(input.positionOS);
    o.positionWS = TransformObjectToWorld(input.positionOS.xyz);
    o.normalWS = TransformObjectToWorldNormal(input.normalOS);
    o.tangentWS = float3(TransformObjectToWorldDir(input.tangentOS.xyz));

    real sign = real(input.tangentOS.w) * GetOddNegativeScale();
    o.bitangentWS = cross(o.normalWS.xyz, o.tangentWS.xyz) * sign;
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
    // o.normalOS = normalize(input.normalOS);
    
    o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
    // o.uv = TRANSFORM_TEX(input.texcoord, _NormalMap);
    // o.uv = TRANSFORM_TEX(input.texcoord, _MaskMap);
    // o.uv2 = TRANSFORM_TEX(input.texcoord, _NormalMap);
    // o.uv = TRANSFORM_TEX(input.texcoord, _NormalMap);
    
    return o;
}

float4 frag(v2f input) : SV_TARGET
{
    uint meshRenderingLayers = GetMeshRenderingLightLayer();
    // float rcpPI = rcp(PI);
    _Metallic = max(0.04, _Metallic);

    float3 color = float3(0, 0, 0);
    float3 f0 = float3(0.04, 0.04, 0.04);
    float lambert = 0.0;
    float G = 0.0;
    float3 D = float3(0,0,0);
    float3 S = float3(0,0,0);
    float3 F = float3(0,0,0);

    float3 viewDirectionWS = SafeNormalize(_WorldSpaceCameraPos.xyz - input.positionWS);
    float3 positionVS = TransformWorldToView(input.positionWS);
    float3 normalVS = TransformWorldToViewDir(normalize(input.normalWS), true);

    //albedo
    float4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
    float3 diffuse = _BaseColor * albedo;

    //enable mask map
    #if defined(_ENABLE_MASK_MAP)
        _Metallic = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv).r ;
        _Roughness = (1.0 - SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv).a * _Roughness) ;
    #endif

    float surfaceReduction = 1.0 / (_Roughness * _Roughness + 1.0);

    //normal map
    float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv);
    float3 bump = UnpackNormalScale(normalMap, _NormalScale);
    input.normalWS = SafeNormalize(input.normalWS);
    input.normalWS = TransformTangentToWorld(bump, half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz));

    //initialize main light
    Light MainLight = GetMainLight(input.shadowCoord);
    float3 mainLightDir = normalize(float3(MainLight.direction));
    float4 mainLightColor = float4(MainLight.color, 1);

    float3 H = normalize(mainLightDir + viewDirectionWS);

        #ifdef _LIGHT_LAYERS
            uint lightLayerMask = asuint(MainLight.layerMask);
        #else
            uint lightLayerMask = DEFAULT_LIGHT_LAYERS;
        #endif


if(IsMatchingLightLayer(lightLayerMask, meshRenderingLayers))
{
    ///main light pbr part
    //G
    G = GeometrySmith(input.normalWS, viewDirectionWS, mainLightDir, _Roughness);

    //D_GGX_TR
    float ks = D_GGX_TR(input.normalWS, H, _Roughness);
    S = ks * mainLightColor ;

    //F
    F = Fresnel(input.normalWS, viewDirectionWS, f0);

    //D
    lambert = Lambert(mainLightDir, input.normalWS);
    float3 kd = float3(1.0, 1.0, 1.0) - F;
    kd *= (1.0 - _Metallic);
    // ambient_contrib *=kd;
    D = diffuse * kd * mainLightColor ;

    // input.shadowCoord  = TransformWorldToShadowCoord(input.positionWS);
    
    color += (D * lambert * _DNormalization + S * F * G) * MainLight.shadowAttenuation;
}
    //GI cubemap and mip cul
    float MIP = _Roughness * (1.7 - 0.7 * _Roughness) * UNITY_SPECCUBE_LOD_STEPS;
    float3 reflectDirWS = reflect(-viewDirectionWS, input.normalWS);

    #if defined(_REFLECTION_PROBE_BOX_PROJECTION)
        reflectDirWS = BoxProjection(reflectDirWS, input.positionWS, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
        // reflectDirWS = float3(1,1,1);
    #endif

    float4 cubeMap = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectDirWS, MIP);
    //you have to decodeHDR, otherwise it will not work at all.
    #if defined(UNITY_USE_NATIVE_HDR)
        float3 cubeMapHDR = cubeMap.rgb;
    #else
        float3 cubeMapHDR = DecodeHDREnvironment(cubeMap, unity_SpecCube0_HDR);
    #endif
    //indirect
    float3 ambient_contrib = max(0, SampleSH(input.normalWS.xyz)) * diffuse * _DNormalization;

    //Ambient Fresnel
    f0 = lerp(f0, diffuse, _Metallic);

    float3 AmbientKs = FresnelRoughness(input.normalWS, viewDirectionWS, f0, _Roughness);
    float3 AmbientKd = float3(1.0, 1.0, 1.0) - AmbientKs;
    ambient_contrib = ambient_contrib  * AmbientKd ;

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
            float distanceAttenuation = _AdditionalLightsAttenuation[lightIndex];
            float3 lightColor = _AdditionalLightsColor[lightIndex].rgb;

            //calculate attenuation
            float3 lightVector = lightPositionWS.xyz - input.positionWS * lightPositionWS.w;
            // float3 lightVector = lightPositionWS;
            // float distanceSqr = max(dot(lightVector, lightVector), 0.1);
            float distanceSqr = max(dot(lightVector, lightVector), 0.5);

            float lightAtten = rcp(distanceSqr);

            float factor = float(distanceSqr * distanceAttenuation);
            float smoothFactor = saturate(float(1.0) - factor * factor);
            smoothFactor *= smoothFactor;

            float3 lightDirection = float3(lightVector * rsqrt(distanceSqr));

            H = normalize(lightDirection + viewDirectionWS);

            //G
            G = GeometrySmith(input.normalWS, viewDirectionWS, lightDirection, _Roughness);

            //S
            // float ks = BlinnPhong(H, input.normalWS, _Roughness);
            //D_GGX_TR
            float ks = D_GGX_TR(input.normalWS, H, _Roughness);
            ks = ks * (lightAtten * smoothFactor);
            S = ks * lightColor ;

            //F
            F = Fresnel(input.normalWS, viewDirectionWS, f0);

            //D
            lambert = Lambert(lightDirection, input.normalWS) * lightAtten * smoothFactor;
            float3 kd = float3(1.0, 1.0, 1.0) - F;
            kd *= (1.0 - _Metallic);
            // ambient_contrib *=kd;
            D = diffuse * kd * lightColor ;

            color += (D * lambert * _DNormalization + S * F * G);
        }
    } 
    // f0 = lerp(f0, diffuse, _Metallic);
    float fresnelTerm = FresnelLerp(input.normalWS, viewDirectionWS) /* rcp(PI)*/;
    cubeMapHDR = lerp( diffuse * cubeMapHDR, cubeMapHDR, fresnelTerm);
    float3 indirectSpecular = cubeMapHDR * 0.318309891613572;

    float3 envColor = ambient_contrib * (1 - _Metallic) + indirectSpecular;

    color += envColor;

    // return float4((color), albedo.a) ;
    return float4((color ), albedo.a);
}