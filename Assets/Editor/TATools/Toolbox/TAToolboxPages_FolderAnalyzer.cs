using UnityEngine;
using UnityEditor;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using UnityEngine.Profiling;

namespace TAToolbox
{
    // =========================================================
    // 文件夹资源大小分析工具 (斑马线列表 + 点击跳转)
    // =========================================================
    public class Page_FolderSizeAnalyzer : TAToolPage
    {
        public override string PageName => "10.文件夹大小分析";

        // --- 数据结构 ---
        private class FolderNode
        {
            public string folderName;
            public string assetPath;    
            public long selfSize;       
            public long totalSize;      
            public List<FolderNode> children = new List<FolderNode>();
            public bool isExpanded = true; 
        }

        private FolderNode rootNode;
        private Vector2 scrollPos;
        private bool sortBySize = true;
        
        // 用于计算行数，实现明暗交替
        private int rowCounter = 0;

        public override void OnGUI(string rootPath)
        {
            DrawHeader("文件夹资源大小统计 (Runtime Size)");

            EditorGUILayout.HelpBox(
                "统计说明：\n" +
                "1. 数据为 Unity 导入后的运行时内存占用 (压缩后大小)。\n" +
                "2. 点击文件夹名称可在 Project 窗口中定位。\n" +
                "3. 奇偶行底色不同，方便查看对应数据。", 
                MessageType.Info);

            GUILayout.Space(10);
            
            // --- 顶部控制栏 ---
            GUILayout.BeginHorizontal();
            sortBySize = EditorGUILayout.ToggleLeft("按大小降序排列", sortBySize, GUILayout.Width(120));
            GUILayout.FlexibleSpace();
            if (GUILayout.Button("开始分析", GUILayout.Height(25), GUILayout.Width(120)))
            {
                AnalyzeFolder(rootPath);
            }
            GUILayout.EndHorizontal();

            GUILayout.Space(5);
            
            // --- 列表表头 ---
            if (rootNode != null)
            {
                EditorGUILayout.BeginHorizontal(EditorStyles.toolbar);
                GUILayout.Label("文件夹层级", GUILayout.MinWidth(200));
                GUILayout.FlexibleSpace(); 
                GUILayout.Label("总大小 (含子)", GUILayout.Width(80));
                GUILayout.Space(10);
                GUILayout.Label("文件大小", GUILayout.Width(80));
                GUILayout.Space(20); 
                EditorGUILayout.EndHorizontal();

                // --- 列表内容区 ---
                scrollPos = EditorGUILayout.BeginScrollView(scrollPos);
                
                // 重置行计数器
                rowCounter = 0;
                DrawNode(rootNode, 0);
                
                EditorGUILayout.EndScrollView();
                
                // --- 底部总计 ---
                GUILayout.BeginHorizontal(EditorStyles.helpBox);
                GUILayout.Label("统计结果:", EditorStyles.boldLabel);
                GUILayout.FlexibleSpace();
                GUILayout.Label($"总计资源: {EditorUtility.FormatBytes(rootNode.totalSize)}", EditorStyles.boldLabel);
                GUILayout.EndHorizontal();
            }
        }

        /// <summary>
        /// 递归绘制节点
        /// </summary>
        private void DrawNode(FolderNode node, int indentLevel)
        {
            // 1. 获取行的 Rect，强制高度 20，让排版更整齐
            Rect rowRect = EditorGUILayout.BeginHorizontal(GUILayout.Height(20));
            
            // 2. 绘制斑马线底色 (明暗交替)
            // 只有当行号为奇数时，绘制一个淡淡的黑底，形成明暗差
            if (rowCounter % 2 != 0)
            {
                // 使用 alpha=0.1 的黑色，在 Light/Dark 皮肤下都能产生变暗的效果
                EditorGUI.DrawRect(rowRect, new Color(0, 0, 0, 0.05f));
            }

            // 3. 缩进处理
            GUILayout.Space(indentLevel * 15);
            
            // 4. 折叠箭头
            if (node.children.Count > 0)
            {
                node.isExpanded = EditorGUILayout.Foldout(node.isExpanded, GUIContent.none, true);
            }
            else
            {
                GUILayout.Space(12);
            }

            // 5. 文件夹名称 (点击跳转)
            GUIContent content = new GUIContent(node.folderName, "点击定位");
            // 微调 label 样式，让文字垂直居中
            GUIStyle alignStyle = new GUIStyle(EditorStyles.label);
            alignStyle.alignment = TextAnchor.MiddleLeft;
            
            if (GUILayout.Button(content, alignStyle, GUILayout.Height(20)))
            {
                PingFolder(node.assetPath);
            }

            GUILayout.FlexibleSpace();

            // 6. 数据显示样式 (右对齐 + 垂直居中)
            GUIStyle numberStyle = new GUIStyle(EditorStyles.label);
            numberStyle.alignment = TextAnchor.MiddleRight;
            numberStyle.fixedHeight = 20; // 确保高度一致
            
            // 颜色高亮
            if (node.totalSize > 1024 * 1024 * 10) numberStyle.normal.textColor = new Color(1f, 0.4f, 0.4f);
            else if (node.totalSize > 1024 * 1024) numberStyle.normal.textColor = new Color(1f, 0.8f, 0.2f);

            GUILayout.Label(EditorUtility.FormatBytes(node.totalSize), numberStyle, GUILayout.Width(80));
            GUILayout.Space(10);

            // 7. 自身文件大小
            GUIStyle selfStyle = new GUIStyle(numberStyle);
            if (node.selfSize == 0) selfStyle.normal.textColor = Color.gray;
            else selfStyle.normal.textColor = EditorStyles.label.normal.textColor; // 恢复默认色
            
            GUILayout.Label(node.selfSize > 0 ? EditorUtility.FormatBytes(node.selfSize) : "-", selfStyle, GUILayout.Width(80));

            EditorGUILayout.EndHorizontal();
            
            // 行数加一
            rowCounter++;

            // 递归绘制子节点
            if (node.isExpanded && node.children.Count > 0)
            {
                foreach (var child in node.children)
                {
                    DrawNode(child, indentLevel + 1);
                }
            }
        }

