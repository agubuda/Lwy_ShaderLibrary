using UnityEngine;
using System.Collections.Generic;
using System.Linq;

public class ClothSimulationSystem : MonoBehaviour
{
    [Header("Physics Settings")]
    public float _Spring = 100.0f; // Goal matching strength
    public float _ClothStiffness = 50.0f; // Neighbor pulling strength
    public float _Damper = 5.0f;
    public float _MoveScale = 1.0f;
    
    [Header("Simulation Quality")]
    [Range(30, 120)]
    public int _SimulationRate = 60; 
    
    [Header("References")]
    public ComputeShader meshComputeShader;
    public Material material;

    // --- Structures matching HLSL ---
    struct NeighborData
    {
        public int count;
        public int n0, n1, n2, n3, n4, n5, n6, n7;
        public float d0, d1, d2, d3, d4, d5, d6, d7;
    }

    // Buffers
    private ComputeBuffer inputPosBuffer = null; 
    private ComputeBuffer outputPosBuffer = null; 
    private ComputeBuffer physicsDataBuffer = null; 
    private ComputeBuffer colorBuffer = null; 
    private ComputeBuffer neighborBuffer = null; // New!
    
    // Skinned Mesh Specific
    private GraphicsBuffer skinnedMeshBuffer = null;
    
    // State
    private int kernelIndex;
    private int initKernelIndex; 
    private int threadGroup;
    private int vertCount = 0;
    private SkinnedMeshRenderer skinnedMeshRenderer;
    private MeshFilter meshFilter;
    
    private float _timer;

    // Cached IDs
    private static readonly int ID_VertCount = Shader.PropertyToID("vertCount");
    private static readonly int ID_MoveScale = Shader.PropertyToID("_MoveScale");
    private static readonly int ID_Spring = Shader.PropertyToID("_Spring");
    private static readonly int ID_ClothStiffness = Shader.PropertyToID("_ClothStiffness");
    private static readonly int ID_Damper = Shader.PropertyToID("_Damper");
    private static readonly int ID_DeltaTime = Shader.PropertyToID("_DeltaTime");
    private static readonly int ID_LocalToWorld = Shader.PropertyToID("_LocalToWorld");
    private static readonly int ID_InputPositions = Shader.PropertyToID("_InputPositions");
    private static readonly int ID_Pos = Shader.PropertyToID("_pos");
    private static readonly int ID_Data = Shader.PropertyToID("data");
    private static readonly int ID_VertexColor = Shader.PropertyToID("_VertexColor");
    private static readonly int ID_SkinnedPos = Shader.PropertyToID("_skinnedPos");
    private static readonly int ID_NeighborBuffer = Shader.PropertyToID("_NeighborBuffer");

    private void OnEnable()
    {
        Initialize();
        _timer = 0f;
    }

    private void OnDisable()
    {
        ReleaseBuffers();
    }

    private void Initialize()
    {
        ReleaseBuffers();

        meshFilter = GetComponent<MeshFilter>();
        skinnedMeshRenderer = GetComponent<SkinnedMeshRenderer>();

        if (meshFilter != null)
        {
            InitializeStaticMesh();
        }
        else if (skinnedMeshRenderer != null)
        {
            InitializeSkinnedMesh();
        }
    }

