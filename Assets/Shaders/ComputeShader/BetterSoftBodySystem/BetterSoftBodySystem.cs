using UnityEngine;

public class betterSoftBodySystem : MonoBehaviour
{
    public float _Damper = 5.0f;
    //public ComputeShader skinnedMeshComputeShader;
    public float _MoveScale = 1.0f;

    public float _Spring = 100.0f;
    public Material material;
    public ComputeShader meshComputeShader;
    private ComputeBuffer colorBuffer = null;
    private ComputeBuffer computeBuffer = null;
    private ComputeBuffer data = null;
    private int kernelIndex;
    //matrix
    private Matrix4x4 localToWorld;

    private Mesh mesh;
    private MeshFilter meshFilter;
    //bool isAnimated;
    private Matrix4x4 rootBoneLocalToWorld;

    private GraphicsBuffer skinnedMeshBuffer = null;
    private SkinnedMeshRenderer skinnedMeshRenderer;
    private int threadGroup;
    private int vertCount = 0;
    private Color[] vertexColors;
    private Vector3[] verticesPosition;
    private void LateUpdate()
    {
        // 设置通用参数
        meshComputeShader.SetInt("vertCount", vertCount);
        meshComputeShader.SetFloat("_MoveScale", _MoveScale);
        meshComputeShader.SetFloat("_Spring", _Spring);
        meshComputeShader.SetFloat("_Damper", _Damper);

        bool canDispatch = false; // 标记是否准备好执行 Dispatch

        // ================= 处理 SkinnedMeshRenderer =================
        if (skinnedMeshRenderer)
        {
            rootBoneLocalToWorld = skinnedMeshRenderer.rootBone.transform.localToWorldMatrix;
            meshComputeShader.SetMatrix("_LocalToWorld", rootBoneLocalToWorld);

            // 【修复 1】获取 Buffer
            skinnedMeshBuffer = skinnedMeshRenderer.GetVertexBuffer();

            // 【修复 2】必须判空！如果物体不可见，Unity 可能不会生成 Buffer
            if (skinnedMeshBuffer != null)
            {
                meshComputeShader.SetBuffer(kernelIndex, "_skinnedPos", skinnedMeshBuffer);
                // 注意：千万不要在这里 Dispose，要等 Dispatch 之后！

                meshComputeShader.SetBuffer(kernelIndex, "_pos", computeBuffer);
                canDispatch = true; // 标记可以运行
            }
        }

        // ================= 处理 MeshFilter (普通网格) =================
        if (meshFilter)
        {
            localToWorld = transform.localToWorldMatrix;
            meshComputeShader.SetMatrix("_LocalToWorld", localToWorld);

            verticesPosition = mesh.vertices;
            computeBuffer.SetData(verticesPosition, 0, 0, vertCount);
            meshComputeShader.SetBuffer(kernelIndex, "_pos", computeBuffer);
            canDispatch = true;
        }

        // ================= 执行 Dispatch =================
        if (canDispatch)
        {
            meshComputeShader.SetBuffer(kernelIndex, "data", data);
            meshComputeShader.Dispatch(kernelIndex, threadGroup, 1, 1);

            // 更新材质显示
            material.SetBuffer("_Pos", computeBuffer);
        }

        // ================= 【修复 3】最后再销毁临时 Buffer =================
        // GraphicsBuffer 需要手动释放，但必须在用完之后
        if (skinnedMeshBuffer != null)
        {
            skinnedMeshBuffer.Dispose();
            skinnedMeshBuffer = null; // 防止野指针
        }
    }

    private void OnDisable()
    {
        computeBuffer.Release();
        data.Release();
        colorBuffer.Release();
    }

    //private Vector3[] aaa;
    private void OnEnable()
    {
        //compute buffer initialize
        meshFilter = GetComponent<MeshFilter>();
        if (meshFilter)
        {
            kernelIndex = meshComputeShader.FindKernel("meshModifier");

            vertCount = meshFilter.sharedMesh.vertexCount;
            mesh = meshFilter.sharedMesh;
        }

        skinnedMeshRenderer = GetComponent<SkinnedMeshRenderer>();
        if (skinnedMeshRenderer)
        {
            kernelIndex = meshComputeShader.FindKernel("skinnedMeshModifier");

            vertCount = skinnedMeshRenderer.sharedMesh.vertexCount;
            verticesPosition = skinnedMeshRenderer.sharedMesh.vertices;

            //initialize vert colors buffer
            vertexColors = skinnedMeshRenderer.sharedMesh.colors;
            colorBuffer = new ComputeBuffer(vertCount, 4 * sizeof(float), ComputeBufferType.Default);
            colorBuffer.SetData(vertexColors);
            meshComputeShader.SetBuffer(kernelIndex, "_VertexColor", colorBuffer);
            material.SetBuffer("_VertexColor", colorBuffer);
            //Debug.Log(skinnedMeshBuffer.count);
        }

        var renderer = GetComponent<Renderer>();
        if (!renderer) return;

        Debug.Log(vertCount);
        computeBuffer = new ComputeBuffer(vertCount, 3 * sizeof(float), ComputeBufferType.Default);
        data = new ComputeBuffer(vertCount, 3 * 3 * sizeof(float), ComputeBufferType.Default);

        threadGroup = Mathf.CeilToInt(vertCount / 128.0f);

        // Debug.Log(computeBuffer);

        // for(int i = 0; i<vertCount; i++)
        // {
        //     verticesPosition[i] = localToWorld.MultiplyPoint3x4(verticesPosition[i]);
        // }

        ////debug array
        //aaa = new Vector3[verticesPosition.Length];
    }
}