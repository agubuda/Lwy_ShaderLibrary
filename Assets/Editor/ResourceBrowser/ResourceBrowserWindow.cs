using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement; 
using UnityEngine.SceneManagement; 
using System.Collections.Generic;
using System.Linq;
using System.IO; 

public class ResourceBrowserWindow : EditorWindow
{
    private AssetLibraryData _libraryData;
    private Vector2 _scrollPos;
    
    // 页签相关
    private int _selectedTabIndex = 0;
    private string[] _tabLabels;
    private AssetCategory[] _categoryValues;
    
    // 多选相关
    private List<AssetData> _selectedAssets = new List<AssetData>(); 
    private AssetData _lastClickedAsset; 

    // 样式缓存
    private GUIStyle _cardStyle;
    private GUIStyle _statusStyle;
    private GUIStyle _selectedStyle; 

    [MenuItem("Tools/美术资源浏览器")]
    public static void ShowWindow()
    {
        GetWindow<ResourceBrowserWindow>("资源浏览器");
    }

    private void OnEnable()
    {
        string[] guids = AssetDatabase.FindAssets("t:AssetLibraryData");
        if (guids.Length > 0)
        {
            string path = AssetDatabase.GUIDToAssetPath(guids[0]);
            _libraryData = AssetDatabase.LoadAssetAtPath<AssetLibraryData>(path);
        }
        InitializeTabs();
    }

    private void InitializeTabs()
    {
        System.Array enumArray = System.Enum.GetValues(typeof(AssetCategory));
        _categoryValues = new AssetCategory[enumArray.Length];
        for (int i = 0; i < enumArray.Length; i++)
        {
            _categoryValues[i] = (AssetCategory)enumArray.GetValue(i);
        }

        _tabLabels = new string[enumArray.Length + 1];
        _tabLabels[0] = "全部";

        for (int i = 0; i < _categoryValues.Length; i++)
        {
            _tabLabels[i + 1] = GetCategoryLabel(_categoryValues[i]);
        }
    }

    private string GetCategoryLabel(AssetCategory category)
    {
        switch (category)
        {
            case AssetCategory.RoleModel: return "角色Model";
            case AssetCategory.RolePrefab: return "角色Prefab";
            case AssetCategory.Monster: return "怪物";
            case AssetCategory.SceneProp: return "场景道具";
            case AssetCategory.Interactable: return "可交互道具";
            case AssetCategory.Scene: return "场景";
            case AssetCategory.Background: return "背景图";
            case AssetCategory.VFX: return "特效";
            case AssetCategory.Other: return "其他";
            default: return category.ToString(); 
        }
    }

    private void OnGUI()
    {
        DrawToolbar();

        if (_libraryData == null)
        {
            EditorGUILayout.HelpBox("请先创建并分配 Asset Library Database 文件！", MessageType.Warning);
            _libraryData = (AssetLibraryData)EditorGUILayout.ObjectField("数据库", _libraryData, typeof(AssetLibraryData), false);
            return;
        }

        DrawDropArea();
        DrawAssetGrid();
    }

    private void DrawToolbar()
    {
        GUILayout.BeginHorizontal(EditorStyles.toolbar);
        
        EditorGUI.BeginChangeCheck();
        _selectedTabIndex = GUILayout.Toolbar(_selectedTabIndex, _tabLabels, EditorStyles.toolbarButton, GUILayout.Height(25));
        
        if (EditorGUI.EndChangeCheck())
        {
            _scrollPos = Vector2.zero;
            _selectedAssets.Clear(); 
        }

        GUILayout.FlexibleSpace();
        if (GUILayout.Button("保存状态", EditorStyles.toolbarButton, GUILayout.Width(80)))
        {
            EditorUtility.SetDirty(_libraryData);
            AssetDatabase.SaveAssets();
        }
        GUILayout.EndHorizontal();
    }

    private void DrawDropArea()
    {
        Event evt = Event.current;
        Rect dropArea = GUILayoutUtility.GetRect(0.0f, 40.0f, GUILayout.ExpandWidth(true));
        GUI.Box(dropArea, "拖拽 Assets 到此处添加进库", EditorStyles.helpBox);

        switch (evt.type)
        {
            case EventType.DragUpdated:
            case EventType.DragPerform:
                if (!dropArea.Contains(evt.mousePosition)) return;
                DragAndDrop.visualMode = DragAndDropVisualMode.Copy;
                if (evt.type == EventType.DragPerform)
                {
                    DragAndDrop.AcceptDrag();
                    foreach (Object draggedCode in DragAndDrop.objectReferences)
                        AddAssetToLibrary(draggedCode);
                }
                break;
        }
    }

