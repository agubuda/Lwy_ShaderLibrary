Shader "LwyShaders/FurShader"
{
    Properties
    {
        _MainTex("Albedo", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _HgihtMap ("_HgihtMap", 2D) = "white" {}
        _Alpha("_Alpha", Range(0,1)) = 0.5
        // _Glossiness ("Smoothness", Range(0,1)) = 0.5
        // _Metallic ("Metallic", Range(0,1)) = 0.0
        _Height ("Height", Range(0,1)) = 1

        _HeightAmount ("_HeightAmount", Range(0,2)) = 1
        _HeightTileSpeed("Turbulence Tile&Speed",Vector) = (1.0,1.0,0.05,0.0)

        _FixedLightDir("_FixedLightDir", vector) = (1,1,1,1)
    }
    SubShader
    {

        pass{

        Tags 
			{
                "LightMode"="ForwardBase"
            }

        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off


        HLSLPROGRAM

        #include "UnityCG.cginc"
        #include "AutoLight.cginc"
        #include "Lighting.cginc"

        
        #pragma multi_compile_fwdbase
        #pragma target 3.0

        sampler2D _HgihtMap;
        sampler2D _MainTex;
        float4 _HgihtMap_ST , _MainTex_ST;

        half4 _Color;
        half _Height, _HeightAmount, _Alpha ;
        half4 _FixedLightDir , _HeightTileSpeed;

        #pragma vertex vert
        #pragma fragment frag

        // struct a2v{
        //     float4 positionOS : POSITION;
        //     float3 normalOS : NORMAL;
        //     float4 uv : TEXCOORD;
        // };


        struct v2f{
            float4 positionCS : SV_POSITION;
            float4 positionWS : TEXCOORD2;
            float3 positionVS: TEXCOORD1;
            float2 uv : TEXCOORD0;
            float2 uv2 : TEXCOORD3;
            float2 uv3 : TEXCOORD7;
            float3 normalWS: TEXCOORD4;
            float3 ViewDir: TEXCOORD5;
            float4 color: TEXCOORD6;

        };
        


        v2f vert(appdata_full v){
            v2f o;
            
                o.positionCS = UnityObjectToClipPos(v.vertex);
                o.uv3 = TRANSFORM_TEX(v.texcoord, _MainTex) + frac(_SinTime.y* _HeightTileSpeed.zw);
                o.uv = TRANSFORM_TEX(v.texcoord,_HgihtMap);
                o.uv2 = v.texcoord, _HeightTileSpeed.xy;
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                o.positionWS = mul(unity_ObjectToWorld, v.vertex);
                TANGENT_SPACE_ROTATION;
                o.ViewDir = mul(rotation, ObjSpaceViewDir(v.vertex));
                o.color = v.color;
                // o.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                // o.normalWS = TransformObjectToWorldNormal(input.normalOS.xyz);

            return o;

        }


        half4 frag(v2f input):COLOR{

            float3 viewRay = normalize(input.ViewDir *- 1);
            viewRay.z = abs(viewRay.z) + 0.2;
            viewRay.xy *= _Height;

            float3 shadeP = float3(input.uv, 0 );
            float3 shadeP2 = float3(input.uv2, 0 );

            float linearStep = 16;

            float4 T = tex2D(_HgihtMap, shadeP2.xy);
            float h2  = T.a * _HeightAmount;

            float3 lioffset = viewRay / (viewRay.z * linearStep);
            float d = 1.0 -tex2Dlod(_HgihtMap, float4(shadeP.xy, 0, 0)).a * h2;

            float3 prev_d = d;
            float3 prev_shadeP = shadeP;
            while(d > shadeP.z){
                prev_shadeP = shadeP;
                shadeP += lioffset;
                prev_d = d;
                d= 1.0 - tex2Dlod(_HgihtMap, float4(shadeP.xy, 0, 0)).a*h2;
            }

            float d1 = d - shadeP.z;
            float d2 = prev_d - prev_shadeP.z;
            float w = d1/(d1 -d2);
            shadeP = lerp(shadeP, prev_shadeP,w);

            half4 c = tex2D(_HgihtMap, shadeP.xy) * T * _Color ;
            half Alpha = lerp(c.a, 1.0, _Alpha) * input.color.r;

            half4 a = tex2D(_MainTex,shadeP.xy) ;

            //light
            float3 normal = normalize(input.normalWS);
            // float3 lightDir = normalize(_FixedLightDir);
            float3 lightDir = UnityWorldSpaceLightDir(input.positionWS);
            float NdotL = max(0,dot(normal, lightDir));


            // half4 diffuse = tex2D(_HgihtMap,input.uv);
            float4 diffuse = tex2D(_MainTex, shadeP.xy);
            half3 lightColor = _LightColor0.rgb;
            
            // half4 o = (1,1,1,1);

            return diffuse;

            // float3 viewRay=normalize(input.ViewDir *-1);
			// 	viewRay.z=abs(viewRay.z)+0.2;
			// 	viewRay.xy *= _Height;

			// 	float3 shadeP = float3(input.uv,0);
			// 	float3 shadeP2 = float3(input.uv2,0);


			// 	float linearStep = 16;

			// 	float4 T = tex2D(_MainTex, shadeP2.xy);
			// 	float h2 = T.a * _HeightAmount;

			// 	float3 lioffset = viewRay / (viewRay.z * linearStep);
			// 	float d = 1.0 - tex2Dlod(_MainTex, float4(shadeP.xy,0,0)).a * h2;
			// 	float3 prev_d = d;
			// 	float3 prev_shadeP = shadeP;
			// 	while(d > shadeP.z)
			// 	{
			// 		prev_shadeP = shadeP;
			// 		shadeP += lioffset;
			// 		prev_d = d;
			// 		d = 1.0 - tex2Dlod(_MainTex, float4(shadeP.xy,0,0)).a * h2;
			// 	}
			// 	float d1 = d - shadeP.z;
			// 	float d2 = prev_d - prev_shadeP.z;
			// 	float w = d1 / (d1 - d2);
			// 	shadeP = lerp(shadeP, prev_shadeP, w);

			// 	half4 c = tex2D(_MainTex,shadeP.xy) * T * _Color;
			// 	half Alpha = lerp(c.a, 1.0, _Alpha) * input.color.r;

			// 	float3 normal = normalize(input.normalWS);
			// 	half3 lightDir1 = normalize(_FixedLightDir.xyz);
			// 	half3 lightDir2 = UnityWorldSpaceLightDir(input.positionWS);
			// 	half3 lightDir = lerp(lightDir2, lightDir1, 1);
			// 	float NdotL = max(0,dot(normal,lightDir));
			// 	half3 lightColor = _LightColor0.rgb;
            //     fixed3 finalColor = c.rgb*(NdotL*lightColor + 1.0);
            //     return c ;
        }

        ENDHLSL
        }
    }
    FallBack "Diffuse"
}
