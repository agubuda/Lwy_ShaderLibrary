Shader "Universal Render Pipeline/CRLuo/CRLuo_Particle_Alpha_uv"

{
	//面板属性
	Properties
	{
		[Toggle(_UVOne_Key)] _UVOne_Key("曲线动画开关",Float) = 0


		//基础颜色
		[HDR]_Color0("基础颜色", Color) = (1,1,1,1)
		//纹理贴图
		_Texture("主贴图", 2D) = "white" {}
		_U_speed("U_speed", Float) = 0
		_V_speed("V_speed", Float) = 0
		_Mask_tex("噪波贴图01", 2D) = "white" {}
		_Mask_U_speed("Mask_U_speed", Float) = 0
		_Mask_V_speed("Mask_V_speed", Float) = 0
		_Mask_tex_02("噪波贴图02", 2D) = "white" {}
		_Mask_02_U_speed("Mask_02_U_speed", Float) = 0
		_Mask_02_V_speed("Mask_02_V_speed", Float) = 0
		[NoScaleOffset]_zhezhao("遮罩贴图", 2D) = "white" {}
		_Disslove_Tex("溶解贴图", 2D) = "white" {}
		_Disslove_U_speed("Disslove_U_speed", Float) = 0
		_Disslove_V_speed("Disslove_V_speed", Float) = 0
		_Disslove_Line("溶解柔化值", Float) = 0
		_DissloveCutoff("剔除强度", Float) = 0
			//[NoScaleOffset] 隐藏贴图重复与偏移面板

	}
		SubShader
		{
			//渲染类型为URP
		   Tags {"Queue" = "Transparent"  "RenderType" = "Transparent"  "RenderPipeline" = "UniversalRenderPipeline"}
		   //多距离级别
		   LOD 100

		 Cull OFF
		Pass
	   {
	   Blend SrcAlpha OneMinusSrcAlpha
	   ZWrite Off
		   HLSLPROGRAM  //URP 程序块开始

		   //顶点程序片段 vert
		   #pragma vertex vert

		   //表面程序片段 frag
		   #pragma fragment frag

		   //URP函数库
		   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			#pragma shader_feature _UVOne_Key

		   CBUFFER_START(UnityPerMaterial) //变量引入开始

			   //获取属性面板颜色
			   float4 _Color0;
			   float4 _Texture_ST;
			   float4 _Mask_tex_ST;
			   float4 _Mask_tex_02_ST;
			   float _DissloveCutoff;
			   float4 _Disslove_Tex_ST;
			   float _U_speed;
			   float _V_speed;
			   float _Mask_U_speed;
			   float _Mask_V_speed;
			   float _Mask_02_U_speed;
			   float _Mask_02_V_speed;
			   float _Disslove_Line;
			   float _Disslove_U_speed;
			   float _Disslove_V_speed;






	CBUFFER_END //变量引入结束


	//获取面板纹理
	TEXTURE2D(_Texture);
	//获取贴图的偏移与重复
	SAMPLER(sampler_Texture);
	//获取面板纹理
	TEXTURE2D(_Mask_tex);
	//获取贴图的偏移与重复
	SAMPLER(sampler_Mask_tex);
	//获取面板纹理
	TEXTURE2D(_Mask_tex_02);
	//获取贴图的偏移与重复
	SAMPLER(sampler_Mask_tex_02);
	//获取面板纹理
	TEXTURE2D(_zhezhao);
	//获取贴图的偏移与重复
	SAMPLER(sampler_zhezhao);
	TEXTURE2D(_Disslove_Tex);
	//获取贴图的偏移与重复
	SAMPLER(sampler_Disslove_Tex);



	//定义模型原始数据结构
	struct VertexInput
	{
		//获取物体空间顶点坐标
		float4 position : POSITION;

		//获取模型UV坐标
		float2 uv : TEXCOORD0;
		//获取模型UV坐标
		float4 uv2 : TEXCOORD1;
		//获取模型UV坐标
		float4 vCOLOR : COLOR;

	};


	//定义顶点程序片段与表i面程序片段的传递数据结构
	struct VertexOutput
	{
		//物体视角空间坐标
		 float4 position : SV_POSITION;

		 //UV坐标
		 float2 uv : TEXCOORD0;
		 float4 uv2 : TEXCOORD1;
		 float4 vCOLOR : TEXCOORD2;
	 };


	//顶点程序片段
	VertexOutput vert(VertexInput i)
	{
		//声明输出变量o
		 VertexOutput o;

		 //物体空间顶点转换为摄像机空间顶点
		 o.position = TransformObjectToHClip(i.position.xyz);

		 //传递法线变量
		 o.uv = i.uv;
		 o.uv2 = i.uv2;
		 o.vCOLOR = i.vCOLOR;

		 //输出数据
		 return o;
	 }

	//表面程序片段
	float4 frag(VertexOutput i) : SV_Target
	{
		//获取纹理 = 纹理载入（纹理变量，纹理重复，重新定义二维数据的UV坐标（分别定义x方向与y方向 i.uv.x获取贴图U方向*自定义变量↑_Texture_ST的四维数的第一个变量（重复作用）

		float2 newUV = i.uv * float2(_Texture_ST.x,_Texture_ST.y) + float2(_Texture_ST.z,_Texture_ST.w) + float2(_U_speed,_V_speed)*_Time.y;

#ifdef _UVOne_Key

		newUV += float2(i.uv2.x, i.uv2.y);
#endif




		 float4 mainTex = SAMPLE_TEXTURE2D(_Texture, sampler_Texture, newUV);





		 //float4 mainTex = SAMPLE_TEXTURE2D(_Texture, sampler_Texture, i.uv);
	//                                                                          float2重新定义二维数据的UV坐标
	//                                                                                 uv的U方向*自定义变量的四维数的第一个数值
	//                                                                                 +自定义变量的四维数的z*_Time.y(规定好的时间速度(_Time.y(0.05倍速)))
	//                                                                                  实现重铺加偏移 是乘tilling+offset


		 float4 noise01Tex = SAMPLE_TEXTURE2D(_Mask_tex, sampler_Mask_tex, i.uv*float2(_Mask_tex_ST.x, _Mask_tex_ST.y) + float2(_Mask_tex_ST.z, _Mask_tex_ST.w) + float2(_Mask_U_speed, _Mask_V_speed)*_Time.y);




		 float4 noise02Tex = SAMPLE_TEXTURE2D(_Mask_tex_02, sampler_Mask_tex_02, i.uv*float2(_Mask_tex_02_ST.x, _Mask_tex_02_ST.y) + float2(_Mask_tex_02_ST.z, _Mask_tex_02_ST.w) + float2(_Mask_02_U_speed, _Mask_02_V_speed)*_Time.y);


		 float4 maskTex = SAMPLE_TEXTURE2D(_zhezhao, sampler_zhezhao, i.uv);

		 float4 dissloveTex = SAMPLE_TEXTURE2D(_Disslove_Tex, sampler_Disslove_Tex, i.uv*float2(_Disslove_Tex_ST.x, _Disslove_Tex_ST.y) + float2(_Disslove_Tex_ST.z, _Disslove_Tex_ST.w) + float2(_Disslove_U_speed, _Disslove_V_speed)*_Time.y);


		_Color0 *= mainTex * noise01Tex*noise02Tex*maskTex.r*i.vCOLOR;
	
		_Color0.a *= smoothstep(((_DissloveCutoff) - i.uv2.w), _Disslove_Line, dissloveTex.r);

		//	_Color0.a = maskTex.r;
		   clip(dissloveTex.r - (_DissloveCutoff - i.uv2.w));
		   //输出颜色
		   return  _Color0;
	   }

	   ENDHLSL  //URP 程序块结束

	  }
		}
}
