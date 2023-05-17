Shader "ZKFShader/URPOutLine"
{
	//属性
	Properties{
		_OutlineCol("OutlineCol", Color) = (1,0,0,1)
		_OutlineFactor("OutlineFactor", Range(0,0.05)) = 0.0025    //0.005
	}

	//子着色器	
	SubShader
	{
		//让渲染队列靠后，并且渲染顺序为从后向前，保证描边效果不被其他对象遮挡。
		Tags{"Queue" = "Transparent" "IgnoreProjector"="True" "RenderType"="Transparent + 1" }
		//描边使用两个Pass，第一个pass沿法线挤出一点，只输出描边的颜色

		Pass
		{
			Name "OutLine"
			//剔除正面，只渲染背面
			Cull Front
			//ZWrite Off      //深度写入  Off关闭后，描边就没有交错线了

			HLSLPROGRAM
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#pragma vertex vert
            #pragma fragment frag

            CBUFFER_START(UnityPerMaterial)
			float4 _OutlineCol;
			float _OutlineFactor;
			CBUFFER_END
			

			struct appdata
            {
                float4 vertex : POSITION;
				float4 normal : NORMAL;

            };
			struct v2f
			{
				float4 pos : SV_POSITION;
			};

			v2f vert(appdata v)
			{
				v2f o;

				float4 upPos = float4(v.vertex.xyz + (v.normal.xyz * _OutlineFactor), v.vertex.w);
				//o.pos = mul(UNITY_MATRIX_MVP, upPos);     //这个报过时  	//o.pos = UnityObjectToClipPos(upPos);  //这个CG库
				float3 worldPos = mul(unity_ObjectToWorld , upPos).xyz;
				o.pos = TransformWorldToHClip(worldPos);

				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				//这个Pass直接输出描边颜色
				return _OutlineCol;
			}
			ENDHLSL
		}
	}
	FallBack "Hidden/Shader Graph/FallbackError" 
}
