Shader "LwyShaders/Hair_Anisotropy_Phong"
{
    Properties
    {
        _BaseMap ("Base Map", 2D) = "white" { }
        _NormalMap ("Normal Map", 2D) = "white" { }
        _BaseColor ("Color", Color) = (2, 1, 1, 1)
        _SpecColor ("Specular color", Color) = (1, 1, 1, 1)
        _SpecPower ("Specular power", float) = 1
        _Darkness ("Darkness", range(0, 1)) = 0.6
        _Glossness ("Glossness", float) = 8
        _NormalScale ("Normal scale", float) = 0.2
        _Cutoff ("Alpha Clip threshold", float) = 0.5
        _NoiseMap ("Hair Noise", 2D) = "white" { }
        _AnisotropyColor ("anistropy color", color) = (1, 1, 1, 1)
        _AnisotropyPower ("anistropy power", float) = 2
        _NoisePower ("Noise Power", Range(0, 5)) = 0.6
        _FrenelPower ("Rim Power", float) = 3
        _FrenelLightness ("Rim lightness", float) = 0.3
        _RimColor ("Rim Color", Color) = (1, 1, 1, 1)
        _Exponent ("Exponent", float) = 100
        _AOMap ("AOmap", 2D) = "white" { }
        _AOContrast ("AO contrast", float) = 1.5
        
        _OutLineWidth("Outline width", float) = 0.1
        _OutLineColor("Outline color", color) = (0.2,0.2,0.2,1)
        // _SoftDepth ("soft depth", half) = 1
        // _RampMap ("Ramp Map", 2D) = "white" { }
        // _Remap ("Remap value", vector) = (1,-1,-1,1)
        // _LightDebug ("light Debug", vector) = (0,0,0,0)

    }
    SubShader
    {
        Tags { "Queue" = "Geometry" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
            Cull off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile  _MAIN_LIGHT_SHADOWS
            #pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile  _SHADOWS_SOFT


            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"


            CBUFFER_START(UnityPerMaterial)
                // float4 _BaseMap_ST;
                // half4 _BaseColor;
                // half _Cutoff;
                half _Surface;

                half4 _BaseColor;
                half4 _AnisotropyColor;
                half _Darkness;
                half _Glossness;
                half _Cutoff;
                half4 _SpecColor;
                half _SpecPower;
                
                half4 _BaseMap_ST;
                half4 _NormalMap_ST;
                half4 _NoiseMap_ST;
                half4 _AOMap_ST;
                
                half _NormalScale;
                half _NoisePower;
                half _AnisotropyPower;
                half _FrenelPower;
                half4 _RimColor;
                half _Exponent;
                half _FrenelLightness;
                half _AOContrast;

                float4 _DetailAlbedoMap_ST;
                half4 _EmissionColor;
                half _Smoothness;
                half _Metallic;
                half _BumpScale;
                half _Parallax;
                half _OcclusionStrength;
                half _ClearCoatMask;
                half _ClearCoatSmoothness;
                half _DetailAlbedoMapScale;
                half _DetailNormalMapScale;
                // half _SoftDepth;
                // half4 _RampMap;
                // half4 _RampMap_ST;
                // half4 _Remap;
                // half3 _LightDebug;

            CBUFFER_END



            struct a2v
            {
                half4 vertex : POSITION;
                half3 normal : NORMAL;
                half4 texcoord : TEXCOORD0;
                half4 AOcoord : TEXCOORD1;
                half4 tangent : TANGENT;
            };

            struct v2f
            {
                half4 pos : SV_POSITION;
                half2 uv : TEXCOORD0;
                half3 worldNormal : TEXCOORD1;
                half3 worldPos : TEXCOORD2;
                half3 worldTangent : TEXCOORD3;
                half3 worlBbitangent : TEXCOORD4;
                half4 screenPos : TEXCOORD5;
                half fogFactor : TEXCOORD6;
                half4 shadowCoord : TEXCOORD7;
                half2 AOcoord : TEXCOORD9;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            // TEXTURE2D(_RampMap);
            // SAMPLER(sampler_RampMap);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            TEXTURE2D(_NoiseMap);
            SAMPLER(sampler_NoiseMap);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            
            TEXTURE2D(_AOMap);
            SAMPLER(sampler_AOMap);


            v2f vert(a2v inside)
            {
                v2f o;

                o.pos = TransformObjectToHClip(inside.vertex.xyz);

                o.worldNormal = TransformObjectToWorldNormal(inside.normal);
                o.worldPos = TransformObjectToWorld(inside.vertex.xyz);
                o.worldTangent = TransformObjectToWorldDir(inside.tangent.xyz);

                o.shadowCoord = TransformWorldToShadowCoord(o.worldPos);
                

                //cul bitangent
                o.worlBbitangent = normalize(cross(o.worldNormal, o.worldTangent) * inside.tangent.w);
                

                // o.uv = TRANSFORM_TEX(inside.texcoord, _RampMap);
                o.uv = TRANSFORM_TEX(inside.texcoord, _BaseMap);
                o.uv = TRANSFORM_TEX(inside.texcoord, _NormalMap);
                o.AOcoord = TRANSFORM_TEX(inside.AOcoord, _AOMap);

                //for depth tex
                o.screenPos = ComputeScreenPos(o.pos);

                //fog
                o.fogFactor = ComputeFogFactor(o.pos.z);

                return o;
            };

            // //define remap function
            // half remap(half x , half t1, half t2, half s1, half s2){
            
            //     // if(x=0){return x;}
            //     return (x-t1)/(t2-t1)*(s2-s1) +s1;
            
            // }


            half4 frag(v2f inside) : SV_TARGET
            {
                //initialize lighting struct
                Light mlight = GetMainLight(inside.shadowCoord);
                // half3 lightDebug = {_LightDebug.xyz};
                half4 lightColor = half4(mlight.color, 0);

                //normal map
                half4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, inside.uv);
                half3 bump = UnpackNormalScale(normalMap, _NormalScale);
                inside.worldNormal = TransformTangentToWorld(bump, half3x3(inside.worldTangent, inside.worlBbitangent, inside.worldNormal));

                //diffuse color
                half4 diffuseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, inside.uv);

                //AO map
                half AOMap = SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap, inside.AOcoord).r;
                


                //lambert
                half Lambert = dot(mlight.direction, inside.worldNormal) * 0.5 + _Darkness;

                // half4 rampColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, inside.uv) ;

                clip(diffuseColor.a - _Cutoff);


                // half4 remapLambert =Lambert;
                // if(Lambert < 0 ){
                //     remapLambert = saturate(remap(Lambert, _Remap.x,_Remap.y,_Remap.z,_Remap.w));
                // }

                
                // return testingColor;
                
                //Define light props

                half3 lightDir = normalize(mlight.direction);
                half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - inside.worldPos);
                half3 reflectDir = normalize(reflect(lightDir, inside.worldNormal));

                // //phong

                // half phong = pow(saturate(dot(viewDir,-reflectDir)),_Glossness);
                
                // half4 phongSpecular = phong * _SpecColor * lightColor *_SpecPower;


                //blin-phong
                //cul bisector
                half3 bisector = normalize(lightDir + viewDir);
                half blinPhone = pow(saturate(dot(bisector, -reflectDir)), _Glossness);
                half4 blinPhoneSpec = blinPhone * _SpecColor * lightColor * _SpecPower;

                //Anistropy
                //set noise
                half4 noiseMap = SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, inside.uv);
                half3 ShiftT = inside.worlBbitangent + inside.worldNormal * saturate(pow(abs(noiseMap.x), _NoisePower));

                // half3 H = normalize(lightDir + viewDir);

                half dotTH = dot(ShiftT, bisector);
                half sinTH = sqrt(1 - dotTH * dotTH);
                half dirAtten = smoothstep(1, 0.0, dotTH);
                half finalDirAtten = dirAtten * pow(sinTH, _Exponent);
                half4 anistropy = saturate(pow(finalDirAtten, _AnisotropyPower) * lightColor) * _AnisotropyColor;

                //fresnel rim light
                half4 fresnelRimLight ;
                fresnelRimLight = _RimColor * pow((1 - (saturate(dot(normalize(inside.worldNormal), viewDir)))), _FrenelPower) * _FrenelLightness;
                // fresnelRimLight -= 0.1;




                // // depth tex
                // half2 scrPos = inside.screenPos.xy / inside.screenPos.w;
                // half depthTex = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, scrPos).r;
                // half LinearDepth = LinearEyeDepth(depthTex, _ZBufferParams);

                // half4 depthCol = saturate((LinearDepth - inside.screenPos.w)/_SoftDepth);
                // half4 depthCol2 = lerp(-100,100,(LinearDepth - inside.screenPos.w));


                // half4 depwithbase = _BaseColor * (1-depthCol2);

                //final blend colors
                // half4 finalColorPhong = anistropy + _BaseColor * remapLambert * half4(mlight.color, 1) * diffuseColor +phongSpecular;
                half4 finalColorBlin = (_BaseColor + fresnelRimLight) * Lambert * half4(mlight.color, 0) * diffuseColor + blinPhoneSpec + anistropy ;

                //Mix with fog
                half3 diffuseColorFog;
                diffuseColorFog = MixFog(finalColorBlin.xyz, inside.fogFactor);

                //Reciving shadows
                finalColorBlin *= (mlight.shadowAttenuation + 0.5);

                return half4(finalColorBlin.rgb * saturate(clamp(AOMap, 0, 1) * _AOContrast),1);
                // return AOMap;

            };

            ENDHLSL
        }

        // Pass
        // {
        //     Name "DepthOnly"
        //     Tags { "LightMode" = "DepthOnly" }

        //     ZWrite On
        //     ColorMask 0

        //     HLSLPROGRAM
        //     #pragma exclude_renderers gles gles3 glcore
        //     #pragma target 4.5

        //     #pragma vertex DepthOnlyVertex
        //     #pragma fragment DepthOnlyFragment

        //     #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"


        //     CBUFFER_START(UnityPerMaterial)
        //         half _Surface;

        //         half4 _BaseColor;
        //         half4 _AnisotropyColor;
        //         half _Darkness;
        //         half _Glossness;
        //         half _Cutoff;
        //         half4 _SpecColor;
        //         half _SpecPower;
                
        //         half4 _BaseMap_ST;
        //         half4 _NormalMap_ST;
        //         half4 _NoiseMap_ST;
        //         half4 _AOMap_ST;
                
        //         half _NormalScale;
        //         half _NoisePower;
        //         half _AnisotropyPower;
        //         half _FrenelPower;
        //         half4 _RimColor;
        //         half _Exponent;
        //         half _FrenelLightness;
        //         half _AOContrast;

        //         float4 _DetailAlbedoMap_ST;
        //         half4 _EmissionColor;
        //         half _Smoothness;
        //         half _Metallic;
        //         half _BumpScale;
        //         half _Parallax;
        //         half _OcclusionStrength;
        //         half _ClearCoatMask;
        //         half _ClearCoatSmoothness;
        //         half _DetailAlbedoMapScale;
        //         half _DetailNormalMapScale;
        //     CBUFFER_END

        //     // -------------------------------------
        //     // Material Keywords
        //     // #pragma shader_feature_local_fragment _ALPHATEST_ON

        //     //--------------------------------------
        //     // GPU Instancing
        //     // #pragma multi_compile_instancing
        //     // #pragma multi_compile _ DOTS_INSTANCING_ON

        //     // #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
        //     #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
        //     ENDHLSL
        // }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
            CBUFFER_START(UnityPerMaterial)
                half _Surface;

                half4 _BaseColor;
                half4 _AnisotropyColor;
                half _Darkness;
                half _Glossness;
                half _Cutoff;
                half4 _SpecColor;
                half _SpecPower;
                
                half4 _BaseMap_ST;
                half4 _NormalMap_ST;
                half4 _NoiseMap_ST;
                half4 _AOMap_ST;
                
                half _NormalScale;
                half _NoisePower;
                half _AnisotropyPower;
                half _FrenelPower;
                half4 _RimColor;
                half _Exponent;
                half _FrenelLightness;
                half _AOContrast;

                float4 _DetailAlbedoMap_ST;
                half4 _EmissionColor;
                half _Smoothness;
                half _Metallic;
                half _BumpScale;
                half _Parallax;
                half _OcclusionStrength;
                half _ClearCoatMask;
                half _ClearCoatSmoothness;
                half _DetailAlbedoMapScale;
                half _DetailNormalMapScale;
            CBUFFER_END

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        Pass{
            Tags { "Queue"="Geometry" "IgnoreProjector"="True" "LightMode"="SRPDefaultUnlit" }
            Cull front

            
            HLSLPROGRAM

            

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            CBUFFER_START(UnityPerMaterial)

                
                float _OutLineWidth;
                float4 _OutLineColor;
                half _Cutoff;

            CBUFFER_END

            
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);


            struct a2v{
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                float3 vertColor : COLOR;

            };

            struct v2f{
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float2 worldNormal : TEXCOORD1;
                float2 uv : TEXCOORD2;
                // float3 vertColor : COLOR;
            };

            v2f vert(a2v input){
                v2f o;

                // input.positionOS.xyz += input.tangent * 0.01 *_OutLineWidth;
                // o.positionCS = TransformObjectToHClip(input.positionOS.xyz + input.normal * _OutLineWidth *0.1);
                o.positionCS = TransformObjectToHClip(input.positionOS);
                o.uv = input.uv;

                o.positionCS.xy += input.normal.xy * _OutLineWidth * 0.1 * o.positionCS.w * input.vertColor.r;
                // o.vertColor = input.vertColor;

                
                // o.uv = input.uv;
                

                return o;
            }
            
            half4 frag(v2f input):SV_TARGET{
                half4 diffuseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                // _OutLineColor.a *= diffuseColor.a;
                clip(diffuseColor.a - _Cutoff);

                return _OutLineColor;
            }

            ENDHLSL

        }
    }
}

