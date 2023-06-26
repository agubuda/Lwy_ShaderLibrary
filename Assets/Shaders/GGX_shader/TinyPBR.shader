//processing, not finished.

Shader "LwyShaders/TinyPBR"
{
    Properties
    {
        _BaseMap ("Albedo", 2D) = "white" { }
        [MainColor] _BaseColor ("BaseColor", color) = (1.0, 1.0, 1.0, 1.0)
        [Space(20)]

        _Roughness ("Roughness", Range(0.01, 1)) = 0
        _Metallic ("Metallic", Range(0, 1)) = 1
        [Toggle(_ENABLE_MASK_MAP)] _ENABLE_MASK_MAP ("Enable Mask Map", float) = 0.0
        _MaskMap ("Mask map", 2D) = "white" { }

        [Space(20)]
        [Normal]_NormalMap ("Normal map", 2D) = "bump" { }
        _NormalScale ("Normal scale", float) = 1

        // [Space(20)]
        // _DNormalization ("UE=>Unity factor", Range(0.318309891613572,1)) = 0.318309891613572
    }
    SubShader
    {
        Tags { "Queue" = "Geometry" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _GLOSSINESS_FROM_BASE_ALPHA

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/SimpleLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _GLOSSINESS_FROM_BASE_ALPHA

            // -------------------------------------
            // Universal Pipeline keywords

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/SimpleLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        pass
        {
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Name "TinyPBR"

            ZWrite On
            ZTest LEqual
            Cull back

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex vert
            #pragma fragment frag

            // #pragma multi_compile _fog
            // #pragma multi_compile  _MAIN_LIGHT_SHADOWS
            // #pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
            // #pragma multi_compile  _SHADOWS_SOFT

            // #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            // #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION

            // #define  _fog
            #define  _MAIN_LIGHT_SHADOWS
            #define  _MAIN_LIGHT_SHADOWS_CASCADE
            #define  _SHADOWS_SOFT

            // #define _REFLECTION_PROBE_BLENDING
            #define _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma shader_feature _ENABLE_MASK_MAP

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseMap_ST;
                // half4 _MainTex_ST;
                half4 _NormalMap_ST;
                half4 _MaskMap_ST;
                half4 _BaseColor;
                half _Metallic, _Roughness;
                // half _SpecularPower;
                half _NormalScale;
                // half _DNormalization;
            CBUFFER_END

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MaskMap);SAMPLER(sampler_MaskMap);
            
            #include "Assets/Shaders/GGX_shader/tinyForwardPass.hlsl"

            ENDHLSL
        }
        
    }
    FallBack "SimpleLit"
}
