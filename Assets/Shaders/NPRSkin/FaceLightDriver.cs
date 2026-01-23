using UnityEngine;

// 允许在编辑器运行，方便查看效果，但在编辑器下要注意不要生成多余的材质实例
[ExecuteAlways] 
public class FaceLightDriver : MonoBehaviour
{
    [Header("设置")]
    public Transform faceLocator; // 脸部朝向定位器
    public Renderer targetRenderer; // 【修改点1】改为引用 Renderer (MeshRenderer 或 SkinnedMeshRenderer)
    public int faceMaterialIndex = 0; // 【新增】在这里手动填入材质球的索引（从0开始）
    
    [Header("调试 (只读)")]
    public Vector3 currentForward;
    public Vector3 currentRight;

    // Shader 属性 ID
    private static int _FaceForwardID = Shader.PropertyToID("_FaceForwardGlobal");
    private static int _FaceRightID = Shader.PropertyToID("_FaceRightGlobal");

    // 【修改点2】创建一个 PropertyBlock 用于传递数据
    private MaterialPropertyBlock _propBlock;

    void OnEnable()
    {
        // 只需要初始化一次
        if (_propBlock == null)
            _propBlock = new MaterialPropertyBlock();
    }

    void LateUpdate()
    {
        if (faceLocator == null || targetRenderer == null) return;

        // 1. 计算向量
        Vector3 forwardWS = faceLocator.forward;
        Vector3 rightWS = faceLocator.right;

        // 调试显示
        currentForward = forwardWS;
        currentRight = rightWS;

        // 2. 获取当前的 PropertyBlock (防止覆盖了其他脚本设置的属性)
        // targetRenderer.GetPropertyBlock(_propBlock);
        targetRenderer.GetPropertyBlock(_propBlock, faceMaterialIndex); // 获取特定索引的Block

        // 3. 设置向量到 Block 中
        // 注意：Vector4 的 w 分量没用到就填 0，或者根据 Shader 需求填
        _propBlock.SetVector(_FaceForwardID, new Vector4(forwardWS.x, forwardWS.y, forwardWS.z, 0));
        _propBlock.SetVector(_FaceRightID, new Vector4(rightWS.x, rightWS.y, rightWS.z, 0));

        // 4. 将 Block 应用回 Renderer
        targetRenderer.SetPropertyBlock(_propBlock);
    }
}
