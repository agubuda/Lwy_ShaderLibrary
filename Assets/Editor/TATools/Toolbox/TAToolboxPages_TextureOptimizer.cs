using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace TAToolbox
{
    // =========================================================
    // 2. 贴图综合优化工具 (ASTC/Size/sRGB/筛选增强)
    // =========================================================
    public class Page_TextureOptimizer : TAToolPage
    {
        public override string PageName => "2. 贴图综合优化 (ASTC/Size/sRGB)";

        // --- 数据结构 ---
        public class TexItem 
        { 
            public string path; 
            public int w, h; 
            public bool isSelected = true; 
            public string name;
            public bool isSRGB; // 当前的 sRGB 状态
        }

        // --- 选项 ---
        public enum ProcessMode { ResizeOnly = 0, ResizeAndASTC = 1 }
        public enum ASTCBlockSize { _4x4_High = 0, _5x5 = 1, _6x6_Balanced = 2, _8x8 = 3, _10x10 = 4, _12x12_Low = 5 }
        public enum MaxTextureSize { _32 = 32, _64 = 64, _128 = 128, _256 = 256, _512 = 512, _1024 = 1024, _2048 = 2048, _4096 = 4096 }
        public enum MatchMode { Anywhere = 0, Prefix = 1, Suffix = 2 }

        // --- 状态变量 ---
        private ProcessMode mode = ProcessMode.ResizeAndASTC;
        private MaxTextureSize targetSize = MaxTextureSize._2048;
        private ASTCBlockSize targetASTC = ASTCBlockSize._6x6_Balanced;
        private bool applyAndroid = true;
        private bool applyiOS = true;

        // sRGB 设置
        private bool changeSRGB = false; // 是否启用 sRGB 修改
        private bool targetSRGB = true;  // 目标是否为 sRGB (true=Color, false=Linear)

        // 筛选
        private bool recursive = true;
        private string searchKeyword = "";
        private MatchMode matchMode = MatchMode.Anywhere;
        private bool ignoreCase = true; // 是否忽略大小写
        private int minFilterSize = 0; 

        // 列表
        private List<TexItem> itemList = new List<TexItem>();
        private Vector2 scrollPos;

        public override void OnGUI(string rootPath)
        {
            DrawHeader("贴图分辨率、压缩与 sRGB 设置");

            // 1. 筛选区域
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            GUILayout.Label("第一步：筛选", EditorStyles.boldLabel);
            
            // 搜索栏：模式 | 关键字 | 忽略大小写
            EditorGUILayout.BeginHorizontal();
            GUILayout.Label("文件名匹配:", GUILayout.Width(70));
            matchMode = (MatchMode)EditorGUILayout.EnumPopup(matchMode, GUILayout.Width(80));
            // 提示：留空则匹配所有
            GUI.SetNextControlName("SearchInput");
            searchKeyword = EditorGUILayout.TextField(searchKeyword);
            if (string.IsNullOrEmpty(searchKeyword))
            {
                // 在输入框绘制淡色提示文字 (Placeholder)
                Rect r = GUILayoutUtility.GetLastRect();
                if (Event.current.type == EventType.Repaint)
                {
                    GUIStyle placeholderStyle = new GUIStyle(EditorStyles.label);
                    placeholderStyle.normal.textColor = Color.gray;
                    placeholderStyle.padding = EditorStyles.textField.padding;
                    GUI.Label(r, " (留空则扫描全部)", placeholderStyle);
                }
            }
            ignoreCase = EditorGUILayout.ToggleLeft("忽略大小写", ignoreCase, GUILayout.Width(85));
            EditorGUILayout.EndHorizontal();

            // 路径与尺寸过滤
            EditorGUILayout.BeginHorizontal();
            recursive = EditorGUILayout.ToggleLeft("包含子文件夹", recursive, GUILayout.Width(100));
            minFilterSize = EditorGUILayout.IntField("忽略小于尺寸:", minFilterSize);
            EditorGUILayout.EndHorizontal();
            
            GUILayout.Space(5);
            if (GUILayout.Button("扫描贴图文件", GUILayout.Height(25))) ScanTextures(rootPath);
            EditorGUILayout.EndVertical();

            // 2. 设置区域
            GUILayout.Space(10);
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            GUILayout.Label("第二步：设置参数", EditorStyles.boldLabel);
            
            // --- sRGB 设置 ---
            EditorGUILayout.BeginHorizontal();
            changeSRGB = EditorGUILayout.ToggleLeft("修改 sRGB 设置", changeSRGB, GUILayout.Width(120));
            if (changeSRGB)
            {
                targetSRGB = EditorGUILayout.Toggle(targetSRGB, GUILayout.Width(20));
                GUILayout.Label(targetSRGB ? "设为 sRGB (用于颜色贴图)" : "设为 Linear (用于法线/Mask/数据图)");
            }
            EditorGUILayout.EndHorizontal();
            GUILayout.Space(5);

            // --- 分辨率与压缩 ---
            mode = (ProcessMode)EditorGUILayout.EnumPopup("压缩处理模式:", mode);
            targetSize = (MaxTextureSize)EditorGUILayout.EnumPopup("最大分辨率 (Max Size):", targetSize);

            if (mode == ProcessMode.ResizeAndASTC)
            {
                targetASTC = (ASTCBlockSize)EditorGUILayout.EnumPopup("ASTC 块大小:", targetASTC);
                EditorGUILayout.BeginHorizontal();
                GUILayout.Label("应用平台:", GUILayout.Width(70));
                applyAndroid = EditorGUILayout.ToggleLeft("Android", applyAndroid, GUILayout.Width(70));
                applyiOS = EditorGUILayout.ToggleLeft("iOS", applyiOS, GUILayout.Width(70));
                EditorGUILayout.EndHorizontal();
                
                string hint = targetASTC == ASTCBlockSize._4x4_High ? "高质量 (UI/主角)" : 
                              targetASTC == ASTCBlockSize._6x6_Balanced ? "平衡 (推荐)" : "高压缩 (特效/次要)";
                EditorGUILayout.HelpBox($"ASTC {targetASTC}: {hint}", MessageType.Info);
            }
            EditorGUILayout.EndVertical();

            // 3. 列表与执行
            GUILayout.Space(10);
            if (itemList.Count > 0)
            {
                GUILayout.Label($"预览列表 ({itemList.Count(x => x.isSelected)}/{itemList.Count}):");
                
                EditorGUILayout.BeginHorizontal();
                if (GUILayout.Button("全选", EditorStyles.miniButton)) itemList.ForEach(x => x.isSelected = true);
                if (GUILayout.Button("全不选", EditorStyles.miniButton)) itemList.ForEach(x => x.isSelected = false);
                EditorGUILayout.EndHorizontal();

                scrollPos = EditorGUILayout.BeginScrollView(scrollPos, EditorStyles.helpBox, GUILayout.Height(200));
                foreach (var item in itemList)
                {
                    EditorGUILayout.BeginHorizontal();
                    item.isSelected = EditorGUILayout.Toggle(item.isSelected, GUILayout.Width(20));
                    
                    // 状态检查与颜色标记
                    bool needsResize = Mathf.Max(item.w, item.h) > (int)targetSize;
                    bool needsSRGBChange = changeSRGB && (item.isSRGB != targetSRGB);
                    
                    if (needsResize || needsSRGBChange) GUI.color = new Color(1f, 0.9f, 0.8f);
                    else GUI.color = Color.white;
                    
                    GUILayout.Label(item.name, GUILayout.Width(160));
                    GUILayout.Label($"{item.w}x{item.h}", GUILayout.Width(70));
                    GUILayout.Label(item.isSRGB ? "[sRGB]" : "[Linear]", GUILayout.Width(60));
                    
                    string op = "";
                    if (needsSRGBChange) op += targetSRGB ? "->sRGB " : "->Linear ";
                    if (mode == ProcessMode.ResizeAndASTC) op += "+ASTC";
                    else if (needsResize) op += "+Resize";
                    
                    GUILayout.Label(op, EditorStyles.miniLabel);

                    GUI.color = Color.white;
                    EditorGUILayout.EndHorizontal();
                }
                EditorGUILayout.EndScrollView();

                GUILayout.Space(5);
                GUI.backgroundColor = Color.green;
                if (GUILayout.Button("开始批量处理", GUILayout.Height(35))) ApplySettings();
                GUI.backgroundColor = Color.white;
            }
        }

        private void ScanTextures(string rootPath)
        {
            itemList.Clear();
            string[] guids = AssetDatabase.FindAssets("t:Texture", new[] { rootPath });
            
            // 1. 获取并处理搜索关键词 (Trim去除空格)
            // 如果 input 为 null 或 "" 或 "  "，cleanKeyword 都会是 ""
            string cleanKeyword = searchKeyword == null ? "" : searchKeyword.Trim();
            
            // 2. 根据大小写设置预处理关键词
            string keywordToCheck = ignoreCase ? cleanKeyword.ToLower() : cleanKeyword;
            
            foreach (var guid in guids)
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                
                // 路径筛选
                if (!recursive && Path.GetDirectoryName(path).Replace("\\", "/") != rootPath) continue;

                string name = Path.GetFileNameWithoutExtension(path);
                // 根据大小写设置预处理文件名
                string nameToCheck = ignoreCase ? name.ToLower() : name;

                // 核心匹配逻辑：只有当关键词不为空时才进行筛选
                if (!string.IsNullOrEmpty(keywordToCheck))
                {
                    bool isMatch = false;
                    switch (matchMode)
                    {
                        case MatchMode.Anywhere:
                            isMatch = nameToCheck.Contains(keywordToCheck);
                            break;
                        case MatchMode.Prefix:
                            isMatch = nameToCheck.StartsWith(keywordToCheck);
                            break;
                        case MatchMode.Suffix:
                            isMatch = nameToCheck.EndsWith(keywordToCheck);
                            break;
                    }
                    if (!isMatch) continue; // 不匹配则跳过，如果不进入这里，说明匹配或关键词为空
                }

                TextureImporter imp = AssetImporter.GetAtPath(path) as TextureImporter;
                if (imp == null) continue;
                
                int w = 0, h = 0;
                Texture2D tex = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
                if (tex != null) { w = tex.width; h = tex.height; }
                
                // 尺寸筛选
                if (w < minFilterSize && h < minFilterSize) continue;

                itemList.Add(new TexItem 
                { 
                    path = path, 
                    w = w, 
                    h = h, 
                    name = Path.GetFileName(path),
                    isSelected = true,
                    isSRGB = imp.sRGBTexture
                });
            }
        }

        private void ApplySettings()
        {
            var targets = itemList.Where(x => x.isSelected).ToList();
            if (targets.Count == 0) return;
            string scanRootPath = Selection.activeObject != null ? AssetDatabase.GetAssetPath(Selection.activeObject) : null;
            if (!AssetDatabase.IsValidFolder(scanRootPath)) scanRootPath = "Assets";

            int count = 0;

            try 
            {
                using (new AssetEditingScope())
                {
                    for (int i = 0; i < targets.Count; i++)
                    {
                        var item = targets[i];
                        TextureImporter imp = AssetImporter.GetAtPath(item.path) as TextureImporter;
                        if (imp == null) continue;

                        bool changed = false;
                        int maxSz = (int)targetSize;

                        // 1. 设置 sRGB
                        if (changeSRGB && imp.sRGBTexture != targetSRGB)
                        {
                            imp.sRGBTexture = targetSRGB;
                            changed = true;
                        }

                        // 2. 设置 Max Texture Size
                        if (imp.maxTextureSize != maxSz)
                        {
                            imp.maxTextureSize = maxSz;
                            changed = true;
                        }

                        // 3. 设置压缩 (ASTC)
                        if (mode == ProcessMode.ResizeAndASTC)
                        {
                            TextureImporterFormat astcFmt = GetUnityFormat(targetASTC);
                            if (applyAndroid) changed |= SetPlatformSettings(imp, "Android", maxSz, astcFmt);
                            if (applyiOS) changed |= SetPlatformSettings(imp, "iPhone", maxSz, astcFmt);
                        }

                        if (changed)
                        {
                            imp.SaveAndReimport();
                            count++;
                        }
                    }
                }
            }
            finally
            {
                AssetDatabase.Refresh();
                EditorUtility.DisplayDialog("完成", $"已处理 {count} 个贴图文件。", "确定");
                ScanTextures(scanRootPath);
            }
        }

        private bool SetPlatformSettings(TextureImporter imp, string platform, int size, TextureImporterFormat fmt)
        {
            var settings = imp.GetPlatformTextureSettings(platform);
            if (!settings.overridden || settings.maxTextureSize != size || settings.format != fmt)
            {
                settings.overridden = true;
                settings.name = platform;
                settings.maxTextureSize = size;
                settings.format = fmt;
                imp.SetPlatformTextureSettings(settings);
                return true;
            }
            return false;
        }

        private TextureImporterFormat GetUnityFormat(ASTCBlockSize size)
        {
            switch(size) {
                case ASTCBlockSize._4x4_High: return TextureImporterFormat.ASTC_4x4;
                case ASTCBlockSize._5x5: return TextureImporterFormat.ASTC_5x5;
                case ASTCBlockSize._8x8: return TextureImporterFormat.ASTC_8x8;
                case ASTCBlockSize._10x10: return TextureImporterFormat.ASTC_10x10;
                case ASTCBlockSize._12x12_Low: return TextureImporterFormat.ASTC_12x12;
                default: return TextureImporterFormat.ASTC_6x6;
            }
        }
    }
}
