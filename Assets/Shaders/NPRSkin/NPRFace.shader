Shader "LwyShaders/NPR/NPRFace_NormalBased_Fixed" {
    Properties {
        _BaseMap ("Texture", 2D) = "white" { }
        _BaseColor ("Color", color) = (1, 1, 1, 1)
        [Header(Modify alpha color value for Blush.)]
        _BlushColor("Blush Color", color) = (1,0.5,0.5,0.0)

        [Space(20)][Header(Ramp lights)]
        _RampMap ("Ramp Map", 2D) = "White" { }
        _RampColum ("Ramp colum", Range(0,1)) = 0.8
        _SDFMap ("_SDFMap", 2D) = "White" { }
        _LerpMax("_LerpMax",Range(0,1)) = 0.1
        _SDFRampDarkness("SDF Ramp Darkness", Range(0,1)) = 0.4
        
        // --- [新增] AO 设置 ---
        [Space(20)][Header(Occlusion)]
        _OcclusionMap ("Occlusion Map", 2D) = "white" {}
        _OcclusionStrength ("Occlusion Strength", Range(0, 1)) = 1.0
        // ---------------------

        [Space(20)][Header(Outline settings)]
        _OutLineWidth ("Outline width", float) = -0.04
        _OutLineColor ("Outline color", color) = (0.1, 0.1, 0.1, 1)

        [Space(20)][Header(Env and dir light)]
        [Toggle(_ENABLEENVIROMENTLIGHT)] _ENABLEENVIROMENTLIGHT ("Enable enviroment light", Float) = 0.0
        _LightInfluence ("Light influence", Range(0.0, 2.0)) = 1
        _ShadowEnvMix ("Shadow Light Mix", Range(0, 1)) = 0.3 
        
        [Space(20)][Header(Hair Shadow Receiver)]
        _HairShadowColor ("Hair Shadow Color", Color) = (0.5, 0.4, 0.4, 0.5)
        _StencilRef ("Stencil Ref ID", Int) = 128
    }

    SubShader {

        Tags { "Queue" = "Geometry" "RenderType" = "Opaque" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }

        Pass {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        Pass {
            Name "NPR Face"
            Tags { "LightMode" = "UniversalForward" } // 原先写的是 SRPDefaultUnlit，现在改为 UniversalForward 以匹配 URP 流程
            // 如果你之前用 SRPDefaultUnlit 是有特殊原因的，可以改回去，但通常主 Pass 应该是 UniversalForward
            // 不过看你之前的 Outline Pass 是 SRPDefaultUnlit，我这里先不改这个 Pass 的 Tag 以免破坏你现有的管线配置
            // 但为了 Hair Shadow Pass 能正确叠加，建议它是 UniversalForward 的。
            // 暂时保持原样 SRPDefaultUnlit
            
            ZWrite On

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma shader_feature _ENABLEENVIROMENTLIGHT

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float4 _MainTex_ST;
            float4 _BlushColor;
            float _OutLineWidth;
            float _RampColum;
            float _OffsetMul;
            float _Threshold;
            float4 _BaseColor;
            float _LerpMax, _SDFRampDarkness;
            float _LightInfluence;
            // --- [新增变量] ---
            float _OcclusionStrength;
            float _ShadowEnvMix;
            
            // [新增] 接收脚本传来的世界方向
            float4 _FaceForwardGlobal;
            float4 _FaceRightGlobal;
            
            // Hair Shadow
            float4 _HairShadowColor;
            CBUFFER_END

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_RampMap); SAMPLER(sampler_RampMap);
            TEXTURE2D(_SDFMap); SAMPLER(sampler_SDFMap);
            // --- [新增纹理] ---
            TEXTURE2D(_OcclusionMap); SAMPLER(sampler_OcclusionMap);

            struct a2v {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float4 scrPos : TEXCOORD3;
                float4 shadowCoord : TEXCOORD4;
                float3 tangentWS : TEXCOORD5;
                float3 bitangentWS : TEXCOORD6;
            };

            v2f vert(a2v input) {
                v2f o;
                o.positionCS = TransformObjectToHClip(input.positionOS);
                o.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(input.normalOS.xyz, true);
                o.tangentWS = TransformObjectToWorldDir(input.tangentOS.xyz);
                o.bitangentWS = normalize(cross(o.normalWS, o.tangentWS) * input.tangentOS.w);

                o.scrPos = ComputeScreenPos(o.positionCS);
                o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
                o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

                return o;
            }

            float4 frag(v2f input) : SV_TARGET {
                // 1. 获取灯光信息
                Light MainLight = GetMainLight(input.shadowCoord);
                float3 LightDir = normalize(MainLight.direction);
                float3 LightColor = MainLight.color; // 使用 float3

                // 2. 基础颜色处理
                float4 difusse = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                difusse *= _BaseColor;
                difusse.rgb = lerp(difusse.rgb , _BlushColor.rgb * difusse.rgb, difusse.a * _BlushColor.a);
                float4 color = difusse;

                // 3. SDF 计算逻辑
                float isShadow = 0;
                float4 SDFMap = SAMPLE_TEXTURE2D(_SDFMap, sampler_SDFMap, input.uv);
                float4 SDFMap_R = SAMPLE_TEXTURE2D(_SDFMap, sampler_SDFMap, float2(1-input.uv.x,input.uv.y));

                // 确保模型切线空间正确
                float3 leftDir = -_FaceRightGlobal.xyz;
                float3 frontDir = _FaceForwardGlobal.xyz;

                // [Note] 面部阴影计算核心逻辑 (SDF Face Shadow):
                // 1. 计算 "面部朝向" 与 "光照方向" 的关系 (FdotL)。
                //    使用二次方曲线 ((-x+1)/2)^2 将 [-1, 1] 映射到平滑的 [0, 1] 衰减曲线，用于控制阴影阈值。
                float FdotL = dot(frontDir.xz, normalize(LightDir.xz));
                FdotL = ((-FdotL + 1.0) * 0.5) * ((-FdotL + 1.0) * 0.5);
                float ctrl = saturate(FdotL); // 修复 clamp 参数顺序问题

                // 2. 采样 SDF 面部光照图。
                //    根据光线是来自左侧还是右侧，选择采样原图还是翻转的图 (SDFMap_R)。
                //    SDF图中存储的是 "在这个角度下，此处是否应该变黑" 的阈值。
                float ilm = dot(LightDir.xz, leftDir.xz) > 0 ? SDFMap.r : SDFMap_R.r;

                // 3. 比较:
                //    ilm (SDF阈值) vs ctrl (当前光照强度)。
                //    step(ilm, ctrl) 决定是亮部(0)还是暗部(1)。
                isShadow = step(ilm, ctrl);
                float bias = smoothstep(0, _LerpMax, abs(ctrl - ilm)); // 边缘软化

                float SDFFactor = 0;
                if (ctrl > 0.99 || isShadow == 1)
                {
                    SDFFactor = lerp(0, 1, bias);
                }

                // --- [核心修改 1] AO 融入 SDF ---
                // [Note] AO 处理思路:
                // 在二次元渲染中，AO不仅仅是变暗，而是强制该区域进入 "阴影状态"。
                // 所以我们计算一个权重，取 max(现有阴影, AO带来的阴影)，确保深陷区域使用 ShadowColor。
                // 采样 AO 图 (假设在 R 通道)
                float ao = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, input.uv).r;
                // 计算 AO 带来的额外阴影权重 (AO越黑，值越大)
                float aoShadowWeight = (1.0 - ao) * _OcclusionStrength;
                // 取最大值：原本的阴影 OR AO 强制的阴影
                SDFFactor = saturate(max(SDFFactor, aoShadowWeight));
                // -----------------------------

                // 4. 应用 Ramp 颜色 (材质本身的固有阴影色)
                float4 SDFShadowColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(_SDFRampDarkness, _RampColum));
                // 此时 color 包含了 "固有色 + Ramp阴影"，但还没有应用任何光照颜色强度
                color = lerp(color, color * SDFShadowColor, SDFFactor);

                // --- [核心修改 2] 环境光照合理化 ---
                #if _ENABLEENVIROMENTLIGHT
                    // A. 获取环境光 (SH) - 这代表了周围环境的漫反射光颜色
                    float3 ambient = SampleSH(input.normalWS); 
                    
                    // B. 构建受光面光照 (Lit Light)
                    // 在受光面，物体主要反射主光颜色
                    float3 litLightColor = LightColor;

                    // C. 构建背光面光照 (Shadow Light)
                    // [Note] 阴影色策略:
                    // 在背光面，物体主要反射环境光(Ambient)。
                    // 但纯环境光通常太暗，为了保持卡通感，我们通常会混入一点点主光颜色(Bounce/Subsurface Scattering approximation)。
                    // 这里使用 _ShadowEnvMix 控制混合比例 (0 = 纯环境光, 1 = 纯主光)
                    // 你原来的逻辑 (ambient+2*light)/3 大约等同于混合了 0.66 的主光
                    float3 shadowLightColor = lerp(ambient, LightColor, _ShadowEnvMix);
                    
                    // 确保光照不会出现负值或过暗（可选）
                    shadowLightColor = max(shadowLightColor, float3(0.05, 0.05, 0.05));

                    // D. 根据 SDF 阴影因子在 "亮部光照" 和 "暗部光照" 之间插值
                    // SDFFactor=0 (亮) -> 使用 MainLight
                    // SDFFactor=1 (暗) -> 使用 Ambient Mix
                    float3 finalLight = lerp(litLightColor, shadowLightColor, SDFFactor);

                    // E. 应用光照到材质
                    color.rgb *= finalLight * _LightInfluence;
                #else
                    // 如果不开启环境光，至少要应用主光颜色，否则物体会发光
                    // 简单的处理：亮部=LightColor, 暗部=变暗的LightColor
                    float3 simpleShadowLight = LightColor * 0.5; // 简单的变暗
                    float3 finalLightNoEnv = lerp(LightColor, simpleShadowLight, SDFFactor);
                    color.rgb *= finalLightNoEnv;
                #endif

                return color;
            }
            ENDHLSL
        }

        // Pass 3: Hair Shadow Receiver (New Integrated Pass)
        // 注意：这个 Pass 只有在 Render Queue 晚于 Caster 时才有用。
        // 但同一个 Shader 的 Pass 是顺序执行的。如果脸部是 Geometry，头发 Caster 是 Geometry+10，
        // 那么这个 Pass 在 Geometry 阶段执行时，Stencil 还没被写入！
        // 所以，集成在这里仅仅是为了代码集中。
        // 你必须把使用这个 Shader 的材质放到 Geometry+20 队列（修改 Material Inspector 里的 Render Queue），
        // 或者使用 Render Objects Feature 再次渲染这个 Pass。
        Pass
        {
            Name "HairShadowReceiver"
            // 使用一个特殊的 LightMode，以便在 Render Features 中调用，或者只是作为普通 Pass 尝试执行
            // 为了保险，我用 UniversalForward，但如果它不执行，你可能需要用 Render Objects 
            Tags { "LightMode" = "HairShadow" } 

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest Equal // 这里的 ZTest Equal 很有趣：只在脸部已经画过的地方画。
            // 配合 Stencil 才能生效

            Stencil
            {
                Ref [_StencilRef]
                Comp Equal
                Pass Keep
            }

            HLSLPROGRAM
            #pragma vertex vert_shadow
            #pragma fragment frag_shadow
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _HairShadowColor;
            CBUFFER_END

            Varyings vert_shadow(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            half4 frag_shadow(Varyings input) : SV_TARGET
            {
                return _HairShadowColor;
            }
            ENDHLSL
        }

        // Pass 4: Outline (保持不变)
        Pass {
            Name "Outline"
            Tags { "Queue" = "Geometry" "IgnoreProjector" = "True" "LightMode" = "SRPDefaultUnlit" }
            Cull Front
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float GetCameraFOV()
            {
                float t = unity_CameraProjection._m11;
                float Rad2Deg = 180 / 3.1415;
                float fov = atan(1.0f / t) * 2.0 * Rad2Deg;
                return fov;
            }

            float ApplyOutlineDistanceFadeOut(float inputMulFix)
            {
                return saturate(inputMulFix);
            }
            float GetOutlineCameraFovAndDistanceFixMultiplier(float positionVS_Z)
            {
                float cameraMulFix;
                if(unity_OrthoParams.w == 0)
                {
                    cameraMulFix = abs(positionVS_Z);
                    cameraMulFix = ApplyOutlineDistanceFadeOut(cameraMulFix);
                    cameraMulFix *= GetCameraFOV();       
                }
                else
                {
                    float orthoSize = abs(unity_OrthoParams.y);
                    orthoSize = ApplyOutlineDistanceFadeOut(orthoSize);
                    cameraMulFix = orthoSize * 50; 
                }
                return cameraMulFix * 0.00005; 
            }

            float3 TransformPositionWSToOutlinePositionWS(float3 positionWS, float positionVS_Z, float3 normalWS, float outlineWidth, float musk)
            {
                float outlineExpandAmount = musk * outlineWidth * GetOutlineCameraFovAndDistanceFixMultiplier(positionVS_Z);
                #if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED) || defined(UNITY_STEREO_DOUBLE_WIDE_ENABLED)
                outlineExpandAmount *= 0.5;
                #endif
                return positionWS + normalWS * outlineExpandAmount; 
            }

            #pragma vertex vert
            #pragma fragment frag
            CBUFFER_START(UnityPerMaterial)
            float _OutLineWidth;
            float4 _OutLineColor;
            CBUFFER_END
            
            struct a2v {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float3 vertColor : COLOR;
            };

            struct v2f {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 vertColor : COLOR;
            };

            v2f vert(a2v input) {
                v2f o;
                float4 positionOS = input.positionOS;
                half3 normalOS = normalize(input.normalOS);
                o.positionWS = TransformObjectToWorld(positionOS.xyz);
                float3 positionVS = TransformWorldToView(o.positionWS);
                float3 normalWS = TransformObjectToWorldNormal(normalOS);
                o.positionWS = TransformPositionWSToOutlinePositionWS(o.positionWS, positionVS.z, normalWS, _OutLineWidth, input.vertColor.r);
                o.positionCS = TransformWorldToHClip(o.positionWS);
                return o;
            }

            half4 frag(v2f input) : SV_TARGET {
                return _OutLineColor;
            }
            ENDHLSL
        }
    }
}
