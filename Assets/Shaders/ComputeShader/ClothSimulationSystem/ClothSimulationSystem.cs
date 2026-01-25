using UnityEngine;
using System.Collections.Generic;
using System.Linq;

public class ClothSimulationSystem : MonoBehaviour
{
    [Header("Physics Settings")]
    public float _Spring = 100.0f; 
    public float _ClothStiffness = 50.0f; 
    public float _Damper = 5.0f;
    public float _MoveScale = 1.0f;
    
    [Header("Simulation Quality")]
    [Range(30, 120)]
    public int _SimulationRate = 60;
    
    [Header("Normals")]
    public bool _RecalculateNormals = true; // Switch
    
    [Header("References")]
    public ComputeShader meshComputeShader;
    public Material material;

    struct NeighborData
    {
        public int count;
        public int n0, n1, n2, n3, n4, n5, n6, n7;
        public float d0, d1, d2, d3, d4, d5, d6, d7;
    }

    struct VertexTriangleMap
    {
        public int count;
        public int t0, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11;
    }
    
    struct Triangle
    {
        public int v0, v1, v2;
    }

    // Buffers
    private ComputeBuffer inputPosBuffer = null; 
    private ComputeBuffer inputNormalBuffer = null; 
    private ComputeBuffer outputPosBuffer = null; 
    private ComputeBuffer outputNormalBuffer = null; 
    private ComputeBuffer physicsDataBuffer = null; 
    private ComputeBuffer colorBuffer = null; 
    private ComputeBuffer neighborBuffer = null; 
    
    private ComputeBuffer triangleBuffer = null; 
    private ComputeBuffer vertexTriangleMapBuffer = null; 
    
    private GraphicsBuffer skinnedMeshBuffer = null;
    
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
    private static readonly int ID_RecalculateNormals = Shader.PropertyToID("_RecalculateNormals");
    private static readonly int ID_LocalToWorld = Shader.PropertyToID("_LocalToWorld");
    private static readonly int ID_InputPositions = Shader.PropertyToID("_InputPositions");
    private static readonly int ID_InputNormals = Shader.PropertyToID("_InputNormals");
    private static readonly int ID_Pos = Shader.PropertyToID("_pos");
    private static readonly int ID_Normals = Shader.PropertyToID("_normals");
    private static readonly int ID_Data = Shader.PropertyToID("data");
    private static readonly int ID_VertexColor = Shader.PropertyToID("_VertexColor");
    private static readonly int ID_SkinnedPos = Shader.PropertyToID("_skinnedPos");
    private static readonly int ID_NeighborBuffer = Shader.PropertyToID("_NeighborBuffer");
    private static readonly int ID_TriangleBuffer = Shader.PropertyToID("_TriangleBuffer");
    private static readonly int ID_VertexTriangleMap = Shader.PropertyToID("_VertexTriangleMap");

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

