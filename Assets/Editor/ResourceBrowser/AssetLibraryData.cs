using System.Collections.Generic;
using UnityEngine;

// 1. 定义资源分类枚举
public enum AssetCategory
{
    RoleModel,      // 角色模型
    RolePrefab,     // 角色预制体
    Monster,        // 怪物
    SceneProp,      // 场景道具
    Interactable,   // 可交互道具
    Scene,          // 场景
    Background,     // 背景图
    VFX,            // 特效
    Other           // 其他
}

// 2. 定义状态枚举
public enum AssetStatus
{
    Developing,     // 开发中
    Incomplete,     // 将废弃/未完成
    Finished        // 已完成
}

// 3. 单个资源的数据结构
[System.Serializable]
public class AssetData
{
    public string guid;             // 资源的唯一ID (用于防止重名文件冲突)
    public Object assetReference;   // 资源引用
    public AssetCategory category;  // 分类
    public AssetStatus status;      // 状态
    public Texture2D customPreview; // 自定义预览图 (截图)

    // 构造函数
    public AssetData(Object asset)
    {
        assetReference = asset;
        category = AssetCategory.Other; // 默认初始化为 其他
        status = AssetStatus.Developing;
        customPreview = null;
    }
}

// 4. 数据库本体 (ScriptableObject)
[CreateAssetMenu(fileName = "ProjectAssetLibrary", menuName = "Tools/Asset Library Database")]
public class AssetLibraryData : ScriptableObject
{
    public List<AssetData> assets = new List<AssetData>();
}
