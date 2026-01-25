using UnityEngine;
using UnityEditor;

namespace TAToolbox
{
    // =========================================================
    // 3. 快捷压缩预设
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
}