    private void AddAssetToLibrary(Object obj)
    {
        if (_libraryData.assets.Any(x => x.assetReference == obj)) return;

        AssetCategory defaultCat = AssetCategory.Other; 
        if (_selectedTabIndex > 0)
        {
            defaultCat = _categoryValues[_selectedTabIndex - 1];
        }

        var newData = new AssetData(obj);
        newData.category = defaultCat;
        
        if (AssetDatabase.TryGetGUIDAndLocalFileIdentifier(obj, out string guid, out long localId))
        {
            newData.guid = guid;
        }
        else
        {
            newData.guid = System.Guid.NewGuid().ToString();
        }

        _libraryData.assets.Add(newData);
        EditorUtility.SetDirty(_libraryData);
        Repaint(); 
    }

    private void DrawAssetGrid()
    {
        if (_cardStyle == null) InitStyles();

        int removedCount = _libraryData.assets.RemoveAll(x => x.assetReference == null);
        if (removedCount > 0)
        {
            EditorUtility.SetDirty(_libraryData);
            _selectedAssets.RemoveAll(x => x.assetReference == null);
        }

        _scrollPos = EditorGUILayout.BeginScrollView(_scrollPos);
        
        IEnumerable<AssetData> query = _libraryData.assets;
        if (_selectedTabIndex != 0)
        {
            AssetCategory targetCategory = _categoryValues[_selectedTabIndex - 1];
            query = query.Where(x => x.category == targetCategory);
        }

        List<AssetData> filteredAssets = query
            .OrderBy(x => x.assetReference.name) 
            .ToList();

        float windowWidth = position.width;
        float cardWidth = 140f; 
        float cardHeight = 210f; 
        
        int columns = Mathf.FloorToInt(windowWidth / cardWidth);
        if (columns < 1) columns = 1;

        int index = 0;
        
        while (index < filteredAssets.Count)
        {
            GUILayout.BeginHorizontal();
            for (int i = 0; i < columns; i++)
            {
                if (index >= filteredAssets.Count) break;

                var assetData = filteredAssets[index];
                DrawAssetCard(assetData, cardWidth, cardHeight, filteredAssets);
                index++;
            }
            GUILayout.EndHorizontal();
            GUILayout.Space(10);
        }

        EditorGUILayout.EndScrollView();
    }