    // --- Neighbor Generation Logic ---
    private NeighborData[] GenerateNeighbors(Mesh mesh)
    {
        int vCount = mesh.vertexCount;
        Vector3[] vertices = mesh.vertices;
        int[] triangles = mesh.triangles;

        // Use HashSet to avoid duplicates
        HashSet<int>[] adjList = new HashSet<int>[vCount];
        for(int i=0; i<vCount; i++) adjList[i] = new HashSet<int>();

        // Iterate triangles to find connections
        for (int i = 0; i < triangles.Length; i += 3)
        {
            int v0 = triangles[i];
            int v1 = triangles[i + 1];
            int v2 = triangles[i + 2];

            // Add mutual connections
            adjList[v0].Add(v1); adjList[v0].Add(v2);
            adjList[v1].Add(v0); adjList[v1].Add(v2);
            adjList[v2].Add(v0); adjList[v2].Add(v1);
        }

        // Convert to Struct Array
        NeighborData[] result = new NeighborData[vCount];
        for(int i=0; i<vCount; i++)
        {
            List<int> neighbors = adjList[i].ToList();
            int count = Mathf.Min(neighbors.Count, 8); // Max 8
            
            result[i].count = count;
            
            // Fill indices and pre-calculate rest lengths
            // For indices, defaults to 0 (which is valid but harmless if count is checked)
            // But let's set -1 conceptually, though HLSL loop uses .count
            
            if (count > 0) { result[i].n0 = neighbors[0]; result[i].d0 = Vector3.Distance(vertices[i], vertices[neighbors[0]]); }
            if (count > 1) { result[i].n1 = neighbors[1]; result[i].d1 = Vector3.Distance(vertices[i], vertices[neighbors[1]]); }
            if (count > 2) { result[i].n2 = neighbors[2]; result[i].d2 = Vector3.Distance(vertices[i], vertices[neighbors[2]]); }
            if (count > 3) { result[i].n3 = neighbors[3]; result[i].d3 = Vector3.Distance(vertices[i], vertices[neighbors[3]]); }
            if (count > 4) { result[i].n4 = neighbors[4]; result[i].d4 = Vector3.Distance(vertices[i], vertices[neighbors[4]]); }
            if (count > 5) { result[i].n5 = neighbors[5]; result[i].d5 = Vector3.Distance(vertices[i], vertices[neighbors[5]]); }
            if (count > 6) { result[i].n6 = neighbors[6]; result[i].d6 = Vector3.Distance(vertices[i], vertices[neighbors[6]]); }
            if (count > 7) { result[i].n7 = neighbors[7]; result[i].d7 = Vector3.Distance(vertices[i], vertices[neighbors[7]]); }
        }
        return result;
    }

    private void InitializeStaticMesh()
    {
        kernelIndex = meshComputeShader.FindKernel("meshModifier");
        initKernelIndex = meshComputeShader.FindKernel("InitializeMesh");

        Mesh mesh = meshFilter.sharedMesh;
        vertCount = mesh.vertexCount;

        // Buffers
        inputPosBuffer = new ComputeBuffer(vertCount, 3 * sizeof(float));
        inputPosBuffer.SetData(mesh.vertices);
        meshComputeShader.SetBuffer(kernelIndex, ID_InputPositions, inputPosBuffer);
        meshComputeShader.SetBuffer(initKernelIndex, ID_InputPositions, inputPosBuffer);

        outputPosBuffer = new ComputeBuffer(vertCount, 3 * sizeof(float));
        physicsDataBuffer = new ComputeBuffer(vertCount, 3 * 3 * sizeof(float)); 

        colorBuffer = new ComputeBuffer(vertCount, 4 * sizeof(float));
        if (mesh.colors.Length > 0) colorBuffer.SetData(mesh.colors);
        else colorBuffer.SetData(new Color[vertCount]);
        meshComputeShader.SetBuffer(kernelIndex, ID_VertexColor, colorBuffer);
        meshComputeShader.SetBuffer(initKernelIndex, ID_VertexColor, colorBuffer);

        // Neighbor Buffer Generation
        NeighborData[] nData = GenerateNeighbors(mesh);
        // Struct size: int + 8*int + 8*float = 4 + 32 + 32 = 68 bytes
        neighborBuffer = new ComputeBuffer(vertCount, 68); 
        neighborBuffer.SetData(nData);
        meshComputeShader.SetBuffer(kernelIndex, ID_NeighborBuffer, neighborBuffer);

        BindBuffersToKernel(kernelIndex);
        BindBuffersToKernel(initKernelIndex);

        threadGroup = Mathf.CeilToInt(vertCount / 128.0f);
        
        meshComputeShader.SetInt(ID_VertCount, vertCount);
        meshComputeShader.SetMatrix(ID_LocalToWorld, transform.localToWorldMatrix);
        meshComputeShader.Dispatch(initKernelIndex, threadGroup, 1, 1);

        if (material != null)
        {
            material.SetBuffer("_Pos", outputPosBuffer);
            material.SetBuffer("_VertexColor", colorBuffer);
        }
    }

