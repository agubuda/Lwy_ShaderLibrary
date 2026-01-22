using UnityEngine;

[ExecuteAlways] // 允许在编辑器不运行也能看到效果
public class FaceLightDriver : MonoBehaviour
{
    [Header("设置")]
    public Transform faceLocator; // 把后面创建的定位器拖进来
    public Material targetMaterial; // 角色的脸部材质

    [Header("调试 (只读)")]
    public Vector3 currentForward;
    public Vector3 currentRight;

    // Shader 里的变量名 ID，提升性能
    private int _FaceForwardID;
    private int _FaceRightID;

    void OnEnable()
    {
        _FaceForwardID = Shader.PropertyToID("_FaceForwardGlobal");
        _FaceRightID = Shader.PropertyToID("_FaceRightGlobal");
    }

    void LateUpdate()
    {
        if (faceLocator == null || targetMaterial == null) return;

        // 获取定位器的世界空间方向
        // 这里的 forward 就是蓝轴，right 就是红轴
        Vector3 forwardWS = faceLocator.forward;
        Vector3 rightWS = faceLocator.right;

        // 记录调试信息
        currentForward = forwardWS;
        currentRight = rightWS;

        // 传给材质
        targetMaterial.SetVector(_FaceForwardID, new Vector4(forwardWS.x, forwardWS.y, forwardWS.z, 0));
        targetMaterial.SetVector(_FaceRightID, new Vector4(rightWS.x, rightWS.y, rightWS.z, 0));
    }
}
