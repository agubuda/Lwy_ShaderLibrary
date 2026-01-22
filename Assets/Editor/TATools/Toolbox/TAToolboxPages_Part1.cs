using UnityEngine;
using UnityEditor;
using System.IO;
using System.Collections.Generic;
using System.Linq;

namespace TAToolbox
{
    // =========================================================
    // 1. 批量重命名工具 (保持不变)
    // =========================================================
    public class Page_BatchRename : TAToolPage
    {
        public override string PageName => "1. 批量重命名";
        
        public enum RenameMode { Anywhere = 0, Prefix = 1, Suffix = 2 }
        private string findText = "";
        private string replaceText = "";
        private bool recursive = false;
        private RenameMode currentMode = RenameMode.Anywhere;
        private List<string> previewLogs = new List<string>();
        private Vector2 scrollPos;

        public override void OnGUI(string rootPath)
        {
            DrawHeader("文件批量重命名 (Batch Rename)");

            recursive = EditorGUILayout.Toggle("包含子文件夹", recursive);
            GUILayout.Space(10);

            currentMode = (RenameMode)EditorGUILayout.EnumPopup("匹配模式:", currentMode);
            findText = EditorGUILayout.TextField("查找内容:", findText);
            replaceText = EditorGUILayout.TextField("替换为:", replaceText);

            if (currentMode == RenameMode.Suffix && !string.IsNullOrEmpty(findText))
                EditorGUILayout.HelpBox($"将在文件名末尾查找 \"{findText}\"", MessageType.Info);

            GUILayout.Space(15);
            GUILayout.BeginHorizontal();
            if (GUILayout.Button("预览变化", GUILayout.Height(30))) PreviewChanges(rootPath);
            
            GUI.backgroundColor = new Color(1f, 0.6f, 0.6f);
            if (GUILayout.Button("执行重命名", GUILayout.Height(30)))
            {
                if (EditorUtility.DisplayDialog("确认", $"即将处理: {rootPath}\n操作不可撤销！", "确定", "取消"))
                    ExecuteRename(rootPath);
            }
            GUI.backgroundColor = Color.white;
            GUILayout.EndHorizontal();

            GUILayout.Space(10);
            GUILayout.Label("日志:");
            scrollPos = EditorGUILayout.BeginScrollView(scrollPos, EditorStyles.helpBox, GUILayout.Height(200));
            foreach (var log in previewLogs) GUILayout.Label(log);
            EditorGUILayout.EndScrollView();
        }

        private string TryGetNewName(string originalFileName)
        {
            string nameNoExt = Path.GetFileNameWithoutExtension(originalFileName);
            string extension = Path.GetExtension(originalFileName);
            string newNameNoExt = nameNoExt;
            
            if (currentMode == RenameMode.Anywhere && !string.IsNullOrEmpty(findText) && nameNoExt.Contains(findText))
                newNameNoExt = nameNoExt.Replace(findText, replaceText);
            else if (currentMode == RenameMode.Prefix && !string.IsNullOrEmpty(findText) && nameNoExt.StartsWith(findText))
                newNameNoExt = replaceText + nameNoExt.Substring(findText.Length);
            else if (currentMode == RenameMode.Suffix && !string.IsNullOrEmpty(findText) && nameNoExt.EndsWith(findText))
                newNameNoExt = nameNoExt.Substring(0, nameNoExt.Length - findText.Length) + replaceText;

            return (newNameNoExt != nameNoExt) ? newNameNoExt + extension : null;
        }

        private void PreviewChanges(string rootPath)
        {
            previewLogs.Clear();
            string fullPath = GetFullPath(rootPath);
            if (!Directory.Exists(fullPath)) return;
            
            var files = Directory.GetFiles(fullPath, "*", recursive ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly);
            foreach (var file in files)
            {
                if (file.EndsWith(".meta")) continue;
                string newName = TryGetNewName(Path.GetFileName(file));
                if (!string.IsNullOrEmpty(newName)) previewLogs.Add($"[预览] {Path.GetFileName(file)} -> {newName}");
            }
        }

        private void ExecuteRename(string rootPath)
        {
            previewLogs.Clear();
            string fullPath = GetFullPath(rootPath);
            var files = Directory.GetFiles(fullPath, "*", recursive ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly);
            
            AssetDatabase.StartAssetEditing();
            foreach (var file in files)
            {
                if (file.EndsWith(".meta")) continue;
                string fileName = Path.GetFileName(file);
                string newName = TryGetNewName(fileName);
                if (string.IsNullOrEmpty(newName)) continue;

                string relativePath = "Assets" + file.Substring(Application.dataPath.Length).Replace('\\', '/');
                string error = AssetDatabase.RenameAsset(relativePath, newName);
                if (string.IsNullOrEmpty(error)) previewLogs.Add($"[成功] {fileName} -> {newName}");
                else previewLogs.Add($"[失败] {error}");
            }
            AssetDatabase.StopAssetEditing();
            AssetDatabase.Refresh();
        }
    }

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

