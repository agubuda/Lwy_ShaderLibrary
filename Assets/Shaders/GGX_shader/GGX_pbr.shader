//processing, not finished.

Shader "LwyShaders/GGX_pbr"
{
    Properties
    {
        _Metalic("Metalic", Range(0,1)) = 1
        _BaseMap ("Texture", 2D) = "white" { }
        _BaseColor ("BaseColor", color) = (1.0,1.0,1.0,1.0)
        
        // [Space(20)][Header(Ramp lights)]
        // _RampMap ("Ramp Map", 2D) = "White" { }
        // _RampColum ("Ramp colum", float) = 0.8
        _Darkness ("Darkness", float) = 0.5

        // [Space(20)][Header(Outline settings)]
        // _OutLineWidth ("Outline width", float) = -0.04
        // _OutLineColor ("Outline color", color) = (0.4, 0.3, 0.3, 1)

        // [Space(20)][Header(Rim light settings)]
        // _OffsetMul ("_RimWidth", Range(0, 0.1)) = 0.0055
        // _Threshold ("_Threshold", Range(0, 1)) = 0.02
        // _RimColor ("RimColor", color) = (0.8, 0.7, 0.7, 1)
        // _FresnelPower ("Fresnel power", Range(0, 10)) = 3
        
        // [Space(20)][Header(AO map)]
        // _MaskMap ("Mask Map", 2D) = "white" { }//as urp default settings, g = AO, a = Metalic
        // _AOPower ("AO power", Range(0, 6)) = 1

        // [Space(20)][Header(Specular)]
        // _SpecPower ("Specular Power", float) = 10
        // _SpecColor ("Specular Color", color) = (0.4, 0.3, 0.3, 1)
        // _SpecRange ("Specular Range", Range(0, 1)) = 0.075
        // _SpacSmoothness ("Specular Edge Smoothness", Range(0, 1)) = 0.58
        // _SpecStrength ("Specular Range", float) = 0.86
        // _SpecAOPower ("Specular AO power", float) = 0.5
        // _SpecMaskPower ("Specular Mask power", Range(0, 10)) = 1

        // [Space(20)][Header(Better Stay in One)]
        // [Toggle(_ENABLEENVIROMENTLIGHT)] _ENABLEENVIROMENTLIGHT("Enable enviroment light", Float) = 0.0
        // _LightInfluence ("Light influence", Range(0.1, 1.5)) = 1

        // [Space(20)][Header(Color adjastment)]
        // _HueRed ("Hue red", Range(-1, 1)) = 0
        // _HueBlue ("Hue blue", Range(-1, 1)) = 0
        // _HueGreen ("Hue green", Range(-1, 1)) = 0

        [Space(20)]
        _Cubemap ("cube map", Cube) = "_Skybox" {}
    }
    SubShader
    {
        pass
        {
            Name "PBR skin"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            ZWrite On


            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fog

            #pragma multi_compile  _MAIN_LIGHT_SHADOWS
            #pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile  _SHADOWS_SOFT
            #pragma shader_feature _ENABLEENVIROMENTLIGHT

            CBUFFER_START(UnityPerMaterial)

                float4 _BaseMap_ST;
                float4 _MainTex_ST;
                float4 _BaseColor;
                // half _SpecPower;
                // float4 _SpecColor;
                // float _SpecRange;
                // float _SpecStrength;
                float _Darkness;
                // float _OutLineWidth;
                // float _RampColum;
                // float _OffsetMul;
                // float _Threshold;
                // float4 _RimColor;
                // float _FresnelPower;
                // float _AOPower;
                // float _SpacSmoothness;
                // float _SpecAOPower;
                // float _SpecMaskPower;
                // float _LightInfluence;
                // float _HueBlue;
                // float _HueRed;
                // float _HueGreen; 
                float _Metalic;
                // float4 unity_SpecCube0_HDR;
                // float4 _AOMap;

            CBUFFER_END

            
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_RampMap); SAMPLER(sampler_RampMap);
            TEXTURE2D(_MaskMap); SAMPLER(sampler_MaskMap);
            TEXTURE2D_X_FLOAT(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
            TEXTURECUBE(_Cubemap);SAMPLER(sampler_Cubemap);

            
// TEXTURECUBE(unity_SpecCube0);
// SAMPLER(samplerunity_SpecCube0);
            
            struct a2v
            {

                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 texcoord : TEXCOORD0;
                // float2 secondTexcoord : TEXCOORD1;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                // float3 positionVS : TEXCOORD4;
                float2 uv : TEXCOORD1;
                // float fogCoord : TEXCOORD2;
                float3 normalWS : TEXCOORD3;
                // float3 normalVS : TEXCOORD5;
                float4 positionNDC : TEXCOORD6;
                float4 scrPos : TEXCOORD7;
                float4 shadowCoord : TEXCOORD8;
            };

            v2f vert(a2v input)
            {
                v2f o;

                o.positionCS = TransformObjectToHClip(input.positionOS);
                o.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(input.normalOS.xyz);
                // o.positionVS = TransformWorldToView(TransformObjectToWorld(input.positionOS.xyz));
                // normalVS = TransformWorldToViewDir(normalWS, true);


                //NDC
                float4 ndc = input.positionOS * 0.5f;
                o.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
                o.positionNDC.zw = TransformObjectToHClip(input.positionOS).zw;

                //scr pos
                o.scrPos = ComputeScreenPos(o.positionCS);

                //recive shadow
                o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
                
                o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                

                return o;
            }


            float GeometrySchlickGGX(float NdotV, float k){
                    float SchGGXNom = NdotV;
                    float SchGGXDenom = NdotV * (1-k) + k;
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

            float4 frag(v2f input) : SV_TARGET
            {

                float3 positionVS = TransformWorldToView(input.positionWS);
                float3 normalVS = TransformWorldToViewDir(normalize(input.normalWS), true);

                //initialize main light
                Light MainLight = GetMainLight(input.shadowCoord);
                float3 LightDir = normalize(float3(MainLight.direction));
                float4 LightColor = float4(MainLight.color, 1);


                // //Blinn_phong
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
                // float3 HalfWay = normalize(viewDir + LightDir);
               
                float4 difusse = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);

                //ggx

                _Metalic = max(0.0001,_Metalic);

                float3 H =normalize( viewDir + LightDir );
                // float NoH = saturate(dot(input.normalWS, H));
                // float d = (NoH * _Metalic - NoH) * NoH +1;

                float temp2 = _Metalic * _Metalic ;
                float NoH = saturate(dot(H , input.normalWS ) );
                float NoH2 = NoH * NoH;
                float nom = temp2;
                float denom = (NoH2 * (temp2 - 1) + 1);
                denom = PI * denom *denom;
                float ggx = nom/max(denom, 0.001);

                //G
                
                float3 n = normalize(input.normalWS);

                float G = GeometrySmith(n , viewDir, LightDir, _Metalic);

                float NdotV = dot(n,viewDir);
                float NdotL = dot(n,LightDir);


                float brdfSpec = ggx*G/(4*NoH * NdotV);

                float ks = ggx;
                float kd = (1-ks) * (1- _Metalic);


                // float3 derectDiffColor = kd * difusse * LightColor * Lambert;


                float3 reflectDirWS = reflect(-viewDir,input.normalWS);
                // float4 Cubemap = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectDirWS, 10);
                float4 Cubemap = SAMPLE_TEXTURECUBE_LOD(_Cubemap, sampler_Cubemap, reflectDirWS, 0.5 * 10);

                float dirDiffColor = kd * _BaseColor *  saturate(NdotL)  ;

                float4 final = float4(dirDiffColor /* *  _GlossyEnvironmentColor */ + ks * LightColor * difusse ) ;

                // return  difusse * (ggx * LightColor + dirDiffColor* _GlossyEnvironmentColor * LightColor) + Cubemap *0.1;
                // return   dirDiffColor  + Cubemap  * _GlossyEnvironmentColor + ggx *difusse * LightColor;
                // return dirDiffColor + _GlossyEnvironmentColor * Cubemap  + ggx *difusse * LightColor;
                return (ggx * LightColor * difusse + dirDiffColor * difusse + Cubemap /* * _GlossyEnvironmentColor */) ;
            }

            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