    private void InitializeSkinnedMesh()
    {
        kernelIndex = meshComputeShader.FindKernel("skinnedMeshModifier");
        initKernelIndex = meshComputeShader.FindKernel("InitializeSkinnedMesh");

        Mesh mesh = skinnedMeshRenderer.sharedMesh;
        vertCount = mesh.vertexCount;

        outputPosBuffer = new ComputeBuffer(vertCount, 3 * sizeof(float));
        physicsDataBuffer = new ComputeBuffer(vertCount, 3 * 3 * sizeof(float));

        colorBuffer = new ComputeBuffer(vertCount, 4 * sizeof(float));
        if (mesh.colors.Length > 0) colorBuffer.SetData(mesh.colors);
        else colorBuffer.SetData(new Color[vertCount]);
        meshComputeShader.SetBuffer(kernelIndex, ID_VertexColor, colorBuffer);
        meshComputeShader.SetBuffer(initKernelIndex, ID_VertexColor, colorBuffer);

        // Neighbor Buffer
        NeighborData[] nData = GenerateNeighbors(mesh);
        neighborBuffer = new ComputeBuffer(vertCount, 68); 
        neighborBuffer.SetData(nData);
        meshComputeShader.SetBuffer(kernelIndex, ID_NeighborBuffer, neighborBuffer);

        BindBuffersToKernel(kernelIndex);
        BindBuffersToKernel(initKernelIndex);

        threadGroup = Mathf.CeilToInt(vertCount / 128.0f);

        meshComputeShader.SetInt(ID_VertCount, vertCount);
        meshComputeShader.SetMatrix(ID_LocalToWorld, transform.localToWorldMatrix);

        skinnedMeshBuffer = skinnedMeshRenderer.GetVertexBuffer();
        if (skinnedMeshBuffer != null)
        {
            meshComputeShader.SetBuffer(initKernelIndex, ID_SkinnedPos, skinnedMeshBuffer);
            meshComputeShader.Dispatch(initKernelIndex, threadGroup, 1, 1);
            skinnedMeshBuffer.Dispose();
            skinnedMeshBuffer = null;
        }

        if (material != null)
        {
            material.SetBuffer("_Pos", outputPosBuffer);
            material.SetBuffer("_VertexColor", colorBuffer);
        }
    }

    private void BindBuffersToKernel(int kernel)
    {
        meshComputeShader.SetBuffer(kernel, ID_Pos, outputPosBuffer);
        meshComputeShader.SetBuffer(kernel, ID_Data, physicsDataBuffer);
    }

    private void LateUpdate()
    {
        if (vertCount == 0) return;

        _timer += Time.deltaTime;
        float physicsStep = 1.0f / _SimulationRate;
        int maxSteps = 3;
        int stepsTaken = 0;

        meshComputeShader.SetInt(ID_VertCount, vertCount);
        meshComputeShader.SetFloat(ID_MoveScale, _MoveScale);
        meshComputeShader.SetFloat(ID_Spring, _Spring);
        meshComputeShader.SetFloat(ID_ClothStiffness, _ClothStiffness); // New param
        meshComputeShader.SetFloat(ID_Damper, _Damper);
        meshComputeShader.SetFloat(ID_DeltaTime, physicsStep);

        if (skinnedMeshRenderer != null)
        {
            skinnedMeshBuffer = skinnedMeshRenderer.GetVertexBuffer();
            if (skinnedMeshBuffer != null)
            {
                meshComputeShader.SetBuffer(kernelIndex, ID_SkinnedPos, skinnedMeshBuffer);
            }
        }

        while (_timer >= physicsStep && stepsTaken < maxSteps)
        {
            _timer -= physicsStep;
            stepsTaken++;

            meshComputeShader.SetMatrix(ID_LocalToWorld, transform.localToWorldMatrix);
            meshComputeShader.Dispatch(kernelIndex, threadGroup, 1, 1);
        }

        if (skinnedMeshBuffer != null)
        {
            skinnedMeshBuffer.Dispose();
            skinnedMeshBuffer = null;
        }

        if (stepsTaken >= maxSteps) _timer = 0f;
    }

    private void ReleaseBuffers()
    {
        if (inputPosBuffer != null) inputPosBuffer.Release();
        if (outputPosBuffer != null) outputPosBuffer.Release();
        if (physicsDataBuffer != null) physicsDataBuffer.Release();
        if (colorBuffer != null) colorBuffer.Release();
        if (neighborBuffer != null) neighborBuffer.Release(); // New buffer
        
        inputPosBuffer = null;
        outputPosBuffer = null;
        physicsDataBuffer = null;
        colorBuffer = null;
        neighborBuffer = null;
    }
}