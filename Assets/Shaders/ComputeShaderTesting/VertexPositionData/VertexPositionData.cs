using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[RequireComponent(typeof(Renderer))]
public class VertexPositionData : MonoBehaviour
{
    ComputeBuffer _buffer = null;
    // Start is called before the first frame update
    void OnEnable()
    {
        int numVertices = 0;

        //如果是没有蒙皮的obj
        var meshFilter = GetComponent<MeshFilter>();
        if(meshFilter){
            numVertices = meshFilter.sharedMesh.vertexCount;
            Debug.Log(numVertices+ "in");
        }

        //如果是蒙皮了的obj
        var skinnedMeshRenderer = GetComponent<SkinnedMeshRenderer>();
        if(skinnedMeshRenderer){
            numVertices = skinnedMeshRenderer.sharedMesh.vertexCount;
        }

        if(numVertices==0) return;

        var renderer = GetComponent<Renderer>();
        if(!renderer) return;

        _buffer = new ComputeBuffer(numVertices*4,12*3+4);
        Graphics.SetRandomWriteTarget(1,_buffer,true);

        foreach(var mat in renderer.materials){
            mat.SetBuffer("_Buffer", _buffer);
        }

        
    }

    // Update is called once per frame
    void OnDisable() {
        if(_buffer == null) return;
        _buffer.Dispose();
        _buffer = null;
    }

   
}
