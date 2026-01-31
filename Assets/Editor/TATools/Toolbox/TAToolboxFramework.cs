using UnityEngine;
using UnityEditor;
using System.Collections.Generic;

namespace TAToolbox
{
    /// <summary>
    /// 所有工具页面的基类
    /// </summary>
    public abstract class TAToolPage
    {
        public abstract string PageName { get; }

        // 页面激活时调用
        public virtual void OnEnable() { }
        
        // 页面隐藏时调用
        public virtual void OnDisable() { }

        // 核心绘制函数，rootPath 为当前在 Project 窗口选中的文件夹路径
        public abstract void OnGUI(string rootPath);

        // 辅助：绘制标题
        protected void DrawHeader(string title)
        {
            GUILayout.Space(10);
            GUILayout.Label(title, EditorStyles.boldLabel);
            EditorGUILayout.LabelField("", GUI.skin.horizontalSlider); // 分割线
            GUILayout.Space(10);
        }

        // 辅助：获取系统绝对路径
        protected string GetFullPath(string assetPath)
        {
            return System.IO.Path.Combine(System.IO.Directory.GetParent(Application.dataPath).FullName, assetPath);
        }
    }

    /// <summary>
    /// 工具箱主窗口
    /// </summary>
    public class TAToolboxWindow : EditorWindow
    {
        private List<TAToolPage> _pages = new List<TAToolPage>();
        private int _selectedPageIndex = 0;
        private Vector2 _sidebarScroll;
        private Vector2 _contentScroll;
        private string _currentFolderPath = "Assets"; // 默认路径

        [MenuItem("Tools/TA&美术工具/★综合工具箱 (TAToolbox)")]
        public static void ShowWindow()
        {
            var window = GetWindow<TAToolboxWindow>("TA工具箱");
            window.minSize = new Vector2(900, 600);
            window.Show();
        }

        private void OnEnable()
        {
            // --- 在这里注册所有页面 ---
            _pages.Clear();
            
            // 1. 通用/文件
            _pages.Add(new Page_BatchRename());
            
            // 2. 贴图工具
            _pages.Add(new Page_TextureOptimizer()); // 原来的 ASTC 和 Resize 合并成了这个
            _pages.Add(new Page_TextureCompressionPreset());
            _pages.Add(new Page_TextureChannelPacker());
            
            // 3. 模型动画工具
            _pages.Add(new Page_FBXImporter());
            _pages.Add(new Page_FbxClipRenamer());
            _pages.Add(new Page_HeatmapCopier());
            
            // 4. 材质工具
            _pages.Add(new Page_MaterialPropertyBatcher());
            _pages.Add(new Page_MaterialShaderReplacer());

            _pages.Add(new Page_FolderSizeAnalyzer());
            _pages.Add(new Page_GameViewCapture());

            _pages.Add(new Page_TextureSwizzler());

            // 5. 外部同步工具
            _pages.Add(new Page_ArtSync());

            // 初始化选中
            if (_pages.Count > 0) _pages[_selectedPageIndex].OnEnable();
            UpdateSelection();
        }

        private void OnDisable()
        {
            foreach (var page in _pages) page.OnDisable();
        }

        // 监听 Project 窗口选择变化
        private void OnSelectionChange()
        {
            UpdateSelection();
            Repaint();
        }

        private void UpdateSelection()
        {
            Object obj = Selection.activeObject;
            if (obj != null)
            {
                string path = AssetDatabase.GetAssetPath(obj);
                if (AssetDatabase.IsValidFolder(path))
                {
                    _currentFolderPath = path;
                }
                // 如果选中的是文件，取其父文件夹（可选，为了方便）
                else
                {
                    // _currentFolderPath = System.IO.Path.GetDirectoryName(path).Replace("\\", "/");
                }
            }
        }

        private void OnGUI()
        {
            EditorGUILayout.BeginHorizontal();

            // --- 左侧导航栏 ---
            EditorGUILayout.BeginVertical(EditorStyles.helpBox, GUILayout.Width(220));
            DrawSidebar();
            EditorGUILayout.EndVertical();

            // --- 右侧内容区 ---
            EditorGUILayout.BeginVertical();
            
            // 顶部状态栏
            GUI.backgroundColor = new Color(0.8f, 1f, 0.8f);
            EditorGUILayout.HelpBox($"当前目标文件夹: {_currentFolderPath}", MessageType.None);
            GUI.backgroundColor = Color.white;

            _contentScroll = EditorGUILayout.BeginScrollView(_contentScroll);
            if (_pages.Count > 0 && _selectedPageIndex < _pages.Count)
            {
                _pages[_selectedPageIndex].OnGUI(_currentFolderPath);
            }
            EditorGUILayout.EndScrollView();
            
            EditorGUILayout.EndVertical();

            EditorGUILayout.EndHorizontal();
        }

        private void DrawSidebar()
        {
            GUILayout.Space(5);
            GUILayout.Label("工具列表", EditorStyles.largeLabel);
            GUILayout.Space(5);

            _sidebarScroll = EditorGUILayout.BeginScrollView(_sidebarScroll);

            string[] names = new string[_pages.Count];
            for (int i = 0; i < _pages.Count; i++) names[i] = _pages[i].PageName;

            int newIndex = GUILayout.SelectionGrid(_selectedPageIndex, names, 1, EditorStyles.toolbarButton);

            if (newIndex != _selectedPageIndex)
            {
                _pages[_selectedPageIndex].OnDisable();
                _selectedPageIndex = newIndex;
                _pages[_selectedPageIndex].OnEnable();
            }

            EditorGUILayout.EndScrollView();
        }
    }
}