    private void DrawAssetCard(AssetData data, float width, float height, List<AssetData> currentList)
    {
        bool isSelected = _selectedAssets.Contains(data);
        GUIStyle currentStyle = isSelected ? _selectedStyle : _cardStyle;

        bool isScene = data.category == AssetCategory.Scene || data.assetReference is SceneAsset;
        float actualHeight = isScene ? height : height - 40; 

        GUILayout.BeginVertical(currentStyle, GUILayout.Width(width), GUILayout.Height(actualHeight));

        Texture2D preview = data.customPreview; 
        if (preview == null) preview = AssetPreview.GetAssetPreview(data.assetReference);
        if (preview == null) preview = AssetPreview.GetMiniThumbnail(data.assetReference);
        
        Rect rect = GUILayoutUtility.GetRect(width - 10, width - 10);
        if (preview != null) GUI.DrawTexture(rect, preview, ScaleMode.ScaleToFit);

        Event evt = Event.current;
        if (rect.Contains(evt.mousePosition))
        {
            if (evt.type == EventType.MouseDrag)
            {
                DragAndDrop.PrepareStartDrag();
                if (!_selectedAssets.Contains(data))
                {
                    _selectedAssets.Clear();
                    _selectedAssets.Add(data);
                    _lastClickedAsset = data;
                    Repaint();
                }

                List<Object> draggedObjects = new List<Object>();
                foreach (var item in _selectedAssets)
                {
                    if (item.assetReference != null) 
                        draggedObjects.Add(item.assetReference);
                }

                DragAndDrop.objectReferences = draggedObjects.ToArray();
                DragAndDrop.StartDrag("Dragging Assets");
                evt.Use();
            }
            else if (evt.type == EventType.MouseDown && evt.button == 0)
            {
                HandleSelectionClick(data, currentList, evt);
                
                if (_selectedAssets.Count > 0)
                {
                    Selection.objects = _selectedAssets.Select(x => x.assetReference).ToArray();
                }
                
                if (evt.clickCount == 2)
                {
                    AssetDatabase.OpenAsset(data.assetReference);
                }
                
                evt.Use();
                Repaint(); 
            }
        }

        GUILayout.Label(data.assetReference.name, EditorStyles.miniLabel);

        if (isScene)
        {
            GUI.backgroundColor = new Color(0.7f, 0.8f, 1f);
            if (GUILayout.Button("📷 场景截图", EditorStyles.miniButton))
            {
                CaptureScenePreview(data);
            }
            GUI.backgroundColor = Color.white;
        }

        GUI.backgroundColor = GetStatusColor(data.status);
        if (GUILayout.Button(GetStatusString(data.status), _statusStyle))
        {
            AssetStatus newStatus = (AssetStatus)(((int)data.status + 1) % 3);
            List<AssetData> targets = _selectedAssets.Contains(data) ? _selectedAssets : new List<AssetData> { data };
            foreach (var item in targets) item.status = newStatus;
            EditorUtility.SetDirty(_libraryData);
        }
        GUI.backgroundColor = Color.white;

        EditorGUI.BeginChangeCheck();
        AssetCategory newCat = (AssetCategory)EditorGUILayout.EnumPopup(data.category, EditorStyles.miniButton);
        if (EditorGUI.EndChangeCheck())
        {
            List<AssetData> targets = _selectedAssets.Contains(data) ? _selectedAssets : new List<AssetData> { data };
            foreach (var item in targets) item.category = newCat;
            EditorUtility.SetDirty(_libraryData);
        }

        if (isScene)
        {
            GUILayout.BeginHorizontal();
            GUILayout.Label("封面:", EditorStyles.miniLabel, GUILayout.Width(30));
            EditorGUI.BeginChangeCheck();
            data.customPreview = (Texture2D)EditorGUILayout.ObjectField(data.customPreview, typeof(Texture2D), false);
            if (EditorGUI.EndChangeCheck())
            {
                EditorUtility.SetDirty(_libraryData);
            }
            GUILayout.EndHorizontal();
        }

        if (GUILayout.Button("Remove", EditorStyles.miniButton))
        {
            List<AssetData> targets = _selectedAssets.Contains(data) ? new List<AssetData>(_selectedAssets) : new List<AssetData> { data };
            foreach (var item in targets)
            {
                // 如果是场景且有自定义截图，询问是否删除截图文件
                // 为了简单起见，这里可以自动清理截图，或者保留
                // 鉴于之前要求自动清理旧截图，这里暂不自动删文件以免误删手动拖进去的图
                // 如果需要连带文件一起删，可以在这里加逻辑
                
                _libraryData.assets.Remove(item);
                if (_selectedAssets.Contains(item)) _selectedAssets.Remove(item);
            }
            EditorUtility.SetDirty(_libraryData);
        }

        GUILayout.EndVertical();
    }

    // --- 核心修改：删除旧截图逻辑 ---
    private void CaptureScenePreview(AssetData data)
    {
        // 0. 准备路径信息
        string libPath = AssetDatabase.GetAssetPath(_libraryData);
        string libDir = Path.GetDirectoryName(libPath);
        string snapshotFolderName = "Snapshots";
        string relativeDir = Path.Combine(libDir, snapshotFolderName).Replace("\\", "/");

        // 1. 删除旧截图 (新增逻辑)
        // ----------------------------------------------------
        if (data.customPreview != null)
        {
            string oldAssetPath = AssetDatabase.GetAssetPath(data.customPreview);
            
            // 安全检查：只有当旧文件位于 Snapshots 文件夹内时才删除
            // 这样可以防止误删用户手动拖进去的、位于其他文件夹的 UI 贴图
            if (!string.IsNullOrEmpty(oldAssetPath) && oldAssetPath.Contains(snapshotFolderName))
            {
                // 使用 AssetDatabase.DeleteAsset 彻底删除资源和meta文件
                bool success = AssetDatabase.DeleteAsset(oldAssetPath);
                if (success)
                {
                    Debug.Log($"[ResourceBrowser] 已删除旧截图: {oldAssetPath}");
                    data.customPreview = null; // 暂时置空
                }
            }
        }
        // ----------------------------------------------------

        string assetPath = AssetDatabase.GetAssetPath(data.assetReference);
        Scene currentScene = SceneManager.GetActiveScene();

        if (currentScene.path != assetPath)
        {
            bool open = EditorUtility.DisplayDialog("场景未打开", 
                "截图需要打开该场景。\n是否保存当前工作并打开目标场景？", 
                "打开并截图", "取消");
            
            if (open)
            {
                if (EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())
                {
                    EditorSceneManager.OpenScene(assetPath);
                }
                else return;
            }
            else return;
        }

        Camera cam = Camera.main;
        if (cam == null) cam = FindObjectOfType<Camera>();
        if (cam == null)
        {
            EditorUtility.DisplayDialog("失败", "当前场景中没有找到相机！", "OK");
            return;
        }

        int res = 512;
        RenderTexture rt = new RenderTexture(res, res, 24);
        cam.targetTexture = rt;
        Texture2D screenShot = new Texture2D(res, res, TextureFormat.RGB24, false);
        
        cam.Render();
        RenderTexture.active = rt;
        screenShot.ReadPixels(new Rect(0, 0, res, res), 0, 0);
        screenShot.Apply();

        cam.targetTexture = null;
        RenderTexture.active = null; 
        DestroyImmediate(rt);

        // 保存文件
        byte[] bytes = screenShot.EncodeToPNG();

        string absoluteDir = Path.GetFullPath(relativeDir);
        if (!Directory.Exists(absoluteDir)) Directory.CreateDirectory(absoluteDir);

        // 使用 GUID 作为文件名的一部分，但由于我们刚才删了旧的，即使同名也没关系
        string fileName = data.assetReference.name + "_" + data.guid + ".png";
        string fullSavePath = Path.Combine(absoluteDir, fileName);
        
        File.WriteAllBytes(fullSavePath, bytes);

        AssetDatabase.Refresh();
        
        string relativeFilePath = relativeDir + "/" + fileName;
        
        TextureImporter importer = AssetImporter.GetAtPath(relativeFilePath) as TextureImporter;
        if (importer != null)
        {
            importer.textureType = TextureImporterType.Default;
            importer.SaveAndReimport();
        }

        data.customPreview = AssetDatabase.LoadAssetAtPath<Texture2D>(relativeFilePath);
        EditorUtility.SetDirty(_libraryData);
        
        Debug.Log($"[ResourceBrowser] 新截图已保存: {relativeFilePath}");
    }