            AssetDatabase.StartAssetEditing();
            int count = 0;
            
            try 
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
            finally
            {
                AssetDatabase.StopAssetEditing();
                AssetDatabase.Refresh();
                EditorUtility.DisplayDialog("完成", $"已处理 {count} 个贴图文件。", "确定");
                ScanTextures(AssetDatabase.GetAssetPath(Selection.activeObject)); // 刷新状态
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
    // =========================================================
    // 3. 快捷压缩预设 (保持不变)
    // =========================================================
    public class Page_TextureCompressionPreset : TAToolPage
    {
        public override string PageName => "3. 快捷压缩预设";

        public override void OnGUI(string rootPath)
        {
            DrawHeader("一键应用 Android 压缩预设");
            EditorGUILayout.HelpBox($"将对文件夹 '{rootPath}' 下所有贴图(Default/Sprite/Normal)生效", MessageType.Info);
            GUILayout.Space(10);

            if (GUILayout.Button("ASTC 4x4 + Max 2048 (高画质大图)", GUILayout.Height(40)))
                Process(rootPath, TextureImporterFormat.ASTC_4x4, 2048);
                
            if (GUILayout.Button("ASTC 4x4 + Max 1024 (高画质小图)", GUILayout.Height(40)))
                Process(rootPath, TextureImporterFormat.ASTC_4x4, 1024);
                
            GUILayout.Space(10);
            
            if (GUILayout.Button("ASTC 6x6 + Max 2048 (平衡大图)", GUILayout.Height(40)))
                Process(rootPath, TextureImporterFormat.ASTC_6x6, 2048);

            if (GUILayout.Button("ASTC 6x6 + Max 1024 (平衡小图)", GUILayout.Height(40)))
                Process(rootPath, TextureImporterFormat.ASTC_6x6, 1024);
        }

        private void Process(string rootPath, TextureImporterFormat fmt, int size)
        {
            string[] guids = AssetDatabase.FindAssets("t:Texture", new[] { rootPath });
            AssetDatabase.StartAssetEditing();
            foreach (var guid in guids)
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                TextureImporter imp = AssetImporter.GetAtPath(path) as TextureImporter;
                if (imp && (imp.textureType == TextureImporterType.Default || imp.textureType == TextureImporterType.Sprite || imp.textureType == TextureImporterType.NormalMap))
                {
                    var android = imp.GetPlatformTextureSettings("Android");
                    if (!android.overridden || android.format != fmt || android.maxTextureSize != size)
                    {
                        android.overridden = true;
                        android.name = "Android";
                        android.format = fmt;
                        android.maxTextureSize = size;
                        imp.SetPlatformTextureSettings(android);
                        imp.SaveAndReimport();
                    }
                }
            }
            AssetDatabase.StopAssetEditing();
            Debug.Log("预设应用完成。");
        }
    }

    // =========================================================
    // 4. 通道合并工具 (保持不变)
    // =========================================================
    // =========================================================
    // 4. 贴图通道合并工具 (支持大小写敏感设置)
    // =========================================================
    public class Page_TextureChannelPacker : TAToolPage
    {
        public override string PageName => "4. 贴图通道合并";
        public enum Ch { R=0, G=1, B=2, A=3 }
        
        private string srcSuffix = "_AO";
        private string dstSuffix = "_MetallicSmoothness";
        private Ch srcCh = Ch.R;
        private Ch dstCh = Ch.G;
        
        // 新增：大小写敏感开关 (默认开启，即严格匹配)
        private bool isCaseSensitive = true; 

        public override void OnGUI(string rootPath)
        {
            DrawHeader("贴图通道合并 (Packer)");
            
            srcSuffix = EditorGUILayout.TextField("源文件后缀:", srcSuffix);
            dstSuffix = EditorGUILayout.TextField("目标文件后缀:", dstSuffix);
            
            // 新增：复选框
            GUILayout.Space(2);
            isCaseSensitive = EditorGUILayout.Toggle("大小写敏感匹配", isCaseSensitive);

            GUILayout.Space(5);
            GUILayout.BeginHorizontal();
            srcCh = (Ch)EditorGUILayout.EnumPopup("源通道:", srcCh);
            GUILayout.Label("->");
            dstCh = (Ch)EditorGUILayout.EnumPopup("写入目标:", dstCh);
            GUILayout.EndHorizontal();

            string caseInfo = isCaseSensitive ? "严格匹配" : "忽略大小写";
            EditorGUILayout.HelpBox($"逻辑: 读取 [Name{srcSuffix}] 的 {srcCh} -> 写入 [Name{dstSuffix}] 的 {dstCh}\n({caseInfo})", MessageType.Info);
            
            GUILayout.Space(10);
            if (GUILayout.Button("执行合并", GUILayout.Height(40))) Pack(rootPath);
        }

