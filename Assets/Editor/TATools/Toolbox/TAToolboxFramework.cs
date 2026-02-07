using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System;
using System.IO;
using System.Linq;

namespace TAToolbox
{
    public sealed class AssetEditingScope : IDisposable
    {
        private bool _disposed;

        public AssetEditingScope()
        {
            AssetDatabase.StartAssetEditing();
        }

        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;
            AssetDatabase.StopAssetEditing();
        }
    }

    /// <summary>
    /// 所有工具页面的基类
    /// </summary>
    public abstract class TAToolPage
    {
        public abstract string PageName { get; }
        public virtual string Category => null;

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

        protected HashSet<string> ParseExtensions(string extensionsText)
        {
            var result = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            if (string.IsNullOrWhiteSpace(extensionsText)) return result;

            string[] items = extensionsText.Split(new[] { ';', ',', '|' }, StringSplitOptions.RemoveEmptyEntries);
            foreach (string rawItem in items)
            {
                string ext = rawItem.Trim();
                if (string.IsNullOrEmpty(ext)) continue;
                if (!ext.StartsWith(".")) ext = "." + ext;
                result.Add(ext);
            }

            return result;
        }

        protected bool HasMatchingExtension(string filePath, HashSet<string> extensions)
        {
            if (extensions == null || extensions.Count == 0) return false;
            string ext = Path.GetExtension(filePath);
            return !string.IsNullOrEmpty(ext) && extensions.Contains(ext);
        }
    }

    /// <summary>
    /// 工具箱主窗口
    /// </summary>
    public class TAToolboxWindow : EditorWindow
    {
        private class SidebarGroup
        {
            public string Name;
            public List<int> PageIndices = new List<int>();
        }

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
            RegisterPagesByDiscovery();

            // 初始化选中
            if (_pages.Count > 0)
            {
                _selectedPageIndex = Mathf.Clamp(_selectedPageIndex, 0, _pages.Count - 1);
                _pages[_selectedPageIndex].OnEnable();
            }
            UpdateSelection();
        }

        private void RegisterPagesByDiscovery()
        {
            _pages.Clear();

            var discoveredPages = new List<TAToolPage>();
            foreach (Type pageType in TypeCache.GetTypesDerivedFrom<TAToolPage>())
            {
                if (pageType == null || pageType.IsAbstract || pageType.IsInterface) continue;
                if (pageType.GetConstructor(Type.EmptyTypes) == null) continue;

                try
                {
                    if (Activator.CreateInstance(pageType) is TAToolPage page)
                    {
                        discoveredPages.Add(page);
                    }
                }
                catch (Exception ex)
                {
                    Debug.LogError($"[TAToolbox] 页面创建失败: {pageType.FullName}\n{ex.Message}");
                }
            }

            _pages = discoveredPages
                .OrderBy(page => GetPageOrder(page.PageName))
                .ThenBy(page => page.PageName, StringComparer.Ordinal)
                .ToList();
        }

        private static int GetPageOrder(string pageName)
        {
            if (string.IsNullOrWhiteSpace(pageName)) return int.MaxValue;

            int index = 0;
            while (index < pageName.Length && char.IsWhiteSpace(pageName[index])) index++;

            int numberStart = index;
            while (index < pageName.Length && char.IsDigit(pageName[index])) index++;

            if (numberStart == index) return int.MaxValue;
            string numberText = pageName.Substring(numberStart, index - numberStart);
            if (int.TryParse(numberText, out int order)) return order;

            return int.MaxValue;
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
            UnityEngine.Object obj = Selection.activeObject;
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
            else
            {
                EditorGUILayout.HelpBox("未发现可用页面，请检查页面类是否继承 TAToolPage 且有无参构造。", MessageType.Warning);
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

            if (_pages.Count == 0)
            {
                EditorGUILayout.HelpBox("暂无页面", MessageType.Info);
                return;
            }

            _sidebarScroll = EditorGUILayout.BeginScrollView(_sidebarScroll);

            List<SidebarGroup> groups = BuildSidebarGroups();
            foreach (SidebarGroup group in groups)
            {
                GUILayout.Space(3);
                GUILayout.Label(group.Name, EditorStyles.boldLabel);

                foreach (int pageIndex in group.PageIndices)
                {
                    bool isSelected = pageIndex == _selectedPageIndex;
                    bool clicked = GUILayout.Toggle(isSelected, GetDisplayPageName(_pages[pageIndex].PageName), EditorStyles.toolbarButton);
                    if (clicked && !isSelected)
                    {
                        SwitchPage(pageIndex);
                    }
                }
            }

            EditorGUILayout.EndScrollView();
        }

        private void SwitchPage(int newIndex)
        {
            if (newIndex < 0 || newIndex >= _pages.Count || newIndex == _selectedPageIndex) return;

            if (_selectedPageIndex >= 0 && _selectedPageIndex < _pages.Count)
            {
                _pages[_selectedPageIndex].OnDisable();
            }

            _selectedPageIndex = newIndex;
            _pages[_selectedPageIndex].OnEnable();
        }

        private List<SidebarGroup> BuildSidebarGroups()
        {
            var groups = new List<SidebarGroup>();
            var groupMap = new Dictionary<string, SidebarGroup>(StringComparer.Ordinal);

            for (int i = 0; i < _pages.Count; i++)
            {
                string category = ResolveCategory(_pages[i]);
                if (!groupMap.TryGetValue(category, out SidebarGroup group))
                {
                    group = new SidebarGroup { Name = category };
                    groupMap[category] = group;
                    groups.Add(group);
                }

                group.PageIndices.Add(i);
            }

            return groups;
        }

        private string ResolveCategory(TAToolPage page)
        {
            if (!string.IsNullOrWhiteSpace(page.Category)) return page.Category.Trim();
            return InferCategory(page.GetType().Name, page.PageName);
        }

        private static string InferCategory(string typeName, string pageName)
        {
            string typeText = typeName ?? string.Empty;
            string nameText = pageName ?? string.Empty;
            string merged = (typeText + "|" + nameText).ToLowerInvariant();

            if (merged.Contains("texture") || merged.Contains("贴图")) return "贴图工具";
            if (merged.Contains("material") || merged.Contains("shader") || merged.Contains("材质")) return "材质工具";
            if (merged.Contains("fbx") || merged.Contains("heatmap") || merged.Contains("模型") || merged.Contains("动画")) return "模型动画";
            if (merged.Contains("artsync") || merged.Contains("同步")) return "外部同步";
            if (merged.Contains("folder") || merged.Contains("rename") || merged.Contains("capture") || merged.Contains("文件") || merged.Contains("截图")) return "通用工具";

            return "未分类";
        }

        private static string GetDisplayPageName(string pageName)
        {
            if (string.IsNullOrWhiteSpace(pageName)) return "未命名页面";

            int index = 0;
            while (index < pageName.Length && char.IsWhiteSpace(pageName[index])) index++;

            int numberStart = index;
            while (index < pageName.Length && char.IsDigit(pageName[index])) index++;

            if (numberStart == index) return pageName.Trim();

            while (index < pageName.Length)
            {
                char c = pageName[index];
                if (char.IsWhiteSpace(c) || c == '.' || c == '。' || c == '、' || c == '-' || c == '_')
                {
                    index++;
                    continue;
                }
                break;
            }

            if (index >= pageName.Length) return pageName.Trim();
            return pageName.Substring(index).Trim();
        }
    }
}
