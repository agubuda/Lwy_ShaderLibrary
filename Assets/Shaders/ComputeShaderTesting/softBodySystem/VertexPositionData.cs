using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[RequireComponent(typeof(Renderer))]
public class VertexPositionData : MonoBehaviour
{
    public string buffer;
    ComputeBuffer _buffer = null;
    public Material material;
    public int registerField;
    private void OnEnable()
    {

        int numVertices = 0;

        //如果是没有蒙皮的
        var meshFilter = GetComponent<MeshFilter>();
        if (meshFilter)
        {
            numVertices = meshFilter.sharedMesh.vertexCount;
            Debug.Log(numVertices + " in");
        }

        //如果是蒙皮了的
        var skinnedMeshRenderer = GetComponent<SkinnedMeshRenderer>();
        if (skinnedMeshRenderer)
        {
            numVertices = skinnedMeshRenderer.sharedMesh.vertexCount;
        }

        if (numVertices == 0) return;

        var renderer = GetComponent<Renderer>();
        if (!renderer) return;

        _buffer = new ComputeBuffer(numVertices * 2, 12 * 3 + 4);
        Graphics.SetRandomWriteTarget(registerField, _buffer, true);
        Debug.Log(_buffer);

        // foreach(var mat in renderer.materials){
        //     mat.SetBuffer("_Buffer", _buffer);
        // }

        material.SetBuffer("_Buffer", _buffer);

    }

    private void OnDisable()
    {
        if (_buffer == null) return;
        _buffer.Release();
        _buffer = null;
    }


}
