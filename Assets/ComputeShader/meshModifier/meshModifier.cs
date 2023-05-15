using UnityEngine;

public class meshModifier : MonoBehaviour
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
        meshComputeShader.SetInt("vertCount", vertCount);
        meshComputeShader.SetFloat("_MoveScale", _MoveScale);
        meshComputeShader.SetFloat("_Spring", _Spring);
        meshComputeShader.SetFloat("_Damper", _Damper);

        if (skinnedMeshRenderer)
        {
            rootBoneLocalToWorld = skinnedMeshRenderer.rootBone.transform.localToWorldMatrix;
            meshComputeShader.SetMatrix("_LocalToWorld", rootBoneLocalToWorld);

            skinnedMeshBuffer = skinnedMeshRenderer.GetVertexBuffer();

            meshComputeShader.SetBuffer(kernelIndex, "_skinnedPos", skinnedMeshBuffer);
            skinnedMeshBuffer.Dispose();

            meshComputeShader.SetBuffer(kernelIndex, "_pos", computeBuffer);
        }

        if (meshFilter)
        {
            localToWorld = transform.localToWorldMatrix;
            meshComputeShader.SetMatrix("_LocalToWorld", localToWorld);

            verticesPosition = mesh.vertices;
            computeBuffer.SetData(verticesPosition, 0, 0, vertCount);
            meshComputeShader.SetBuffer(kernelIndex, "_pos", computeBuffer);
        }

        meshComputeShader.SetBuffer(kernelIndex, "data", data);
        meshComputeShader.Dispatch(kernelIndex, threadGroup, 1, 1);

        //// debug part

        //computeBuffer.GetData(aaa, 0, 0, vertCount);
        //for (int i = 0; i < aaa.Length; i++)
        //{
        //    Debug.Log(aaa[i]);
        //}

        material.SetBuffer("_Pos", computeBuffer);

        //material.SetConstantBuffer("_Pos", computeBuffer, 0, vertCount * 12);
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