using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable, CreateAssetMenu(fileName = "CustomPostProcessingMaterials", menuName = "Game/CustomPostProcessingMaterials")]
public class CustomPostProcessingMaterials  : UnityEngine.ScriptableObject
{
    public Material customEffect;

    static CustomPostProcessingMaterials _instance;

    public static CustomPostProcessingMaterials Instance{
        get{
            if(_instance !=null) return _instance;

            _instance = UnityEngine.Resources.Load("CustomPostProcessingMaterials") as CustomPostProcessingMaterials;
            return _instance;
        }
    }
}
