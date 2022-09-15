Shader "LwyShaders/FurShader_multipass"
{
    Properties
    {
        _MainTex ("Albedo", 2D) = "white" { }
        _Color ("Color", Color) = (1, 1, 1, 1)
        _RimColor ("Rim Color", Color) = (1, 1, 1, 1)
        _RimRange ("_RimRange", Range(0, 10)) = 1
        _FurMask ("_FurMask", 2D) = "white" { }
        _FurTex ("_FurTex", 2D) = "white" { }
        _FurTex2 ("_FurTex2", 2D) = "white" { }
        _MixPower("_MixPower", Range(0,2)) = 1
        _RampMap ("_RampMap", 2D) = "white" { }
        _Alpha ("_Alpha", Range(0, 1)) = 0.5
        // _Clip ("_Clip", Range(0, 1)) = 0.5

        _FurLength ("_FurLength", Range(0, 1)) = 1
        STEP ("STEP", float) = 0
        _Gravity ("_Gravity", vector) = (0, -1, 0, 0)
        _GravityStrength ("_GravityStrength", Range(-20, 20)) = 1
        _WindSpeed ("_WindSpeed", Range(0, 10)) = 1
        _Wind ("_Wind", Range(0, 10)) = 1
        _FurAOInstensity ("_FurAOInstensity", Range(0, 1)) = 1
        // _Thinkness ("_Thinkness", Range(0, 100)) = 1

        [Space(20)]
        _Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.5 // how "thick"
        _CutoffEnd ("Alpha Cutoff end", Range(0, 1)) = 0.5 // how thick they are at the end
        [Space(20)]
        _fresnelPower ("_fresnelPower", float) = 1
        _EdgeFade ("_EdgeFade", float) = 1
        [Space(20)]
        _SrcBlend ("__src", Float) = 1.0
        _DstBlend ("__dst", Float) = 0.0
        _ZWrite ("__ZW", Float) = 1.0
    }
    SubShader
    {
        Name "FORWARD"
        Tags { "LightMode" = "ForwardBase" "Queue" = "Transparent" "RenderType" = "Transparent" }
        
        Blend[_SrcBlend][_DstBlend]
        ZWrite[_ZWrite]

        // Blend SrcAlpha OneMinusSrcAlpha

        CGINCLUDE

        // #pragma target 3.0

        sampler2D _HgihtMap;
        sampler2D _MainTex;
        sampler2D _FurTex;
        sampler2D _FurMask;
        sampler2D _NoiseMap;
        sampler2D _RampMap;
        sampler2D _FurTex2;
        float4 _HgihtMap_ST, _MainTex_ST, _FurTex_ST, _NoiseMap_ST, _RampMap_ST, _FurMask_ST, _FurTex2_ST;

        half4 _Color, _Gravity, _RimColor;
        half _MixPower, _RimRange, _EdgeFade, _fresnelPower, _SrcBlend, _DstBlend, _CutoffEnd, _Cutoff, _Height, _GravityStrength, _Alpha, _FurLength, STEP, _WindSpeed, _Wind, _FurAOInstensity;
        
        #pragma multi_compile_fwdbase
        #pragma vertex vert
        #pragma fragment frag

        ENDCG
        
        pass
        {

            CGPROGRAM
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"

            
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 positionWS : TEXCOORD2;
                float3 positionVS : TEXCOORD1;
                float4 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD3;
                float2 uv3 : TEXCOORD7;
                float3 normalWS : TEXCOORD4;
                float3 ViewDir : TEXCOORD5;
                float4 color : TEXCOORD6;
            };

            #define STEP 0

            v2f vert(appdata_full v)
            {
                v2f o;

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                // o.uv2.xy = TRANSFORM_TEX(v.texcoord, _FurTex);
                float znormal = 1 - dot(v.normal, float3(0, 0, 1));

                o.uv.zw = float2(znormal, znormal) * 0.001;
                
                o.normalWS = mul(v.normal, (float3x3)unity_WorldToObject);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv.xy) * _Color;

                fixed3 lightDir = normalize(_WorldSpaceLightPos0);

                fixed Lambert = (max(0, dot(normalize(i.normalWS), lightDir)) * 0.5 + 0.5);
                fixed3 Ramp = tex2D(_RampMap, fixed2(Lambert, Lambert));
                // float alpha = tex2D(_FurTex, i.uv.xy * ).r;
                // col.rgb *= (alpha * STEP * _FurAOInstensity + 0.7);
                // alpha = step(lerp(_Cutoff, _CutoffEnd, STEP), alpha);
                // col.a = 1 - STEP * STEP;
                // col.a += max(0, col.a);
                // col.a *= alpha;
                // clip(furTex - _Clip);
                // col.rgb -= 0.2 * alpha;

                return float4(col.rgb * Ramp, 1);
                // return alpha;

            }
            ENDCG
        }
        
        // pass
        // {
        //     Name "FORWARD"
        //     // Tags { "LightMode" = "ForwardBase" "Queue"="Transparent" "RenderType" = "Transparent" }
        
        //     // Blend SrcAlpha OneMinusSrcAlpha
        //     ZWrite[_ZWrite]

        //     CGPROGRAM
        


        //     struct v2f
        //     {
        //         float4 vertex : SV_POSITION;
        //         float4 positionWS : TEXCOORD2;
        //         float3 positionVS : TEXCOORD1;
        //         float4 uv : TEXCOORD0;
        //         float2 uv2 : TEXCOORD3;
        //         float2 uv3 : TEXCOORD7;
        //         float3 normalWS : TEXCOORD4;
        //         float3 ViewDir : TEXCOORD5;
        //         float4 color : TEXCOORD6;
        //     };

        //     #define STEP 0.0
        //     #include "fur.cginc"

        //     ENDCG
        // }

        pass
        {


            CGPROGRAM
            


            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 positionWS : TEXCOORD2;
                float3 positionVS : TEXCOORD1;
                float4 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD3;
                float2 uv3 : TEXCOORD7;
                float3 normalWS : TEXCOORD4;
                float3 ViewDir : TEXCOORD5;
                float4 color : TEXCOORD6;
            };

            #define STEP 0.1
            #include "fur.cginc"

            ENDCG
        }
        
        pass
        {


            CGPROGRAM
            


            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 positionWS : TEXCOORD2;
                float3 positionVS : TEXCOORD1;
                float4 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD3;
                float2 uv3 : TEXCOORD7;
                float3 normalWS : TEXCOORD4;
                float3 ViewDir : TEXCOORD5;
                float4 color : TEXCOORD6;
            };

            #define STEP 0.2

            #include "fur.cginc"

            ENDCG
        }

        pass
        {


            CGPROGRAM
            
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 positionWS : TEXCOORD2;
                float3 positionVS : TEXCOORD1;
                float4 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD3;
                float2 uv3 : TEXCOORD7;
                float3 normalWS : TEXCOORD4;
                float3 ViewDir : TEXCOORD5;
                float4 color : TEXCOORD6;
            };

            #define STEP 0.3
            #include "fur.cginc"

            ENDCG
        }

        pass
        {


            CGPROGRAM
            
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 positionWS : TEXCOORD2;
                float3 positionVS : TEXCOORD1;
                float4 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD3;
                float2 uv3 : TEXCOORD7;
                float3 normalWS : TEXCOORD4;
                float3 ViewDir : TEXCOORD5;
                float4 color : TEXCOORD6;
            };

            #define STEP 0.4
            #include "fur.cginc"

            ENDCG
        }

        pass
        {



            CGPROGRAM
            
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 positionWS : TEXCOORD2;
                float3 positionVS : TEXCOORD1;
                float4 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD3;
                float2 uv3 : TEXCOORD7;
                float3 normalWS : TEXCOORD4;
                float3 ViewDir : TEXCOORD5;
                float4 color : TEXCOORD6;
            };

            #define STEP 0.5
            #include "fur.cginc"

            ENDCG
        }

        pass
        {


            CGPROGRAM
            
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 positionWS : TEXCOORD2;
                float3 positionVS : TEXCOORD1;
                float4 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD3;
                float2 uv3 : TEXCOORD7;
                float3 normalWS : TEXCOORD4;
                float3 ViewDir : TEXCOORD5;
                float4 color : TEXCOORD6;
            };

            #define STEP 0.6
            #include "fur.cginc"

            ENDCG
        }
        
        pass
        {


            CGPROGRAM
            
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 positionWS : TEXCOORD2;
                float3 positionVS : TEXCOORD1;
                float4 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD3;
                float2 uv3 : TEXCOORD7;
                float3 normalWS : TEXCOORD4;
                float3 ViewDir : TEXCOORD5;
                float4 color : TEXCOORD6;
            };

            #define STEP 0.7
            #include "fur.cginc"

            ENDCG
        }
        
        pass
        {


            CGPROGRAM
            
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 positionWS : TEXCOORD2;
                float3 positionVS : TEXCOORD1;
                float4 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD3;
                float2 uv3 : TEXCOORD7;
                float3 normalWS : TEXCOORD4;
                float3 ViewDir : TEXCOORD5;
                float4 color : TEXCOORD6;
            };

            #define STEP 0.8
            #include "fur.cginc"

            ENDCG
        }

        pass
        {


            CGPROGRAM
            
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 positionWS : TEXCOORD2;
                float3 positionVS : TEXCOORD1;
                float4 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD3;
                float2 uv3 : TEXCOORD7;
                float3 normalWS : TEXCOORD4;
                float3 ViewDir : TEXCOORD5;
                float4 color : TEXCOORD6;
            };

            #define STEP 0.9
            #include "fur.cginc"

            ENDCG
        }
        
        pass
        {


            CGPROGRAM
            
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 positionWS : TEXCOORD2;
                float3 positionVS : TEXCOORD1;
                float4 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD3;
                float2 uv3 : TEXCOORD7;
                float3 normalWS : TEXCOORD4;
                float3 ViewDir : TEXCOORD5;
                float4 color : TEXCOORD6;
            };

            #define STEP 1
            #include "fur.cginc"

            ENDCG
        }

        // FallBack "Diffuse"

    }
}