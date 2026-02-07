using UnityEngine;
using UnityEditor;
using System.IO;
using System.Collections.Generic;

namespace TAToolbox
{
    // =========================================================
    // 11. 贴图通道重组工具 (Texture Swizzler)
    // =========================================================
    public class Page_TextureSwizzler : TAToolPage
    {
        public override string PageName => "11. 贴图通道重组";

        public enum SourceChannel
        {
            From_R = 0,
            From_G = 1,
            From_B = 2,
            From_A = 3,
            White_1 = 4,
            Black_0 = 5
        }

        private SourceChannel _rSource = SourceChannel.From_R;
        private SourceChannel _gSource = SourceChannel.From_G;
        private SourceChannel _bSource = SourceChannel.From_B;
        private SourceChannel _aSource = SourceChannel.From_A;

        private bool _invertR = false;
        private bool _invertG = false;
        private bool _invertB = false;
        private bool _invertA = false;

        private string _suffix = "_New";

        public override void OnGUI(string rootPath)
        {
            DrawHeader("贴图通道重组 (Swizzler)");

            EditorGUILayout.HelpBox("选中一张或多张图片，设置 RGBA 的来源通道，生成新图片。", MessageType.Info);

            GUILayout.Space(10);
            GUILayout.Label("新文件后缀:");
            _suffix = EditorGUILayout.TextField(_suffix);

            GUILayout.Space(10);
            GUILayout.Label("通道映射设置:", EditorStyles.boldLabel);
            
            EditorGUI.indentLevel++;

            EditorGUILayout.BeginHorizontal();
            _rSource = (SourceChannel)EditorGUILayout.EnumPopup("Output Red <=", _rSource);
            _invertR = EditorGUILayout.ToggleLeft("Invert", _invertR, GUILayout.Width(60));
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();
            _gSource = (SourceChannel)EditorGUILayout.EnumPopup("Output Green <=", _gSource);
            _invertG = EditorGUILayout.ToggleLeft("Invert", _invertG, GUILayout.Width(60));
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();
            _bSource = (SourceChannel)EditorGUILayout.EnumPopup("Output Blue <=", _bSource);
            _invertB = EditorGUILayout.ToggleLeft("Invert", _invertB, GUILayout.Width(60));
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();
            _aSource = (SourceChannel)EditorGUILayout.EnumPopup("Output Alpha <=", _aSource);
            _invertA = EditorGUILayout.ToggleLeft("Invert", _invertA, GUILayout.Width(60));
            EditorGUILayout.EndHorizontal();

            EditorGUI.indentLevel--;

            GUILayout.Space(15);

            // 获取当前选中的贴图
            var selectedTextures = new List<Texture2D>();
            foreach (var obj in Selection.objects)
            {
                if (obj is Texture2D tex)
                {
                    selectedTextures.Add(tex);
                }
            }

            if (selectedTextures.Count == 0)
            {
                EditorGUILayout.HelpBox("请在 Project 窗口选中至少一张贴图。", MessageType.Warning);
                GUI.enabled = false;
            }
            else
            {
                EditorGUILayout.HelpBox($"已选中 {selectedTextures.Count} 张贴图准备处理。", MessageType.None);
            }

            if (GUILayout.Button("生成新图片", GUILayout.Height(40)))
            {
                ProcessTextures(selectedTextures);
            }
            GUI.enabled = true;
        }

        private void ProcessTextures(List<Texture2D> textures)
        {
            int count = 0;
            float total = textures.Count;

            foreach (var tex in textures)
            {
                string path = AssetDatabase.GetAssetPath(tex);
                EditorUtility.DisplayProgressBar("Processing Textures", $"Processing {Path.GetFileName(path)}...", (float)count / total);

                ProcessSingleTexture(tex, path);
                count++;
            }

            EditorUtility.ClearProgressBar();
            AssetDatabase.Refresh();
            Debug.Log($"通道重组完成！共生成 {count} 张新贴图。");
        }

        private void ProcessSingleTexture(Texture2D tex, string path)
        {
            // 确保可读
            TextureImporter imp = AssetImporter.GetAtPath(path) as TextureImporter;
            bool wasReadable = imp.isReadable;
            TextureImporterCompression wasCompression = imp.textureCompression;

            if (!wasReadable)
            {
                imp.isReadable = true;
                // 为了读取准确的原始像素，最好暂时关闭压缩
                imp.textureCompression = TextureImporterCompression.Uncompressed;
                imp.SaveAndReimport();
            }

            try
            {
                // 读取像素
                // 注意：如果原图有 Mipmap，我们只读 level 0
                // 注意：TextureImporter 设置改变后，tex 对象可能需要重新加载，但通常引用还是有效的，或者 GetPixels 会重新从硬盘读
                // 为了保险，重新 Load 一次
                // Texture2D readableTex = AssetDatabase.LoadAssetAtPath<Texture2D>(path); 
                // 上面这一步其实如果 imp.SaveAndReimport 之后，原来 tex 的 C++ 指针可能变了？通常 Editor 下会自动刷新引用。
                // 暂时直接用 tex.GetPixels()，如果报错则需要重新 Load。

                Color[] srcPixels = tex.GetPixels();
                Color[] dstPixels = new Color[srcPixels.Length];

                for (int i = 0; i < srcPixels.Length; i++)
                {
                    Color s = srcPixels[i];
                    Color d = new Color();

                    d.r = GetChannelValue(s, _rSource, _invertR);
                    d.g = GetChannelValue(s, _gSource, _invertG);
                    d.b = GetChannelValue(s, _bSource, _invertB);
                    d.a = GetChannelValue(s, _aSource, _invertA);

                    dstPixels[i] = d;
                }

                // 创建新 Texture 并保存
                // 使用 ARGB32 或 RGBA32，取决于系统字节序，但 SetPixels 会处理
                // 默认生成 sRGB 还是 Linear？取决于原图。这里我们构造新的 Texture2D，默认是 sRGB=false (Linear) ? 
                // 构造函数: Texture2D(int width, int height, TextureFormat textureFormat, bool mipChain, bool linear)
                // 如果原图是 sRGB，我们生成的新图保存为 PNG 后，Unity 导入时应该也设为 sRGB。
                // 写入文件时其实只关心像素值。
                Texture2D newTex = new Texture2D(tex.width, tex.height, TextureFormat.RGBA32, false);
                newTex.SetPixels(dstPixels);
                newTex.Apply();

                byte[] bytes = newTex.EncodeToPNG();
                Object.DestroyImmediate(newTex);

                string dir = Path.GetDirectoryName(path);
                string name = Path.GetFileNameWithoutExtension(path);
                string newPath = Path.Combine(dir, name + _suffix + ".png");

                // 写入文件系统
                File.WriteAllBytes(newPath, bytes);
            }
            finally
            {
                // 恢复设置
                if (!wasReadable)
                {
                    imp.isReadable = false;
                    imp.textureCompression = wasCompression;
                    imp.SaveAndReimport();
                }
            }
        }

        private float GetChannelValue(Color c, SourceChannel source, bool invert)
        {
            float val = 0.0f;
            switch (source)
            {
                case SourceChannel.From_R: val = c.r; break;
                case SourceChannel.From_G: val = c.g; break;
                case SourceChannel.From_B: val = c.b; break;
                case SourceChannel.From_A: val = c.a; break;
                case SourceChannel.White_1: val = 1.0f; break;
                case SourceChannel.Black_0: val = 0.0f; break;
                default: val = 0.0f; break;
            }
            return invert ? 1.0f - val : val;
        }
    }
}