        private void Pack(string rootPath)
        {
            string[] guids = AssetDatabase.FindAssets("t:Texture2D", new[] { rootPath });
            var targetPaths = new List<string>();
            var srcMap = new Dictionary<string, string>();

            // 确定比较模式
            System.StringComparison compareMode = isCaseSensitive ? 
                System.StringComparison.Ordinal : 
                System.StringComparison.OrdinalIgnoreCase;

            foreach(var g in guids)
            {
                string p = AssetDatabase.GUIDToAssetPath(g);
                string n = Path.GetFileNameWithoutExtension(p);

                // 使用带 StringComparison 参数的 EndsWith
                if (n.EndsWith(dstSuffix, compareMode)) 
                {
                    targetPaths.Add(p);
                }
                else if (n.EndsWith(srcSuffix, compareMode)) 
                {
                    // 提取基础名称 (BaseName)
                    // 无论大小写如何，只要匹配了后缀，就按长度截取前面的部分作为 Key
                    string baseKey = n.Substring(0, n.Length - srcSuffix.Length);
                    
                    // 如果忽略大小写，为了保证匹配，Key 统一转小写存储（防止 Name_AO 和 name_Metallic 这种前缀大小写也不一致的情况）
                    if (!isCaseSensitive) baseKey = baseKey.ToLower();

                    if (!srcMap.ContainsKey(baseKey))
                    {
                        srcMap.Add(baseKey, p);
                    }
                }
            }

            int count = 0;
            foreach(var tgtPath in targetPaths)
            {
                string tgtName = Path.GetFileNameWithoutExtension(tgtPath);
                
                // 同样逻辑提取 Target 的 BaseName
                string baseName = tgtName.Substring(0, tgtName.Length - dstSuffix.Length);
                
                // 如果忽略大小写，Key 也要转小写来查找
                string searchKey = isCaseSensitive ? baseName : baseName.ToLower();

                if (srcMap.ContainsKey(searchKey))
                {
                    EditorUtility.DisplayProgressBar("Merging", baseName, 0.5f);
                    DoMerge(tgtPath, srcMap[searchKey]);
                    count++;
                }
            }
            EditorUtility.ClearProgressBar();
            AssetDatabase.Refresh();
            Debug.Log($"合并了 {count} 对贴图。");
        }

        private void DoMerge(string tPath, string sPath)
        {
            var tImp = ForceRead(tPath);
            var sImp = ForceRead(sPath);
            
            Texture2D tTex = AssetDatabase.LoadAssetAtPath<Texture2D>(tPath);
            Texture2D sTex = AssetDatabase.LoadAssetAtPath<Texture2D>(sPath);
            
            // 简单校验尺寸
            if (tTex.width == sTex.width && tTex.height == sTex.height)
            {
                Color[] tPix = tTex.GetPixels();
                Color[] sPix = sTex.GetPixels();
                for(int i=0; i<tPix.Length; i++)
                {
                    float val = GetVal(sPix[i], srcCh);
                    SetVal(ref tPix[i], dstCh, val);
                }
                
                Texture2D res = new Texture2D(tTex.width, tTex.height, TextureFormat.RGBA32, false);
                res.SetPixels(tPix);
                res.Apply();
                
                string sysPath = Application.dataPath.Replace("Assets", "") + tPath;
                File.WriteAllBytes(sysPath, res.EncodeToPNG());
                Object.DestroyImmediate(res);
            }
            else
            {
                Debug.LogWarning($"尺寸不匹配，跳过: {Path.GetFileName(tPath)} vs {Path.GetFileName(sPath)}");
            }
            
            Revert(tImp);
            Revert(sImp);
        }

        private float GetVal(Color c, Ch ch) => ch==Ch.R?c.r : ch==Ch.G?c.g : ch==Ch.B?c.b : c.a;
        private void SetVal(ref Color c, Ch ch, float v) { if(ch==Ch.R)c.r=v; else if(ch==Ch.G)c.g=v; else if(ch==Ch.B)c.b=v; else c.a=v; }
        
        private TextureImporter ForceRead(string p) {
            var imp = AssetImporter.GetAtPath(p) as TextureImporter;
            // 只有当不可读时才重新导入，减少等待时间
            if(!imp.isReadable) { imp.isReadable=true; imp.textureCompression = TextureImporterCompression.Uncompressed; imp.SaveAndReimport(); }
            return imp;
        }
        private void Revert(TextureImporter imp) { 
            // 恢复为不可读，并改回压缩 (这里默认改回 Compressed，如果原图是其他设置可能需要更复杂的逻辑备份)
            imp.isReadable=false; 
            imp.textureCompression=TextureImporterCompression.Compressed; 
            imp.SaveAndReimport(); 
        }
    }
}
