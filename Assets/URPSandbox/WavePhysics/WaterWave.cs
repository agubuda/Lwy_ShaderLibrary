using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class WaterWave : MonoBehaviour
{
    public Texture2D waveTex;

    public MeshFilter mf;
    public Mesh mesh;
    public Renderer render;
    public Material mat;
    [Range(0.01f, 10f)]
    public float waveScale = 1;
    [Range(-1f, 1f)]
    public float moveSpeed = 0.5f;
    [Range(0f, 10f)]
    public float wavePower = 1;
    
    public static WaterWave inst;
    void Awake()
    {
        inst = this;

        mf = this.GetComponent<MeshFilter>();
        mesh = Instantiate(mf.sharedMesh);
        mf.sharedMesh = mesh;
        render = this.GetComponent<MeshRenderer>();
        mat = render.sharedMaterial;
        //waveTex = mat.GetTexture("_WaveTex")as Texture2D;
        //waveScale = mat.GetFloat("_Wave_Scale");               //1
        //moveSpeed = mat.GetFloat("_Wave_Speed");              //-0.11f
        //wavePower = mat.GetFloat("_Wave_Power");              //2.58

        RDMesh();
        RDTex();
    }
    float[] hList;
    void RDTex()
    {
        pixelWidth = waveTex.height;
        pixelHeight = waveTex.width;
        hList = new float[pixelWidth * pixelHeight];
        int i = 0;
        for (int y = 0; y < pixelHeight; y++)
        {
            for (int x = 0; x < pixelWidth; x++)
            {
                hList[i] = waveTex.GetPixel(x, y).grayscale;
                i++;
            }
        }
    }
    //初始化网格 获取比例
    public float maxX, maxZ, minX, minZ = 0;
    public int pixelWidth, pixelHeight = 1;
    public float offsetX, offsetZ = 0;
   
    void RDMesh()
    {
        for (int i = 0; i < mesh.vertices.Length; i++)
        {
            maxX = Mathf.Max(mesh.vertices[i].x, maxX);
            maxZ = Mathf.Max(mesh.vertices[i].z, maxZ);
            minX = Mathf.Min(mesh.vertices[i].x, minX);
            minZ = Mathf.Min(mesh.vertices[i].z, minZ);
        }
        maxX -= minX;
        maxZ -= minZ;
    }

    
    // Update is called once per frame
    void Update()
    {
        MoveWave();
        WaveMesh();
    }
    void MoveWave()
    {
        //waveScale = mat.GetFloat("_Wave_Scale");               //1
        //moveSpeed = mat.GetFloat("_Wave_Speed");              //-0.11f
        //wavePower = mat.GetFloat("_Wave_Power");              //2.58

        offsetX += moveSpeed * Time.deltaTime;
        offsetZ += moveSpeed * Time.deltaTime;
    }
    void WaveMesh()
    {
        Vector3[] vertices = mesh.vertices;
        for (int i = 0; i < vertices.Length; i ++)
        {
            vertices[i].y = GetPointH(vertices[i].x, vertices[i].z);
        }
        mesh.vertices = vertices;
        mesh.RecalculateNormals();
    }

    /// <summary>
    /// 通过坐标 获取像素矩阵位置    只计算范围内的物体
    /// </summary>
    public float GetPointH(float x, float z)
    {
        //范围外物体不计算
        if (x < minX || x > -minX || z < minZ || z > -minZ) return 0;
        //求出百分比
        float perX = (x - minX) / maxX;
        float perZ = (z - minZ) / maxZ;

        int xx = Mathf.RoundToInt((perX + offsetX) * pixelWidth * waveScale);
        int zz = Mathf.RoundToInt((perZ + offsetZ) * pixelHeight * waveScale);
        return waveTex.GetPixel(xx, zz).grayscale * wavePower + this.transform.position.y;
    }
}
