using UnityEngine;
using UnityEditor;
using System.IO;
using System.Collections.Generic;

namespace TAToolbox
{
    // =========================================================
    // 4. 贴图通道合并工具 (支持大小写敏感设置)
    // =========================================================
    public class Page_TextureChannelPacker : TAToolPage
    {
        public override string PageName => "4. 贴图通道合并";
        public enum Ch { R=0, G=1, B=2, A=3 }

        private struct ImporterState
        {
            public bool isReadable;
            public TextureImporterCompression textureCompression;
        }
        
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
            try
            {
                for (int i = 0; i < targetPaths.Count; i++)
                {
                    string tgtPath = targetPaths[i];
                    string tgtName = Path.GetFileNameWithoutExtension(tgtPath);

                    // 同样逻辑提取 Target 的 BaseName
                    string baseName = tgtName.Substring(0, tgtName.Length - dstSuffix.Length);

                    // 如果忽略大小写，Key 也要转小写来查找
                    string searchKey = isCaseSensitive ? baseName : baseName.ToLower();

                    if (srcMap.ContainsKey(searchKey))
                    {
                        float progress = targetPaths.Count == 0 ? 1f : (float)i / targetPaths.Count;
                        EditorUtility.DisplayCancelableProgressBar("Merging", baseName, progress);
                        DoMerge(tgtPath, srcMap[searchKey]);
                        count++;
                    }
                }
            }
            finally
            {
                EditorUtility.ClearProgressBar();
            }
            AssetDatabase.Refresh();
            Debug.Log($"合并了 {count} 对贴图。");
        }

        private void DoMerge(string tPath, string sPath)
        {
            ImporterState tState;
            ImporterState sState;
            var tImp = ForceRead(tPath, out tState);
            var sImp = ForceRead(sPath, out sState);
            
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
            
            Revert(tImp, tState);
            Revert(sImp, sState);
        }

        private float GetVal(Color c, Ch ch) => ch==Ch.R?c.r : ch==Ch.G?c.g : ch==Ch.B?c.b : c.a;
        private void SetVal(ref Color c, Ch ch, float v) { if(ch==Ch.R)c.r=v; else if(ch==Ch.G)c.g=v; else if(ch==Ch.B)c.b=v; else c.a=v; }
        
        private TextureImporter ForceRead(string p, out ImporterState state) {
            var imp = AssetImporter.GetAtPath(p) as TextureImporter;
            state = new ImporterState
            {
                isReadable = imp.isReadable,
                textureCompression = imp.textureCompression
            };
            // 只有当不可读时才重新导入，减少等待时间
            if(!imp.isReadable) { imp.isReadable=true; imp.textureCompression = TextureImporterCompression.Uncompressed; imp.SaveAndReimport(); }
            return imp;
        }
        private void Revert(TextureImporter imp, ImporterState state) {
            if (imp.isReadable == state.isReadable && imp.textureCompression == state.textureCompression) return;
            imp.isReadable = state.isReadable;
            imp.textureCompression = state.textureCompression;
            imp.SaveAndReimport();
        }
    }
}
