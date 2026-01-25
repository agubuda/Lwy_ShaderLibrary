Shader "LwyShaders/HairShadowSystem/Caster"
{
    Properties
    {
        _ShadowOffsetScale ("Shadow Offset Scale", Float) = 0.01
        _StencilRef ("Stencil Ref ID", Int) = 128
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry+10" "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            Name "HairShadowCaster"
            Tags { "LightMode" = "UniversalForward" }

            // 核心配置：只写 Stencil，不写颜色，不写深度（防止遮挡脸部）
            ColorMask 0
            ZWrite Off
            ZTest LEqual // 只有在脸前面的头发才投影
            Cull Back

            Stencil
            {
                Ref [_StencilRef]
                Comp Always
                Pass Replace
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
                float _ShadowOffsetScale;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output;
                
                // 1. 获取世界坐标
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                
                // 2. 获取主光方向
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);
                
                // 3. 计算偏移 (世界空间)
                // 简单的沿光线方向推挤
                // 为了让阴影贴在脸上，我们需要把顶点往“后”推（沿光线方向）
                // 这里的逻辑可以优化：你提供的参考代码是在 View Space 做的偏移，
                // 但 World Space 偏移其实更符合直觉。
                // 参考代码: positionVS.x -= ... lightDirVS.x
                
                // 我们实现一个简化的 World Space 投影：
                // 把顶点沿着光线方向推一段距离。
                // 实际上，这不仅仅是推，还需要“压扁”到脸的表面。
                // 但作为一个简单的 Trick，直接偏移通常足够。
                
                // 引入相机修正：从头顶看时，阴影应该很少
                float3 viewDir = normalize(_WorldSpaceCameraPos - positionWS);
                // float camFactor = saturate(dot(viewDir, float3(0,1,0))); // 越垂直向下，值越大
                // 也可以用 Object Space 的 View Dir，如你参考代码所示
                
                // 简单实现：直接偏移
                float3 shadowPosWS = positionWS - lightDir * _ShadowOffsetScale;
                
                output.positionCS = TransformWorldToHClip(shadowPosWS);
                return output;
            }

            half4 frag(Varyings input) : SV_TARGET
            {
                return 0;
            }
            ENDHLSL
        }
    }
}