    private NeighborData[] GenerateNeighbors(Mesh mesh)
    {
        int vCount = mesh.vertexCount;
        Vector3[] vertices = mesh.vertices;
        int[] triangles = mesh.triangles;

        HashSet<int>[] adjList = new HashSet<int>[vCount];
        for(int i=0; i<vCount; i++) adjList[i] = new HashSet<int>();

        for (int i = 0; i < triangles.Length; i += 3)
        {
            int v0 = triangles[i];
            int v1 = triangles[i + 1];
            int v2 = triangles[i + 2];

            adjList[v0].Add(v1); adjList[v0].Add(v2);
            adjList[v1].Add(v0); adjList[v1].Add(v2);
            adjList[v2].Add(v0); adjList[v2].Add(v1);
        }

        NeighborData[] result = new NeighborData[vCount];
        for(int i=0; i<vCount; i++)
        {
            List<int> neighbors = adjList[i].ToList();
            int count = Mathf.Min(neighbors.Count, 8); 
            
            result[i].count = count;
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

    private void GenerateGeometryData(Mesh mesh, out Triangle[] tris, out VertexTriangleMap[] map)
    {
        int[] indices = mesh.triangles;
        int triCount = indices.Length / 3;
        int vCount = mesh.vertexCount;

        tris = new Triangle[triCount];
        map = new VertexTriangleMap[vCount];

        List<int>[] vToT = new List<int>[vCount];
        for(int i=0; i<vCount; i++) vToT[i] = new List<int>();

        for (int i = 0; i < triCount; i++)
        {
            int v0 = indices[i * 3 + 0];
            int v1 = indices[i * 3 + 1];
            int v2 = indices[i * 3 + 2];

            tris[i] = new Triangle { v0 = v0, v1 = v1, v2 = v2 };

            vToT[v0].Add(i);
            vToT[v1].Add(i);
            vToT[v2].Add(i);
        }

        for (int i = 0; i < vCount; i++)
        {
            List<int> tList = vToT[i];
            int count = Mathf.Min(tList.Count, 12); 
            map[i].count = count;
            
            if(count > 0) map[i].t0 = tList[0];
            if(count > 1) map[i].t1 = tList[1];
            if(count > 2) map[i].t2 = tList[2];
            if(count > 3) map[i].t3 = tList[3];
            if(count > 4) map[i].t4 = tList[4];
            if(count > 5) map[i].t5 = tList[5];
            if(count > 6) map[i].t6 = tList[6];
            if(count > 7) map[i].t7 = tList[7];
            if(count > 8) map[i].t8 = tList[8];
            if(count > 9) map[i].t9 = tList[9];
            if(count > 10) map[i].t10 = tList[10];
            if(count > 11) map[i].t11 = tList[11];
        }
    }

    private void InitializeStaticMesh()
    {
        kernelIndex = meshComputeShader.FindKernel("meshModifier");
        initKernelIndex = meshComputeShader.FindKernel("InitializeMesh");

        Mesh mesh = meshFilter.sharedMesh;
        vertCount = mesh.vertexCount;

        inputPosBuffer = new ComputeBuffer(vertCount, 3 * sizeof(float));
        inputPosBuffer.SetData(mesh.vertices);
        meshComputeShader.SetBuffer(kernelIndex, ID_InputPositions, inputPosBuffer);
        meshComputeShader.SetBuffer(initKernelIndex, ID_InputPositions, inputPosBuffer);

        inputNormalBuffer = new ComputeBuffer(vertCount, 3 * sizeof(float));
        inputNormalBuffer.SetData(mesh.normals);
        meshComputeShader.SetBuffer(kernelIndex, ID_InputNormals, inputNormalBuffer);

        outputPosBuffer = new ComputeBuffer(vertCount, 3 * sizeof(float));
        outputNormalBuffer = new ComputeBuffer(vertCount, 3 * sizeof(float));
        physicsDataBuffer = new ComputeBuffer(vertCount, 3 * 3 * sizeof(float)); 

        colorBuffer = new ComputeBuffer(vertCount, 4 * sizeof(float));
        if (mesh.colors.Length > 0) colorBuffer.SetData(mesh.colors);
        else colorBuffer.SetData(new Color[vertCount]);
        
        meshComputeShader.SetBuffer(kernelIndex, ID_VertexColor, colorBuffer);
        meshComputeShader.SetBuffer(initKernelIndex, ID_VertexColor, colorBuffer);

        NeighborData[] nData = GenerateNeighbors(mesh);
        neighborBuffer = new ComputeBuffer(vertCount, 68); 
        neighborBuffer.SetData(nData);
        meshComputeShader.SetBuffer(kernelIndex, ID_NeighborBuffer, neighborBuffer);

        GenerateGeometryData(mesh, out Triangle[] tris, out VertexTriangleMap[] map);
        triangleBuffer = new ComputeBuffer(tris.Length, 12); 
        triangleBuffer.SetData(tris);
        vertexTriangleMapBuffer = new ComputeBuffer(vertCount, 52); 
        vertexTriangleMapBuffer.SetData(map);
        
        meshComputeShader.SetBuffer(kernelIndex, ID_TriangleBuffer, triangleBuffer);
        meshComputeShader.SetBuffer(kernelIndex, ID_VertexTriangleMap, vertexTriangleMapBuffer);

        BindBuffersToKernel(kernelIndex);
        BindBuffersToKernel(initKernelIndex);

        threadGroup = Mathf.CeilToInt(vertCount / 128.0f);
        
        meshComputeShader.SetInt(ID_VertCount, vertCount);
        meshComputeShader.SetMatrix(ID_LocalToWorld, transform.localToWorldMatrix);
        meshComputeShader.Dispatch(initKernelIndex, threadGroup, 1, 1);

        if (material != null)
        {
            material.SetBuffer("_Pos", outputPosBuffer);
            material.SetBuffer("_Normals", outputNormalBuffer);
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
        outputNormalBuffer = new ComputeBuffer(vertCount, 3 * sizeof(float));
        physicsDataBuffer = new ComputeBuffer(vertCount, 3 * 3 * sizeof(float));

        colorBuffer = new ComputeBuffer(vertCount, 4 * sizeof(float));
        if (mesh.colors.Length > 0) colorBuffer.SetData(mesh.colors);
        else colorBuffer.SetData(new Color[vertCount]);

        meshComputeShader.SetBuffer(kernelIndex, ID_VertexColor, colorBuffer);
        meshComputeShader.SetBuffer(initKernelIndex, ID_VertexColor, colorBuffer);

        NeighborData[] nData = GenerateNeighbors(mesh);
        neighborBuffer = new ComputeBuffer(vertCount, 68); 
        neighborBuffer.SetData(nData);
        meshComputeShader.SetBuffer(kernelIndex, ID_NeighborBuffer, neighborBuffer);

        GenerateGeometryData(mesh, out Triangle[] tris, out VertexTriangleMap[] map);
        triangleBuffer = new ComputeBuffer(tris.Length, 12);
        triangleBuffer.SetData(tris);
        vertexTriangleMapBuffer = new ComputeBuffer(vertCount, 52); 
        vertexTriangleMapBuffer.SetData(map);
        
        meshComputeShader.SetBuffer(kernelIndex, ID_TriangleBuffer, triangleBuffer);
        meshComputeShader.SetBuffer(kernelIndex, ID_VertexTriangleMap, vertexTriangleMapBuffer);

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
            material.SetBuffer("_Normals", outputNormalBuffer);
            material.SetBuffer("_VertexColor", colorBuffer);
        }
    }

    private void BindBuffersToKernel(int kernel)
    {
        meshComputeShader.SetBuffer(kernel, ID_Pos, outputPosBuffer);
        meshComputeShader.SetBuffer(kernel, ID_Normals, outputNormalBuffer); 
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
        meshComputeShader.SetFloat(ID_ClothStiffness, _ClothStiffness);
        meshComputeShader.SetFloat(ID_Damper, _Damper);
        meshComputeShader.SetFloat(ID_DeltaTime, physicsStep);
        meshComputeShader.SetInt(ID_RecalculateNormals, _RecalculateNormals ? 1 : 0);
        
        // Pass Switch to Material
        if (material != null)
        {
            if (_RecalculateNormals) material.EnableKeyword("_RECALC_NORMALS_ON");
            else material.DisableKeyword("_RECALC_NORMALS_ON");
        }

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
        if (inputNormalBuffer != null) inputNormalBuffer.Release();
        if (outputPosBuffer != null) outputPosBuffer.Release();
        if (outputNormalBuffer != null) outputNormalBuffer.Release();
        if (physicsDataBuffer != null) physicsDataBuffer.Release();
        if (colorBuffer != null) colorBuffer.Release();
        if (neighborBuffer != null) neighborBuffer.Release();
        if (triangleBuffer != null) triangleBuffer.Release();
        if (vertexTriangleMapBuffer != null) vertexTriangleMapBuffer.Release();
        
        inputPosBuffer = null;
        inputNormalBuffer = null;
        outputPosBuffer = null;
        outputNormalBuffer = null;
        physicsDataBuffer = null;
        colorBuffer = null;
        neighborBuffer = null;
        triangleBuffer = null;
        vertexTriangleMapBuffer = null;
    }
}