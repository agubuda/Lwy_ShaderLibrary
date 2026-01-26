#ifndef Include_OutlineUtil
#define Include_OutlineUtil

float GetCameraFOV()
{
    //https://answers.unity.com/questions/770838/how-can-i-extract-the-fov-information-from-the-pro.html
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
        // [Note] 透视补偿:
        // 在透视投影中，物体越远越小。为了保持描边在屏幕上的像素宽度一致，
        // 我们需要根据距离 (positionVS_Z) 放大描边的偏移量。
        // 同时乘上 FOV，确保改变相机 FOV 时描边粗细视觉上不变。
        cameraMulFix = abs(positionVS_Z);

        cameraMulFix = ApplyOutlineDistanceFadeOut(cameraMulFix);

        cameraMulFix *= GetCameraFOV();       
    }
    else
    {
        float orthoSize = abs(unity_OrthoParams.y);
        orthoSize = ApplyOutlineDistanceFadeOut(orthoSize);
        cameraMulFix = orthoSize * 50; //magic number
    }

    return cameraMulFix * 0.00005; 
}

float3 TransformPositionWSToOutlinePositionWS(float3 positionWS, float positionVS_Z, float3 normalWS, float outlineWidth, float musk)
{
    
    //Shoud be replaced
    float outlineExpandAmount = musk * outlineWidth * GetOutlineCameraFovAndDistanceFixMultiplier(positionVS_Z);

    #if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED) || defined(UNITY_STEREO_DOUBLE_WIDE_ENABLED)
    outlineExpandAmount *= 0.5;
    #endif
    
    return positionWS + normalWS * outlineExpandAmount; 
}

#endif