    private void HandleSelectionClick(AssetData clickedData, List<AssetData> currentList, Event evt)
    {
        if (evt.control || evt.command) 
        {
            if (_selectedAssets.Contains(clickedData))
                _selectedAssets.Remove(clickedData);
            else
                _selectedAssets.Add(clickedData);
            
            _lastClickedAsset = clickedData;
        }
        else if (evt.shift) 
        {
            if (_lastClickedAsset != null && currentList.Contains(_lastClickedAsset) && currentList.Contains(clickedData))
            {
                int indexA = currentList.IndexOf(_lastClickedAsset);
                int indexB = currentList.IndexOf(clickedData);
                int start = Mathf.Min(indexA, indexB);
                int end = Mathf.Max(indexA, indexB);

                _selectedAssets.Clear();
                for (int i = start; i <= end; i++)
                {
                    _selectedAssets.Add(currentList[i]);
                }
            }
            else
            {
                _selectedAssets.Clear();
                _selectedAssets.Add(clickedData);
                _lastClickedAsset = clickedData;
            }
        }
        else 
        {
            _selectedAssets.Clear();
            _selectedAssets.Add(clickedData);
            _lastClickedAsset = clickedData;
        }
    }

    private void InitStyles()
    {
        _cardStyle = new GUIStyle(EditorStyles.helpBox);
        _cardStyle.margin = new RectOffset(5, 5, 5, 5);

        _selectedStyle = new GUIStyle(EditorStyles.helpBox);
        _selectedStyle.margin = new RectOffset(5, 5, 5, 5);
        var bgTex = new Texture2D(1, 1);
        bgTex.SetPixel(0, 0, new Color(0.24f, 0.48f, 0.9f, 0.5f)); 
        bgTex.Apply();
        _selectedStyle.normal.background = bgTex;

        _statusStyle = new GUIStyle(EditorStyles.miniButton);
        _statusStyle.fontStyle = FontStyle.Bold;
        _statusStyle.normal.textColor = Color.white;
    }

    private Color GetStatusColor(AssetStatus status)
    {
        switch (status)
        {
            case AssetStatus.Developing: return new Color(0.8f, 0.8f, 0f);
            case AssetStatus.Incomplete: return new Color(0.8f, 0.2f, 0.2f);
            case AssetStatus.Finished: return new Color(0.2f, 0.7f, 0.2f);
            default: return Color.white;
        }
    }
    
    private string GetStatusString(AssetStatus status)
    {
        switch (status)
        {
            case AssetStatus.Developing: return "开发中";
            case AssetStatus.Incomplete: return "将废弃";
            case AssetStatus.Finished: return "已完成";
            default: return "Unknown";
        }
    }
}
