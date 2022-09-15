#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "Lighting.cginc"



v2f vert(appdata_full v)
{
    v2f o;
    half3 direction = lerp(v.normal, _Gravity * _GravityStrength + v.normal * (1 - _GravityStrength), STEP);
    // float3 newPos = v.vertex.xyz + v.normal * _FurLength * STEP;
    v.vertex.xyz += direction * _FurLength * STEP;

    o.vertex = UnityObjectToClipPos(v.vertex);
    //加入毛发阴影，越是中心位置，阴影越明显，边缘位置阴影越浅
    float znormal = 1 - dot(v.normal, float3(0, 0, 1));
    o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.uv2.xy = TRANSFORM_TEX(v.texcoord, _FurTex);
    o.uv3.xy = TRANSFORM_TEX(v.texcoord, _FurMask);
    // o.uv3.xy = TRANSFORM_TEX(v.texcoord, _RampMap);
    
    TANGENT_SPACE_ROTATION;
    o.ViewDir = mul(rotation, ObjSpaceViewDir(v.vertex));

    o.uv.zw = float2(znormal, znormal) * 0.001;
    
    o.normalWS = mul(v.normal, (float3x3)unity_WorldToObject);
    o.positionWS = mul(unity_ObjectToWorld, v.vertex);

    return o;
}

fixed4 frag(v2f i) : SV_Target
{
    // sample the texture
    fixed4 col = tex2D(_MainTex, i.uv.xy) * _Color;

    fixed3 lightDir = normalize(_WorldSpaceLightPos0);
    fixed3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - i.positionWS.xyz);
    fixed3 normalWS = normalize(i.normalWS);


    fixed Lambert = (max(0, dot(normalize(i.normalWS), lightDir)) * 0.5 + 0.5);
    fixed3 Ramp = tex2D(_RampMap, fixed2(Lambert, Lambert));
    // fixed3 diffuse = _LightColor0.rgb * Lambert;
    

    float alpha = tex2D(_FurTex, TRANSFORM_TEX(i.uv2.xy, _FurTex)).r;
    float alpha2 = tex2D(_FurTex2, TRANSFORM_TEX(i.uv2.xy, _FurTex2)).r;

    // alpha *= alpha2;
    // alpha = saturate(min(alpha2 * _MixPower,alpha));

    float FurMask = tex2D(_FurMask, TRANSFORM_TEX(i.uv.xy, _FurMask)).r;
    // alpha *= (noise * 1.1);
    col.rgb *= ((alpha) * STEP * _FurAOInstensity + 0.7);

    fixed frenel = saturate(dot(normalWS, viewDirWS));
    fixed4 rimColor = _RimColor * pow((1 - frenel), _RimRange);

    // return alpha;

    alpha2 = max(alpha2, frenel * frenel * _MixPower) ;
    alpha = saturate(min(alpha2 , alpha));
    // return alpha;

    alpha = step(lerp(_Cutoff, _CutoffEnd, STEP), alpha);

    // fixed frenel = pow(saturate(dot(normalWS,viewDirWS)),_fresnelPower);


    col.a = 1 - STEP * STEP;
    col.a += frenel - _EdgeFade;
    col.a = max(0, col.a);
    col.a *= alpha;
    // clip(furTex - _Clip);

    return float4(col.rgb * Lambert * _LightColor0.rgb + rimColor, col.a * FurMask);
    // return col.a;

}