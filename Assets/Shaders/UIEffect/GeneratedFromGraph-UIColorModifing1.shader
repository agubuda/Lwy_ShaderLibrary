Shader "UIColorModifing1"
{
    Properties
    {
        [NoScaleOffset]_MainTexure("MainTexture", 2D) = "white" {}
        [NoScaleOffset]_MaskTexture("MaskTexture", 2D) = "white" {}
        _Rim_color_shift("Rim color shift", Float) = 0
        _Base_color_Shift("Base color Shift", Float) = 0
        [NoScaleOffset]_AlphaTexture("AlphaTexture", 2D) = "white" {}
        _Color("Color", Color) = (0.5619564, 1, 0, 0)
        [HideInInspector][NoScaleOffset]unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Transparent"
            "UniversalMaterialType" = "Unlit"
            "Queue"="Transparent"
            "ShaderGraphShader"="true"
            "ShaderGraphTargetId"=""
        }
        Pass
        {
            Name "Sprite Unlit"
            Tags
            {
                "LightMode" = "Universal2D"
            }
        
            // Render State
            Cull Off
        Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
        ZTest LEqual
        ZWrite Off
        
            // Debug
            // <None>
        
            // --------------------------------------------------
            // Pass
        
            HLSLPROGRAM
        
            // Pragmas
            #pragma target 2.0
        #pragma exclude_renderers d3d11_9x
        #pragma vertex vert
        #pragma fragment frag
        
            // DotsInstancingOptions: <None>
            // HybridV1InjectedBuiltinProperties: <None>
        
            // Keywords
            #pragma multi_compile_fragment _ DEBUG_DISPLAY
            // GraphKeywords: <None>
        
            // Defines
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define ATTRIBUTES_NEED_TEXCOORD0
            #define ATTRIBUTES_NEED_COLOR
            #define VARYINGS_NEED_POSITION_WS
            #define VARYINGS_NEED_TEXCOORD0
            #define VARYINGS_NEED_COLOR
            #define FEATURES_GRAPH_VERTEX
            /* WARNING: $splice Could not find named fragment 'PassInstancing' */
            #define SHADERPASS SHADERPASS_SPRITEUNLIT
            /* WARNING: $splice Could not find named fragment 'DotsInstancingVars' */
        
            // Includes
            /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPreInclude' */
        
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
        
            // --------------------------------------------------
            // Structs and Packing
        
            /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPrePacking' */
        
            struct Attributes
        {
             float3 positionOS : POSITION;
             float3 normalOS : NORMAL;
             float4 tangentOS : TANGENT;
             float4 uv0 : TEXCOORD0;
             float4 color : COLOR;
            #if UNITY_ANY_INSTANCING_ENABLED
             uint instanceID : INSTANCEID_SEMANTIC;
            #endif
        };
        struct Varyings
        {
             float4 positionCS : SV_POSITION;
             float3 positionWS;
             float4 texCoord0;
             float4 color;
            #if UNITY_ANY_INSTANCING_ENABLED
             uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
             uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
             uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
             FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };
        struct SurfaceDescriptionInputs
        {
             float4 uv0;
        };
        struct VertexDescriptionInputs
        {
             float3 ObjectSpaceNormal;
             float3 ObjectSpaceTangent;
             float3 ObjectSpacePosition;
        };
        struct PackedVaryings
        {
             float4 positionCS : SV_POSITION;
             float3 interp0 : INTERP0;
             float4 interp1 : INTERP1;
             float4 interp2 : INTERP2;
            #if UNITY_ANY_INSTANCING_ENABLED
             uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
             uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
             uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
             FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };
        
            PackedVaryings PackVaryings (Varyings input)
        {
            PackedVaryings output;
            ZERO_INITIALIZE(PackedVaryings, output);
            output.positionCS = input.positionCS;
            output.interp0.xyz =  input.positionWS;
            output.interp1.xyzw =  input.texCoord0;
            output.interp2.xyzw =  input.color;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }
        
        Varyings UnpackVaryings (PackedVaryings input)
        {
            Varyings output;
            output.positionCS = input.positionCS;
            output.positionWS = input.interp0.xyz;
            output.texCoord0 = input.interp1.xyzw;
            output.color = input.interp2.xyzw;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }
        
        
            // --------------------------------------------------
            // Graph
        
            // Graph Properties
            CBUFFER_START(UnityPerMaterial)
        float4 _MainTexure_TexelSize;
        float4 _MaskTexture_TexelSize;
        float _Rim_color_shift;
        float _Base_color_Shift;
        float4 _AlphaTexture_TexelSize;
        float4 _Color;
        CBUFFER_END
        
        // Object and Global properties
        SAMPLER(SamplerState_Linear_Repeat);
        TEXTURE2D(_MainTexure);
        SAMPLER(sampler_MainTexure);
        TEXTURE2D(_MaskTexture);
        SAMPLER(sampler_MaskTexture);
        TEXTURE2D(_AlphaTexture);
        SAMPLER(sampler_AlphaTexture);
        
            // Graph Includes
            // GraphIncludes: <None>
        
            // -- Property used by ScenePickingPass
            #ifdef SCENEPICKINGPASS
            float4 _SelectionID;
            #endif
        
            // -- Properties used by SceneSelectionPass
            #ifdef SCENESELECTIONPASS
            int _ObjectId;
            int _PassValue;
            #endif
        
            // Graph Functions
            
        void Unity_Multiply_float4_float4(float4 A, float4 B, out float4 Out)
        {
            Out = A * B;
        }
        
        void Unity_Hue_Degrees_float(float3 In, float Offset, out float3 Out)
        {
            // RGB to HSV
            float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
            float4 P = lerp(float4(In.bg, K.wz), float4(In.gb, K.xy), step(In.b, In.g));
            float4 Q = lerp(float4(P.xyw, In.r), float4(In.r, P.yzx), step(P.x, In.r));
            float D = Q.x - min(Q.w, Q.y);
            float E = 1e-10;
            float V = (D == 0) ? Q.x : (Q.x + E);
            float3 hsv = float3(abs(Q.z + (Q.w - Q.y)/(6.0 * D + E)), D / (Q.x + E), V);
        
            float hue = hsv.x + Offset / 360;
            hsv.x = (hue < 0)
                    ? hue + 1
                    : (hue > 1)
                        ? hue - 1
                        : hue;
        
            // HSV to RGB
            float4 K2 = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
            float3 P2 = abs(frac(hsv.xxx + K2.xyz) * 6.0 - K2.www);
            Out = hsv.z * lerp(K2.xxx, saturate(P2 - K2.xxx), hsv.y);
        }
        
        void Unity_OneMinus_float4(float4 In, out float4 Out)
        {
            Out = 1 - In;
        }
        
        void Unity_Fraction_float(float In, out float Out)
        {
            Out = frac(In);
        }
        
        void Unity_Hue_Normalized_float(float3 In, float Offset, out float3 Out)
        {
            // RGB to HSV
            float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
            float4 P = lerp(float4(In.bg, K.wz), float4(In.gb, K.xy), step(In.b, In.g));
            float4 Q = lerp(float4(P.xyw, In.r), float4(In.r, P.yzx), step(P.x, In.r));
            float D = Q.x - min(Q.w, Q.y);
            float E = 1e-10;
            float V = (D == 0) ? Q.x : (Q.x + E);
            float3 hsv = float3(abs(Q.z + (Q.w - Q.y)/(6.0 * D + E)), D / (Q.x + E), V);
        
            float hue = hsv.x + Offset;
            hsv.x = (hue < 0)
                    ? hue + 1
                    : (hue > 1)
                        ? hue - 1
                        : hue;
        
            // HSV to RGB
            float4 K2 = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
            float3 P2 = abs(frac(hsv.xxx + K2.xyz) * 6.0 - K2.www);
            Out = hsv.z * lerp(K2.xxx, saturate(P2 - K2.xxx), hsv.y);
        }
        
        void Unity_Add_float3(float3 A, float3 B, out float3 Out)
        {
            Out = A + B;
        }
        
            /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPreVertex' */
        
            // Graph Vertex
            struct VertexDescription
        {
            float3 Position;
            float3 Normal;
            float3 Tangent;
        };
        
        VertexDescription VertexDescriptionFunction(VertexDescriptionInputs IN)
        {
            VertexDescription description = (VertexDescription)0;
            description.Position = IN.ObjectSpacePosition;
            description.Normal = IN.ObjectSpaceNormal;
            description.Tangent = IN.ObjectSpaceTangent;
            return description;
        }
        
            #ifdef FEATURES_GRAPH_VERTEX
        Varyings CustomInterpolatorPassThroughFunc(inout Varyings output, VertexDescription input)
        {
        return output;
        }
        #define CUSTOMINTERPOLATOR_VARYPASSTHROUGH_FUNC
        #endif
        
            // Graph Pixel
            struct SurfaceDescription
        {
            float3 BaseColor;
            float Alpha;
        };
        
        SurfaceDescription SurfaceDescriptionFunction(SurfaceDescriptionInputs IN)
        {
            SurfaceDescription surface = (SurfaceDescription)0;
            UnityTexture2D _Property_8fabc4bcb3b844fea354dd7ac7a32aeb_Out_0 = UnityBuildTexture2DStructNoScale(_MainTexure);
            float4 _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_RGBA_0 = SAMPLE_TEXTURE2D(_Property_8fabc4bcb3b844fea354dd7ac7a32aeb_Out_0.tex, _Property_8fabc4bcb3b844fea354dd7ac7a32aeb_Out_0.samplerstate, _Property_8fabc4bcb3b844fea354dd7ac7a32aeb_Out_0.GetTransformedUV(IN.uv0.xy));
            float _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_R_4 = _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_RGBA_0.r;
            float _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_G_5 = _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_RGBA_0.g;
            float _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_B_6 = _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_RGBA_0.b;
            float _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_A_7 = _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_RGBA_0.a;
            UnityTexture2D _Property_f1cb7ceefa3749a18448b5485a6768fd_Out_0 = UnityBuildTexture2DStructNoScale(_MaskTexture);
            float4 _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_RGBA_0 = SAMPLE_TEXTURE2D(_Property_f1cb7ceefa3749a18448b5485a6768fd_Out_0.tex, _Property_f1cb7ceefa3749a18448b5485a6768fd_Out_0.samplerstate, _Property_f1cb7ceefa3749a18448b5485a6768fd_Out_0.GetTransformedUV(IN.uv0.xy));
            float _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_R_4 = _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_RGBA_0.r;
            float _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_G_5 = _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_RGBA_0.g;
            float _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_B_6 = _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_RGBA_0.b;
            float _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_A_7 = _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_RGBA_0.a;
            float4 _Multiply_6f902fac74144f21a36dd268454558d1_Out_2;
            Unity_Multiply_float4_float4(_SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_RGBA_0, _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_RGBA_0, _Multiply_6f902fac74144f21a36dd268454558d1_Out_2);
            float _Property_0014384bfff745b99820edf47a5bd13c_Out_0 = _Base_color_Shift;
            float3 _Hue_76c7a2fe9bce4f0d807c4f4a89ea71f7_Out_2;
            Unity_Hue_Degrees_float((_Multiply_6f902fac74144f21a36dd268454558d1_Out_2.xyz), _Property_0014384bfff745b99820edf47a5bd13c_Out_0, _Hue_76c7a2fe9bce4f0d807c4f4a89ea71f7_Out_2);
            float4 _OneMinus_7bd6840a1c4a402ba1854ac39fb12254_Out_1;
            Unity_OneMinus_float4(_SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_RGBA_0, _OneMinus_7bd6840a1c4a402ba1854ac39fb12254_Out_1);
            float4 _Multiply_ceb6626815474ccc9e68f5d4bccda5b6_Out_2;
            Unity_Multiply_float4_float4(_SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_RGBA_0, _OneMinus_7bd6840a1c4a402ba1854ac39fb12254_Out_1, _Multiply_ceb6626815474ccc9e68f5d4bccda5b6_Out_2);
            float _Property_5e8c796250cd4aab98165f26868a4046_Out_0 = _Rim_color_shift;
            float _Fraction_b5bcb7141d114649a5c2acb33905e4d6_Out_1;
            Unity_Fraction_float(_Property_5e8c796250cd4aab98165f26868a4046_Out_0, _Fraction_b5bcb7141d114649a5c2acb33905e4d6_Out_1);
            float3 _Hue_8df0df8de8ea43b1a03e01b09d083162_Out_2;
            Unity_Hue_Normalized_float((_Multiply_ceb6626815474ccc9e68f5d4bccda5b6_Out_2.xyz), _Fraction_b5bcb7141d114649a5c2acb33905e4d6_Out_1, _Hue_8df0df8de8ea43b1a03e01b09d083162_Out_2);
            float3 _Add_87a729545d1842edbe0d1dacef1d2bc3_Out_2;
            Unity_Add_float3(_Hue_76c7a2fe9bce4f0d807c4f4a89ea71f7_Out_2, _Hue_8df0df8de8ea43b1a03e01b09d083162_Out_2, _Add_87a729545d1842edbe0d1dacef1d2bc3_Out_2);
            UnityTexture2D _Property_5f740710d06549e08fc3143b9d0c2594_Out_0 = UnityBuildTexture2DStructNoScale(_AlphaTexture);
            float4 _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0 = SAMPLE_TEXTURE2D(_Property_5f740710d06549e08fc3143b9d0c2594_Out_0.tex, _Property_5f740710d06549e08fc3143b9d0c2594_Out_0.samplerstate, _Property_5f740710d06549e08fc3143b9d0c2594_Out_0.GetTransformedUV(IN.uv0.xy));
            float _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_R_4 = _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0.r;
            float _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_G_5 = _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0.g;
            float _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_B_6 = _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0.b;
            float _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_A_7 = _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0.a;
            surface.BaseColor = _Add_87a729545d1842edbe0d1dacef1d2bc3_Out_2;
            surface.Alpha = (_SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0).x;
            return surface;
        }
        
            // --------------------------------------------------
            // Build Graph Inputs
        
            VertexDescriptionInputs BuildVertexDescriptionInputs(Attributes input)
        {
            VertexDescriptionInputs output;
            ZERO_INITIALIZE(VertexDescriptionInputs, output);
        
            output.ObjectSpaceNormal =                          input.normalOS;
            output.ObjectSpaceTangent =                         input.tangentOS.xyz;
            output.ObjectSpacePosition =                        input.positionOS;
        
            return output;
        }
            SurfaceDescriptionInputs BuildSurfaceDescriptionInputs(Varyings input)
        {
            SurfaceDescriptionInputs output;
            ZERO_INITIALIZE(SurfaceDescriptionInputs, output);
        
            
        
        
        
        
        
            output.uv0 =                                        input.texCoord0;
        #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN                output.FaceSign =                                   IS_FRONT_VFACE(input.cullFace, true, false);
        #else
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN
        #endif
        #undef BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN
        
            return output;
        }
        
            // --------------------------------------------------
            // Main
        
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/2D/ShaderGraph/Includes/SpriteUnlitPass.hlsl"
        
            ENDHLSL
        }
        Pass
        {
            Name "SceneSelectionPass"
            Tags
            {
                "LightMode" = "SceneSelectionPass"
            }
        
            // Render State
            Cull Off
        
            // Debug
            // <None>
        
            // --------------------------------------------------
            // Pass
        
            HLSLPROGRAM
        
            // Pragmas
            #pragma target 2.0
        #pragma exclude_renderers d3d11_9x
        #pragma vertex vert
        #pragma fragment frag
        
            // DotsInstancingOptions: <None>
            // HybridV1InjectedBuiltinProperties: <None>
        
            // Keywords
            // PassKeywords: <None>
            // GraphKeywords: <None>
        
            // Defines
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define ATTRIBUTES_NEED_TEXCOORD0
            #define VARYINGS_NEED_TEXCOORD0
            #define FEATURES_GRAPH_VERTEX
            /* WARNING: $splice Could not find named fragment 'PassInstancing' */
            #define SHADERPASS SHADERPASS_DEPTHONLY
        #define SCENESELECTIONPASS 1
        
            /* WARNING: $splice Could not find named fragment 'DotsInstancingVars' */
        
            // Includes
            /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPreInclude' */
        
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
        
            // --------------------------------------------------
            // Structs and Packing
        
            /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPrePacking' */
        
            struct Attributes
        {
             float3 positionOS : POSITION;
             float3 normalOS : NORMAL;
             float4 tangentOS : TANGENT;
             float4 uv0 : TEXCOORD0;
            #if UNITY_ANY_INSTANCING_ENABLED
             uint instanceID : INSTANCEID_SEMANTIC;
            #endif
        };
        struct Varyings
        {
             float4 positionCS : SV_POSITION;
             float4 texCoord0;
            #if UNITY_ANY_INSTANCING_ENABLED
             uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
             uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
             uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
             FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };
        struct SurfaceDescriptionInputs
        {
             float4 uv0;
        };
        struct VertexDescriptionInputs
        {
             float3 ObjectSpaceNormal;
             float3 ObjectSpaceTangent;
             float3 ObjectSpacePosition;
        };
        struct PackedVaryings
        {
             float4 positionCS : SV_POSITION;
             float4 interp0 : INTERP0;
            #if UNITY_ANY_INSTANCING_ENABLED
             uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
             uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
             uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
             FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };
        
            PackedVaryings PackVaryings (Varyings input)
        {
            PackedVaryings output;
            ZERO_INITIALIZE(PackedVaryings, output);
            output.positionCS = input.positionCS;
            output.interp0.xyzw =  input.texCoord0;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }
        
        Varyings UnpackVaryings (PackedVaryings input)
        {
            Varyings output;
            output.positionCS = input.positionCS;
            output.texCoord0 = input.interp0.xyzw;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }
        
        
            // --------------------------------------------------
            // Graph
        
            // Graph Properties
            CBUFFER_START(UnityPerMaterial)
        float4 _MainTexure_TexelSize;
        float4 _MaskTexture_TexelSize;
        float _Rim_color_shift;
        float _Base_color_Shift;
        float4 _AlphaTexture_TexelSize;
        float4 _Color;
        CBUFFER_END
        
        // Object and Global properties
        SAMPLER(SamplerState_Linear_Repeat);
        TEXTURE2D(_MainTexure);
        SAMPLER(sampler_MainTexure);
        TEXTURE2D(_MaskTexture);
        SAMPLER(sampler_MaskTexture);
        TEXTURE2D(_AlphaTexture);
        SAMPLER(sampler_AlphaTexture);
        
            // Graph Includes
            // GraphIncludes: <None>
        
            // -- Property used by ScenePickingPass
            #ifdef SCENEPICKINGPASS
            float4 _SelectionID;
            #endif
        
            // -- Properties used by SceneSelectionPass
            #ifdef SCENESELECTIONPASS
            int _ObjectId;
            int _PassValue;
            #endif
        
            // Graph Functions
            // GraphFunctions: <None>
        
            /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPreVertex' */
        
            // Graph Vertex
            struct VertexDescription
        {
            float3 Position;
            float3 Normal;
            float3 Tangent;
        };
        
        VertexDescription VertexDescriptionFunction(VertexDescriptionInputs IN)
        {
            VertexDescription description = (VertexDescription)0;
            description.Position = IN.ObjectSpacePosition;
            description.Normal = IN.ObjectSpaceNormal;
            description.Tangent = IN.ObjectSpaceTangent;
            return description;
        }
        
            #ifdef FEATURES_GRAPH_VERTEX
        Varyings CustomInterpolatorPassThroughFunc(inout Varyings output, VertexDescription input)
        {
        return output;
        }
        #define CUSTOMINTERPOLATOR_VARYPASSTHROUGH_FUNC
        #endif
        
            // Graph Pixel
            struct SurfaceDescription
        {
            float Alpha;
        };
        
        SurfaceDescription SurfaceDescriptionFunction(SurfaceDescriptionInputs IN)
        {
            SurfaceDescription surface = (SurfaceDescription)0;
            UnityTexture2D _Property_5f740710d06549e08fc3143b9d0c2594_Out_0 = UnityBuildTexture2DStructNoScale(_AlphaTexture);
            float4 _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0 = SAMPLE_TEXTURE2D(_Property_5f740710d06549e08fc3143b9d0c2594_Out_0.tex, _Property_5f740710d06549e08fc3143b9d0c2594_Out_0.samplerstate, _Property_5f740710d06549e08fc3143b9d0c2594_Out_0.GetTransformedUV(IN.uv0.xy));
            float _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_R_4 = _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0.r;
            float _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_G_5 = _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0.g;
            float _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_B_6 = _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0.b;
            float _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_A_7 = _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0.a;
            surface.Alpha = (_SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0).x;
            return surface;
        }
        
            // --------------------------------------------------
            // Build Graph Inputs
        
            VertexDescriptionInputs BuildVertexDescriptionInputs(Attributes input)
        {
            VertexDescriptionInputs output;
            ZERO_INITIALIZE(VertexDescriptionInputs, output);
        
            output.ObjectSpaceNormal =                          input.normalOS;
            output.ObjectSpaceTangent =                         input.tangentOS.xyz;
            output.ObjectSpacePosition =                        input.positionOS;
        
            return output;
        }
            SurfaceDescriptionInputs BuildSurfaceDescriptionInputs(Varyings input)
        {
            SurfaceDescriptionInputs output;
            ZERO_INITIALIZE(SurfaceDescriptionInputs, output);
        
            
        
        
        
        
        
            output.uv0 =                                        input.texCoord0;
        #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN                output.FaceSign =                                   IS_FRONT_VFACE(input.cullFace, true, false);
        #else
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN
        #endif
        #undef BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN
        
            return output;
        }
        
            // --------------------------------------------------
            // Main
        
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/SelectionPickingPass.hlsl"
        
            ENDHLSL
        }
        Pass
        {
            Name "ScenePickingPass"
            Tags
            {
                "LightMode" = "Picking"
            }
        
            // Render State
            Cull Back
        
            // Debug
            // <None>
        
            // --------------------------------------------------
            // Pass
        
            HLSLPROGRAM
        
            // Pragmas
            #pragma target 2.0
        #pragma exclude_renderers d3d11_9x
        #pragma vertex vert
        #pragma fragment frag
        
            // DotsInstancingOptions: <None>
            // HybridV1InjectedBuiltinProperties: <None>
        
            // Keywords
            // PassKeywords: <None>
            // GraphKeywords: <None>
        
            // Defines
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define ATTRIBUTES_NEED_TEXCOORD0
            #define VARYINGS_NEED_TEXCOORD0
            #define FEATURES_GRAPH_VERTEX
            /* WARNING: $splice Could not find named fragment 'PassInstancing' */
            #define SHADERPASS SHADERPASS_DEPTHONLY
        #define SCENEPICKINGPASS 1
        
            /* WARNING: $splice Could not find named fragment 'DotsInstancingVars' */
        
            // Includes
            /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPreInclude' */
        
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
        
            // --------------------------------------------------
            // Structs and Packing
        
            /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPrePacking' */
        
            struct Attributes
        {
             float3 positionOS : POSITION;
             float3 normalOS : NORMAL;
             float4 tangentOS : TANGENT;
             float4 uv0 : TEXCOORD0;
            #if UNITY_ANY_INSTANCING_ENABLED
             uint instanceID : INSTANCEID_SEMANTIC;
            #endif
        };
        struct Varyings
        {
             float4 positionCS : SV_POSITION;
             float4 texCoord0;
            #if UNITY_ANY_INSTANCING_ENABLED
             uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
             uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
             uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
             FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };
        struct SurfaceDescriptionInputs
        {
             float4 uv0;
        };
        struct VertexDescriptionInputs
        {
             float3 ObjectSpaceNormal;
             float3 ObjectSpaceTangent;
             float3 ObjectSpacePosition;
        };
        struct PackedVaryings
        {
             float4 positionCS : SV_POSITION;
             float4 interp0 : INTERP0;
            #if UNITY_ANY_INSTANCING_ENABLED
             uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
             uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
             uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
             FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };
        
            PackedVaryings PackVaryings (Varyings input)
        {
            PackedVaryings output;
            ZERO_INITIALIZE(PackedVaryings, output);
            output.positionCS = input.positionCS;
            output.interp0.xyzw =  input.texCoord0;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }
        
        Varyings UnpackVaryings (PackedVaryings input)
        {
            Varyings output;
            output.positionCS = input.positionCS;
            output.texCoord0 = input.interp0.xyzw;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }
        
        
            // --------------------------------------------------
            // Graph
        
            // Graph Properties
            CBUFFER_START(UnityPerMaterial)
        float4 _MainTexure_TexelSize;
        float4 _MaskTexture_TexelSize;
        float _Rim_color_shift;
        float _Base_color_Shift;
        float4 _AlphaTexture_TexelSize;
        float4 _Color;
        CBUFFER_END
        
        // Object and Global properties
        SAMPLER(SamplerState_Linear_Repeat);
        TEXTURE2D(_MainTexure);
        SAMPLER(sampler_MainTexure);
        TEXTURE2D(_MaskTexture);
        SAMPLER(sampler_MaskTexture);
        TEXTURE2D(_AlphaTexture);
        SAMPLER(sampler_AlphaTexture);
        
            // Graph Includes
            // GraphIncludes: <None>
        
            // -- Property used by ScenePickingPass
            #ifdef SCENEPICKINGPASS
            float4 _SelectionID;
            #endif
        
            // -- Properties used by SceneSelectionPass
            #ifdef SCENESELECTIONPASS
            int _ObjectId;
            int _PassValue;
            #endif
        
            // Graph Functions
            // GraphFunctions: <None>
        
            /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPreVertex' */
        
            // Graph Vertex
            struct VertexDescription
        {
            float3 Position;
            float3 Normal;
            float3 Tangent;
        };
        
        VertexDescription VertexDescriptionFunction(VertexDescriptionInputs IN)
        {
            VertexDescription description = (VertexDescription)0;
            description.Position = IN.ObjectSpacePosition;
            description.Normal = IN.ObjectSpaceNormal;
            description.Tangent = IN.ObjectSpaceTangent;
            return description;
        }
        
            #ifdef FEATURES_GRAPH_VERTEX
        Varyings CustomInterpolatorPassThroughFunc(inout Varyings output, VertexDescription input)
        {
        return output;
        }
        #define CUSTOMINTERPOLATOR_VARYPASSTHROUGH_FUNC
        #endif
        
            // Graph Pixel
            struct SurfaceDescription
        {
            float Alpha;
        };
        
        SurfaceDescription SurfaceDescriptionFunction(SurfaceDescriptionInputs IN)
        {
            SurfaceDescription surface = (SurfaceDescription)0;
            UnityTexture2D _Property_5f740710d06549e08fc3143b9d0c2594_Out_0 = UnityBuildTexture2DStructNoScale(_AlphaTexture);
            float4 _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0 = SAMPLE_TEXTURE2D(_Property_5f740710d06549e08fc3143b9d0c2594_Out_0.tex, _Property_5f740710d06549e08fc3143b9d0c2594_Out_0.samplerstate, _Property_5f740710d06549e08fc3143b9d0c2594_Out_0.GetTransformedUV(IN.uv0.xy));
            float _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_R_4 = _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0.r;
            float _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_G_5 = _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0.g;
            float _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_B_6 = _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0.b;
            float _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_A_7 = _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0.a;
            surface.Alpha = (_SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0).x;
            return surface;
        }
        
            // --------------------------------------------------
            // Build Graph Inputs
        
            VertexDescriptionInputs BuildVertexDescriptionInputs(Attributes input)
        {
            VertexDescriptionInputs output;
            ZERO_INITIALIZE(VertexDescriptionInputs, output);
        
            output.ObjectSpaceNormal =                          input.normalOS;
            output.ObjectSpaceTangent =                         input.tangentOS.xyz;
            output.ObjectSpacePosition =                        input.positionOS;
        
            return output;
        }
            SurfaceDescriptionInputs BuildSurfaceDescriptionInputs(Varyings input)
        {
            SurfaceDescriptionInputs output;
            ZERO_INITIALIZE(SurfaceDescriptionInputs, output);
        
            
        
        
        
        
        
            output.uv0 =                                        input.texCoord0;
        #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN                output.FaceSign =                                   IS_FRONT_VFACE(input.cullFace, true, false);
        #else
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN
        #endif
        #undef BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN
        
            return output;
        }
        
            // --------------------------------------------------
            // Main
        
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/SelectionPickingPass.hlsl"
        
            ENDHLSL
        }
        Pass
        {
            Name "Sprite Unlit"
            Tags
            {
                "LightMode" = "UniversalForward"
            }
        
            // Render State
            Cull Off
        Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
        ZTest LEqual
        ZWrite Off
        
            // Debug
            // <None>
        
            // --------------------------------------------------
            // Pass
        
            HLSLPROGRAM
        
            // Pragmas
            #pragma target 2.0
        #pragma exclude_renderers d3d11_9x
        #pragma vertex vert
        #pragma fragment frag
        
            // DotsInstancingOptions: <None>
            // HybridV1InjectedBuiltinProperties: <None>
        
            // Keywords
            #pragma multi_compile_fragment _ DEBUG_DISPLAY
            // GraphKeywords: <None>
        
            // Defines
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define ATTRIBUTES_NEED_TEXCOORD0
            #define ATTRIBUTES_NEED_COLOR
            #define VARYINGS_NEED_POSITION_WS
            #define VARYINGS_NEED_TEXCOORD0
            #define VARYINGS_NEED_COLOR
            #define FEATURES_GRAPH_VERTEX
            /* WARNING: $splice Could not find named fragment 'PassInstancing' */
            #define SHADERPASS SHADERPASS_SPRITEFORWARD
            /* WARNING: $splice Could not find named fragment 'DotsInstancingVars' */
        
            // Includes
            /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPreInclude' */
        
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
        
            // --------------------------------------------------
            // Structs and Packing
        
            /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPrePacking' */
        
            struct Attributes
        {
             float3 positionOS : POSITION;
             float3 normalOS : NORMAL;
             float4 tangentOS : TANGENT;
             float4 uv0 : TEXCOORD0;
             float4 color : COLOR;
            #if UNITY_ANY_INSTANCING_ENABLED
             uint instanceID : INSTANCEID_SEMANTIC;
            #endif
        };
        struct Varyings
        {
             float4 positionCS : SV_POSITION;
             float3 positionWS;
             float4 texCoord0;
             float4 color;
            #if UNITY_ANY_INSTANCING_ENABLED
             uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
             uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
             uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
             FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };
        struct SurfaceDescriptionInputs
        {
             float4 uv0;
        };
        struct VertexDescriptionInputs
        {
             float3 ObjectSpaceNormal;
             float3 ObjectSpaceTangent;
             float3 ObjectSpacePosition;
        };
        struct PackedVaryings
        {
             float4 positionCS : SV_POSITION;
             float3 interp0 : INTERP0;
             float4 interp1 : INTERP1;
             float4 interp2 : INTERP2;
            #if UNITY_ANY_INSTANCING_ENABLED
             uint instanceID : CUSTOM_INSTANCE_ID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
             uint stereoTargetEyeIndexAsBlendIdx0 : BLENDINDICES0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
             uint stereoTargetEyeIndexAsRTArrayIdx : SV_RenderTargetArrayIndex;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
             FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC;
            #endif
        };
        
            PackedVaryings PackVaryings (Varyings input)
        {
            PackedVaryings output;
            ZERO_INITIALIZE(PackedVaryings, output);
            output.positionCS = input.positionCS;
            output.interp0.xyz =  input.positionWS;
            output.interp1.xyzw =  input.texCoord0;
            output.interp2.xyzw =  input.color;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }
        
        Varyings UnpackVaryings (PackedVaryings input)
        {
            Varyings output;
            output.positionCS = input.positionCS;
            output.positionWS = input.interp0.xyz;
            output.texCoord0 = input.interp1.xyzw;
            output.color = input.interp2.xyzw;
            #if UNITY_ANY_INSTANCING_ENABLED
            output.instanceID = input.instanceID;
            #endif
            #if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
            output.stereoTargetEyeIndexAsBlendIdx0 = input.stereoTargetEyeIndexAsBlendIdx0;
            #endif
            #if (defined(UNITY_STEREO_INSTANCING_ENABLED))
            output.stereoTargetEyeIndexAsRTArrayIdx = input.stereoTargetEyeIndexAsRTArrayIdx;
            #endif
            #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
            output.cullFace = input.cullFace;
            #endif
            return output;
        }
        
        
            // --------------------------------------------------
            // Graph
        
            // Graph Properties
            CBUFFER_START(UnityPerMaterial)
        float4 _MainTexure_TexelSize;
        float4 _MaskTexture_TexelSize;
        float _Rim_color_shift;
        float _Base_color_Shift;
        float4 _AlphaTexture_TexelSize;
        float4 _Color;
        CBUFFER_END
        
        // Object and Global properties
        SAMPLER(SamplerState_Linear_Repeat);
        TEXTURE2D(_MainTexure);
        SAMPLER(sampler_MainTexure);
        TEXTURE2D(_MaskTexture);
        SAMPLER(sampler_MaskTexture);
        TEXTURE2D(_AlphaTexture);
        SAMPLER(sampler_AlphaTexture);
        
            // Graph Includes
            // GraphIncludes: <None>
        
            // -- Property used by ScenePickingPass
            #ifdef SCENEPICKINGPASS
            float4 _SelectionID;
            #endif
        
            // -- Properties used by SceneSelectionPass
            #ifdef SCENESELECTIONPASS
            int _ObjectId;
            int _PassValue;
            #endif
        
            // Graph Functions
            
        void Unity_Multiply_float4_float4(float4 A, float4 B, out float4 Out)
        {
            Out = A * B;
        }
        
        void Unity_Hue_Degrees_float(float3 In, float Offset, out float3 Out)
        {
            // RGB to HSV
            float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
            float4 P = lerp(float4(In.bg, K.wz), float4(In.gb, K.xy), step(In.b, In.g));
            float4 Q = lerp(float4(P.xyw, In.r), float4(In.r, P.yzx), step(P.x, In.r));
            float D = Q.x - min(Q.w, Q.y);
            float E = 1e-10;
            float V = (D == 0) ? Q.x : (Q.x + E);
            float3 hsv = float3(abs(Q.z + (Q.w - Q.y)/(6.0 * D + E)), D / (Q.x + E), V);
        
            float hue = hsv.x + Offset / 360;
            hsv.x = (hue < 0)
                    ? hue + 1
                    : (hue > 1)
                        ? hue - 1
                        : hue;
        
            // HSV to RGB
            float4 K2 = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
            float3 P2 = abs(frac(hsv.xxx + K2.xyz) * 6.0 - K2.www);
            Out = hsv.z * lerp(K2.xxx, saturate(P2 - K2.xxx), hsv.y);
        }
        
        void Unity_OneMinus_float4(float4 In, out float4 Out)
        {
            Out = 1 - In;
        }
        
        void Unity_Fraction_float(float In, out float Out)
        {
            Out = frac(In);
        }
        
        void Unity_Hue_Normalized_float(float3 In, float Offset, out float3 Out)
        {
            // RGB to HSV
            float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
            float4 P = lerp(float4(In.bg, K.wz), float4(In.gb, K.xy), step(In.b, In.g));
            float4 Q = lerp(float4(P.xyw, In.r), float4(In.r, P.yzx), step(P.x, In.r));
            float D = Q.x - min(Q.w, Q.y);
            float E = 1e-10;
            float V = (D == 0) ? Q.x : (Q.x + E);
            float3 hsv = float3(abs(Q.z + (Q.w - Q.y)/(6.0 * D + E)), D / (Q.x + E), V);
        
            float hue = hsv.x + Offset;
            hsv.x = (hue < 0)
                    ? hue + 1
                    : (hue > 1)
                        ? hue - 1
                        : hue;
        
            // HSV to RGB
            float4 K2 = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
            float3 P2 = abs(frac(hsv.xxx + K2.xyz) * 6.0 - K2.www);
            Out = hsv.z * lerp(K2.xxx, saturate(P2 - K2.xxx), hsv.y);
        }
        
        void Unity_Add_float3(float3 A, float3 B, out float3 Out)
        {
            Out = A + B;
        }
        
            /* WARNING: $splice Could not find named fragment 'CustomInterpolatorPreVertex' */
        
            // Graph Vertex
            struct VertexDescription
        {
            float3 Position;
            float3 Normal;
            float3 Tangent;
        };
        
        VertexDescription VertexDescriptionFunction(VertexDescriptionInputs IN)
        {
            VertexDescription description = (VertexDescription)0;
            description.Position = IN.ObjectSpacePosition;
            description.Normal = IN.ObjectSpaceNormal;
            description.Tangent = IN.ObjectSpaceTangent;
            return description;
        }
        
            #ifdef FEATURES_GRAPH_VERTEX
        Varyings CustomInterpolatorPassThroughFunc(inout Varyings output, VertexDescription input)
        {
        return output;
        }
        #define CUSTOMINTERPOLATOR_VARYPASSTHROUGH_FUNC
        #endif
        
            // Graph Pixel
            struct SurfaceDescription
        {
            float3 BaseColor;
            float Alpha;
        };
        
        SurfaceDescription SurfaceDescriptionFunction(SurfaceDescriptionInputs IN)
        {
            SurfaceDescription surface = (SurfaceDescription)0;
            UnityTexture2D _Property_8fabc4bcb3b844fea354dd7ac7a32aeb_Out_0 = UnityBuildTexture2DStructNoScale(_MainTexure);
            float4 _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_RGBA_0 = SAMPLE_TEXTURE2D(_Property_8fabc4bcb3b844fea354dd7ac7a32aeb_Out_0.tex, _Property_8fabc4bcb3b844fea354dd7ac7a32aeb_Out_0.samplerstate, _Property_8fabc4bcb3b844fea354dd7ac7a32aeb_Out_0.GetTransformedUV(IN.uv0.xy));
            float _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_R_4 = _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_RGBA_0.r;
            float _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_G_5 = _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_RGBA_0.g;
            float _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_B_6 = _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_RGBA_0.b;
            float _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_A_7 = _SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_RGBA_0.a;
            UnityTexture2D _Property_f1cb7ceefa3749a18448b5485a6768fd_Out_0 = UnityBuildTexture2DStructNoScale(_MaskTexture);
            float4 _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_RGBA_0 = SAMPLE_TEXTURE2D(_Property_f1cb7ceefa3749a18448b5485a6768fd_Out_0.tex, _Property_f1cb7ceefa3749a18448b5485a6768fd_Out_0.samplerstate, _Property_f1cb7ceefa3749a18448b5485a6768fd_Out_0.GetTransformedUV(IN.uv0.xy));
            float _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_R_4 = _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_RGBA_0.r;
            float _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_G_5 = _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_RGBA_0.g;
            float _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_B_6 = _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_RGBA_0.b;
            float _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_A_7 = _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_RGBA_0.a;
            float4 _Multiply_6f902fac74144f21a36dd268454558d1_Out_2;
            Unity_Multiply_float4_float4(_SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_RGBA_0, _SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_RGBA_0, _Multiply_6f902fac74144f21a36dd268454558d1_Out_2);
            float _Property_0014384bfff745b99820edf47a5bd13c_Out_0 = _Base_color_Shift;
            float3 _Hue_76c7a2fe9bce4f0d807c4f4a89ea71f7_Out_2;
            Unity_Hue_Degrees_float((_Multiply_6f902fac74144f21a36dd268454558d1_Out_2.xyz), _Property_0014384bfff745b99820edf47a5bd13c_Out_0, _Hue_76c7a2fe9bce4f0d807c4f4a89ea71f7_Out_2);
            float4 _OneMinus_7bd6840a1c4a402ba1854ac39fb12254_Out_1;
            Unity_OneMinus_float4(_SampleTexture2D_bfd4efaf96e24496ae8bd8bf15bb6ba8_RGBA_0, _OneMinus_7bd6840a1c4a402ba1854ac39fb12254_Out_1);
            float4 _Multiply_ceb6626815474ccc9e68f5d4bccda5b6_Out_2;
            Unity_Multiply_float4_float4(_SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_RGBA_0, _OneMinus_7bd6840a1c4a402ba1854ac39fb12254_Out_1, _Multiply_ceb6626815474ccc9e68f5d4bccda5b6_Out_2);
            float _Property_5e8c796250cd4aab98165f26868a4046_Out_0 = _Rim_color_shift;
            float _Fraction_b5bcb7141d114649a5c2acb33905e4d6_Out_1;
            Unity_Fraction_float(_Property_5e8c796250cd4aab98165f26868a4046_Out_0, _Fraction_b5bcb7141d114649a5c2acb33905e4d6_Out_1);
            float3 _Hue_8df0df8de8ea43b1a03e01b09d083162_Out_2;
            Unity_Hue_Normalized_float((_Multiply_ceb6626815474ccc9e68f5d4bccda5b6_Out_2.xyz), _Fraction_b5bcb7141d114649a5c2acb33905e4d6_Out_1, _Hue_8df0df8de8ea43b1a03e01b09d083162_Out_2);
            float3 _Add_87a729545d1842edbe0d1dacef1d2bc3_Out_2;
            Unity_Add_float3(_Hue_76c7a2fe9bce4f0d807c4f4a89ea71f7_Out_2, _Hue_8df0df8de8ea43b1a03e01b09d083162_Out_2, _Add_87a729545d1842edbe0d1dacef1d2bc3_Out_2);
            UnityTexture2D _Property_5f740710d06549e08fc3143b9d0c2594_Out_0 = UnityBuildTexture2DStructNoScale(_AlphaTexture);
            float4 _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0 = SAMPLE_TEXTURE2D(_Property_5f740710d06549e08fc3143b9d0c2594_Out_0.tex, _Property_5f740710d06549e08fc3143b9d0c2594_Out_0.samplerstate, _Property_5f740710d06549e08fc3143b9d0c2594_Out_0.GetTransformedUV(IN.uv0.xy));
            float _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_R_4 = _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0.r;
            float _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_G_5 = _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0.g;
            float _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_B_6 = _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0.b;
            float _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_A_7 = _SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0.a;
            surface.BaseColor = _Add_87a729545d1842edbe0d1dacef1d2bc3_Out_2;
            surface.Alpha = (_SampleTexture2D_8c9f8d6027f34598bc3eed3adf511e36_RGBA_0).x;
            clip(_SampleTexture2D_1e98f494a48342aa9c6a2129d1018662_RGBA_0.a - 0.1);
            return surface;
        }
        
            // --------------------------------------------------
            // Build Graph Inputs
        
            VertexDescriptionInputs BuildVertexDescriptionInputs(Attributes input)
        {
            VertexDescriptionInputs output;
            ZERO_INITIALIZE(VertexDescriptionInputs, output);
        
            output.ObjectSpaceNormal =                          input.normalOS;
            output.ObjectSpaceTangent =                         input.tangentOS.xyz;
            output.ObjectSpacePosition =                        input.positionOS;
        
            return output;
        }
            SurfaceDescriptionInputs BuildSurfaceDescriptionInputs(Varyings input)
        {
            SurfaceDescriptionInputs output;
            ZERO_INITIALIZE(SurfaceDescriptionInputs, output);
        
            
        
        
        
        
        
            output.uv0 =                                        input.texCoord0;
        #if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN                output.FaceSign =                                   IS_FRONT_VFACE(input.cullFace, true, false);
        #else
        #define BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN
        #endif
        #undef BUILD_SURFACE_DESCRIPTION_INPUTS_OUTPUT_FACESIGN
        
            return output;
        }
        
            // --------------------------------------------------
            // Main
        
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/Varyings.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Editor/2D/ShaderGraph/Includes/SpriteUnlitPass.hlsl"
        
            ENDHLSL
        }
    }
    CustomEditor "UnityEditor.ShaderGraph.GenericShaderGraphMaterialGUI"
    FallBack "Hidden/Shader Graph/FallbackError"
}