using System;
using UnityEngine;

public class WaterWave : MonoBehaviour
{
    public Texture2D waveTex;
    public MeshFilter mf;
    public Mesh mesh;
    public Renderer render;
    public Material mat;
    [Range(0.01f, 50f)] public float waveScale = 1;
    [Range(-1f, 1f)] public float moveSpeed = 0.5f;
    [Range(0f, 10f)] public float wavePower = 1;

    private Vector3[] vertices; // 缓存顶点数组
    private float[] hList;
    private float maxX, maxZ, minX, minZ;
    private int pixelWidth, pixelHeight;
    private float offsetX, offsetZ;

    public static WaterWave inst;

    void Awake()
    {
        inst = this;

        mf = GetComponent<MeshFilter>();
        mesh = Instantiate(mf.sharedMesh);
        mf.sharedMesh = mesh;
        vertices = mesh.vertices; // 缓存顶点
        render = GetComponent<MeshRenderer>();
        mat = render.sharedMaterial;

        RDMesh();
        RDTex();
    }

    void RDTex()
    {
        pixelWidth = waveTex.width;
        pixelHeight = waveTex.height;
        hList = new float[pixelWidth * pixelHeight];
        for (int y = 0, i = 0; y < pixelHeight; y++)
        {
            for (int x = 0; x < pixelWidth; x++)
            {
                hList[i++] = waveTex.GetPixel(x, y).grayscale;
            }
        }
    }

    void RDMesh()
    {
        for (int i = 0; i < vertices.Length; i++)
        {
            maxX = Mathf.Max(vertices[i].x, maxX);
            maxZ = Mathf.Max(vertices[i].z, maxZ);
            minX = Mathf.Min(vertices[i].x, minX);
            minZ = Mathf.Min(vertices[i].z, minZ);
        }
        maxX -= minX;
        maxZ -= minZ;
    }

    void Update()
    {
        MoveWave();
        WaveMesh();
    }

    void MoveWave()
    {
        offsetX += moveSpeed * Time.deltaTime;
        offsetZ += moveSpeed * Time.deltaTime;
    }

    void WaveMesh()
    {
        for (int i = 0; i < vertices.Length; i++)
        {
            vertices[i].y = GetPointH(vertices[i].x, vertices[i].z);
        }
        mesh.SetVertices(vertices); // 直接设置顶点
        mesh.RecalculateNormals();
    }

    public float GetPointH(float x, float z)
    {
        if (x < minX || x > -minX || z < minZ || z > -minZ) return 0;

        float perX = (x - minX) / maxX;
        float perZ = (z - minZ) / maxZ;

        int xx = Mathf.RoundToInt((perX + offsetX) * pixelWidth * waveScale);
        int zz = Mathf.RoundToInt((perZ + offsetZ) * pixelHeight * waveScale);

        xx = xx % pixelWidth;
        zz = zz % pixelHeight;

        int index = Mathf.Abs(zz * pixelWidth + xx);
        return hList[index] * wavePower + transform.position.y;
    }
}