        private void PingFolder(string assetPath)
        {
            if (string.IsNullOrEmpty(assetPath)) return;
            Object obj = AssetDatabase.LoadAssetAtPath<Object>(assetPath);
            if (obj != null)
            {
                EditorGUIUtility.PingObject(obj); 
                Selection.activeObject = obj;     
            }
        }

        // =========================================================
        // 核心分析逻辑
        // =========================================================

        private void AnalyzeFolder(string rootPath)
        {
            rootNode = null;
            string fullPath = GetFullPath(rootPath);
            
            if (!Directory.Exists(fullPath)) 
            {
                EditorUtility.DisplayDialog("提示", "无效的文件夹路径", "确定");
                return;
            }

            try
            {
                rootNode = BuildTreeRecursive(fullPath);
                
                if (EditorWindow.HasOpenInstances<TAToolboxWindow>())
                {
                    EditorWindow.GetWindow<TAToolboxWindow>().Repaint();
                }
            }
            catch (System.Exception e)
            {
                Debug.LogError($"分析出错: {e.Message}");
            }
            finally
            {
                EditorUtility.ClearProgressBar();
            }
        }

        private FolderNode BuildTreeRecursive(string absolutePath)
        {
            FolderNode node = new FolderNode();
            
            string assetPath = "Assets" + absolutePath.Substring(Application.dataPath.Length).Replace('\\', '/');
            node.assetPath = assetPath;
            node.folderName = Path.GetFileName(absolutePath);
            if (string.IsNullOrEmpty(node.folderName)) node.folderName = "Assets"; 

            // 1. 统计文件
            string[] files = Directory.GetFiles(absolutePath);
            long currentFolderSize = 0;
            
            int count = 0;
            foreach (var file in files)
            {
                if (file.EndsWith(".meta")) continue;

                if (count % 10 == 0) 
                {
                    if (EditorUtility.DisplayCancelableProgressBar("正在分析...", $"正在计算: {Path.GetFileName(file)}", 0.5f))
                        throw new System.Exception("用户取消");
                }
                count++;

                string fileAssetPath = "Assets" + file.Substring(Application.dataPath.Length).Replace('\\', '/');
                currentFolderSize += GetRuntimeMemorySize(fileAssetPath);
            }
            
            node.selfSize = currentFolderSize;
            node.totalSize = currentFolderSize;

            // 2. 统计子文件夹
            string[] subDirs = Directory.GetDirectories(absolutePath);
            foreach (var subDir in subDirs)
            {
                FolderNode childNode = BuildTreeRecursive(subDir);
                if (childNode != null)
                {
                    node.children.Add(childNode);
                    node.totalSize += childNode.totalSize;
                }
            }

            // 3. 排序
            if (sortBySize)
                node.children = node.children.OrderByDescending(c => c.totalSize).ToList();
            else
                node.children = node.children.OrderBy(c => c.folderName).ToList();

            return node;
        }

        private long GetRuntimeMemorySize(string assetPath)
        {
            Object asset = AssetDatabase.LoadAssetAtPath<Object>(assetPath);
            if (asset == null) return 0;
            return Profiler.GetRuntimeMemorySizeLong(asset);
        }
    }
}
