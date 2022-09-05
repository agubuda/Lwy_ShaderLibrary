Shader "Unlit/Hair_Anisotropy_Phong_Blin_001"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" { }
        _NormalMap ("Normal Map", 2D) = "white" {}
        // _RampMap ("Ramp Map", 2D) = "white" { }
        _Remap ("Remap value" , vector) = (1,-1,-1,1)
        _BaseColor ("Color", Color) = (2, 1, 1, 1)
        _SpecColor ("Specular color", Color) = (1,1,1,1)
        _SpecPower("Specular power", float) = 1
        _Darkness ("Darkness", range(0,1)) = 0.5
        _Glossness ("Glossness", float ) = 8
        _NormalScale ("Normal scale",float) = 1
        _Cutoff ("Alpha Clip threshold", float) = 0.5
        // _LightDebug("light Debug", vector) = (0,0,0,0)
        _NoiseMap("Hair Noise" ,2D) = "white" {}
        _AnisotropyColor("anistropy color",color) = (1,1,1,1)
        _AnisotropyPower("anistropy power", float) = 1
        _NoisePower("Noise Power",float) = 0.2
        _FrenelPower("Frenel Power", float) = 1
        // _SoftDepth("soft depth", float) = 1

    }
    SubShader
    {
        Tags { "Queue"="Geometry" "IgnoreProjector"="True" "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            ZWrite On
            Cull off            

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            // #include "UnityCG.cginc"


            CBUFFER_START(UnityPerMaterial)
                // half4 _MainTex;
                half4 _BaseColor;
                half4 _AnisotropyColor;
                float _Darkness;
                float _Glossness;
                float _Cutoff;
                half4 _SpecColor;
                float _SpecPower;
                // half4 _RampMap;
                // float4 _RampMap_ST;
                float4 _MainTex_ST;
                float4 _NormalMap_ST;
                float4 _NoiseMap_ST;
                half4 _Remap;
                // half3 _LightDebug;
                float _NormalScale;
                float _NoisePower;
                float _AnisotropyPower;
                float _FrenelPower;
                // float _SoftDepth;

            CBUFFER_END



            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float3 worldTangent : TEXCOORD3;
                float3 worlBbitangent : TEXCOORD4;
                float4 screenPos : TEXCOORD5;
                half fogFactor :TEXCOORD6;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            // TEXTURE2D(_RampMap);
            // SAMPLER(sampler_RampMap);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            TEXTURE2D(_NoiseMap);
            SAMPLER(sampler_NoiseMap);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);


            v2f vert(a2v inside)
            {
                v2f o;

                // VertexPositionInputs vertexInput = GetVertexPositionInputs(inside.vertex.xyz);

                o.pos = TransformObjectToHClip(inside.vertex.xyz);

                o.worldNormal = TransformObjectToWorldNormal(inside.normal);
                o.worldPos = TransformObjectToWorld(inside.vertex.xyz);
                o.worldTangent = TransformObjectToWorldDir(inside.tangent.xyz);
                

                //cul bitangent
                o.worlBbitangent = normalize(cross(o.worldNormal,o.worldTangent) * inside.tangent.w);
                

                // o.uv = TRANSFORM_TEX(inside.texcoord, _RampMap);
                o.uv = TRANSFORM_TEX(inside.texcoord, _MainTex);
                o.uv = TRANSFORM_TEX(inside.texcoord, _NormalMap);

                //for depth tex
                o.screenPos = ComputeScreenPos(o.pos);

                //fog
                o.fogFactor = ComputeFogFactor(o.pos.z); 

                return o;
            };

            //define remap function
            half remap(half x , half t1, half t2, half s1, half s2){
                
                // if(x=0){return x;}
                return (x-t1)/(t2-t1)*(s2-s1) +s1;
        
            }


            float4 frag(v2f inside) : SV_TARGET
            {
                
                //diffuse color
                float4 diffuseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, inside.uv);
                clip(diffuseColor.a - _Cutoff);

                //initialize lighting struct
                Light mlight = GetMainLight();
                // half3 lightDebug = {_LightDebug.xyz}; 
                half4 lightColor = half4(mlight.color,0);

                //normal map
                float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap, inside.uv);
                float3 bump = UnpackNormalScale(normalMap, _NormalScale);
                inside.worldNormal = TransformTangentToWorld(bump, half3x3(inside.worldTangent, inside.worlBbitangent,inside.worldNormal));

                //lambert
                float Lambert = dot(mlight.direction, inside.worldNormal) * 0.5 + _Darkness;

                // float4 rampColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, inside.uv) ;

                


                float4 remapLambert =Lambert;
                if(Lambert < 0 ){
                    remapLambert = saturate(remap(Lambert, _Remap.x,_Remap.y,_Remap.z,_Remap.w));
                }

               
                // return testingColor;
                
                //Phong

                half3 lightDir = normalize(saturate(mlight.direction));
                half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - inside.worldPos);
                half3 reflectDir  = normalize(reflect(lightDir, inside.worldNormal));

                float phong = pow(saturate(dot(viewDir,-reflectDir)),_Glossness);

                //phong product worldNormal
                half4 normalColor = 0;
                normalColor = half4(inside.worldNormal,1);
                // half4 specular=0;
                // specular *= pow(normalColor.g,1);
                
                half4 phongSpecular = phong * _SpecColor * lightColor *_SpecPower;


                //blin-phong
                //cul bisector
                half3 bisector = normalize(lightDir + viewDir);
                float blinPhone = pow(saturate(dot(bisector, -reflectDir)),_Glossness);
                half4 blinPhoneSpec = blinPhone * _SpecColor *lightColor *_SpecPower;

                //Anistropy
                //set noise
                float4 noiseMap = SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap,inside.uv);
                float3 ShiftT = inside.worlBbitangent + inside.worldNormal * noiseMap * _NoisePower;

                float dotTH = dot(ShiftT,viewDir);
                float sinTH = sqrt(1.0 - dotTH *dotTH);
                float dirAtten = smoothstep(1.0, 0.0, dotTH);
                float finalDirAtten = dirAtten*pow(sinTH,200);
                //fresnel 
                half4 fresnelAnis = finalDirAtten * pow(( saturate(dot(inside.worldNormal, viewDir))),_FrenelPower);


                half4 anistropy = fresnelAnis * _AnisotropyColor *_AnisotropyPower *lightColor;


                // depth tex
                float2 scrPos = inside.screenPos.xy / inside.screenPos.w;
                float depthTex = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, scrPos).r;
                float LinearDepth = LinearEyeDepth(depthTex, _ZBufferParams);
                float a = saturate(LinearDepth);

                // float4 depthCol = saturate((LinearDepth - inside.screenPos.w)/_SoftDepth);
                // float4 depthCol2 = lerp(-100,100,(LinearDepth - inside.screenPos.w));


                // float4 depwithbase = _BaseColor * (1-depthCol2);

                //final blend colors
                float4 finalColorPhong = saturate((anistropy)*(1-a) + _BaseColor * remapLambert * float4(mlight.color, 1) * diffuseColor +phongSpecular);
                float4 finalColorBlin = anistropy + _BaseColor * remapLambert * float4(mlight.color, 1) * diffuseColor +blinPhoneSpec;

                //Mix with fog
                float3 diffuseColorFog;
                diffuseColorFog = MixFog(finalColorPhong.xyz, inside.fogFactor);

          

                // if(lightDir = 0){return 0;}
                return  float4(diffuseColorFog, finalColorPhong.a);
                // return phongSpecular *(1-LinearDepth);
            };



            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        
    }
}

