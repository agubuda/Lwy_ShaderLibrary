using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BlendShapeDriver : MonoBehaviour
{
    int blendeShapeCount;
    SkinnedMeshRenderer skinnedMeshRenderer;
    Mesh skinnedMesh;
    // float blendOne = 0f;
    // float blendTwo = 0f;
    public bool singleLoop = false;
    public float blendSpeed1 = 10f;
    public float blendSpeed2 = 10f;
    public float blendSpeed3 = 10f;
    public float blendSpeed4 = 10f;
    public float Strentgh1 = 1f;
    public float Strentgh2 = 1f;
    public float Strentgh3 = 1f;
    public float Strentgh4 = 1f;
    float SINETIME = 0f;
    float SINETIME2 = 0f;
    float COSINETIME = 0f;
    float COSINETIME2 = 0f;

    float TEMP = 0f;


    // Start is called before the first frame update
    void Awake()
    {
        skinnedMeshRenderer = GetComponent<SkinnedMeshRenderer>();
        skinnedMesh = GetComponent<SkinnedMeshRenderer>().sharedMesh;
    }

    void Start()
    {
        blendeShapeCount = skinnedMesh.blendShapeCount;
    }

    // Update is called once per frame
    void Update()
    {

        
        SINETIME = Mathf.Sin(Time.time * blendSpeed1) * 100 % 100 ;
        SINETIME2 = Mathf.Sin(Time.time * blendSpeed3) * 100 % 100 ;
        COSINETIME = Mathf.Cos(Time.time * blendSpeed2) * 100 % 100 ;
        COSINETIME2 = Mathf.Cos(Time.time * blendSpeed4) * 100 % 100 ;

        TEMP = (TEMP + SINETIME) % 200;
                Debug.Log(SINETIME);


        if(SINETIME> 0 || singleLoop ){
            skinnedMeshRenderer.SetBlendShapeWeight(0, Mathf.Abs(SINETIME * Strentgh1));
        }
        else{
            skinnedMeshRenderer.SetBlendShapeWeight(1, Mathf.Abs(SINETIME) * Strentgh2);
        }

        // skinnedMeshRenderer.SetBlendShapeWeight(0, (SINETIME * 0.5f + 50f) * Strentgh1);
        // skinnedMeshRenderer.SetBlendShapeWeight(1, (Mathf.Clamp((SINETIME * 0.5f + 50f),0,1)) * Strentgh2);
        skinnedMeshRenderer.SetBlendShapeWeight(2, (100 - (COSINETIME * 0.5f + 50f))* Strentgh3);
        skinnedMeshRenderer.SetBlendShapeWeight(3, (COSINETIME * 0.5f + 50f)*Strentgh4); 


        // skinnedMeshRenderer.SetBlendShapeWeight(4, (SINETIME2* 0.5f + 50f)*Strentgh1);
        // skinnedMeshRenderer.SetBlendShapeWeight(5, (COSINETIME2* 0.5f + 50f)*Strentgh1);

        // skinnedMeshRenderer.SetBlendShapeWeight(0, (SINETIME * 0.5f + 50f) * Strentgh1);
        // skinnedMeshRenderer.SetBlendShapeWeight(1, (100 - (SINETIME * 0.5f + 50f)) * Strentgh2);
        // skinnedMeshRenderer.SetBlendShapeWeight(2, (100 - (COSINETIME * 0.5f + 50f))* Strentgh3);
        // skinnedMeshRenderer.SetBlendShapeWeight(4, (COSINETIME * 0.5f + 50f)*Strentgh4); 


        // skinnedMeshRenderer.SetBlendShapeWeight(5, (SINETIME2* 0.5f + 50f)*Strentgh1);
        // skinnedMeshRenderer.SetBlendShapeWeight(6, (COSINETIME2* 0.5f + 50f)*Strentgh1);



    }
}
