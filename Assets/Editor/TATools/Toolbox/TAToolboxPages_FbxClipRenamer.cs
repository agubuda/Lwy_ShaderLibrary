using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;

namespace TAToolbox
{
    // =========================================================
    // 7. FBX 动画重命名 (Clip -> File Name)
    // =========================================================
    public class Page_FbxClipRenamer : TAToolPage
    {
        public override string PageName => "7. FBX 动画重命名";

        public override void OnGUI(string rootPath)
        {
            DrawHeader("重命名 FBX 内部 Clip 为文件名");
            EditorGUILayout.HelpBox("将 FBX 内的第一个 Animation Clip 的名字修改为与 FBX 文件名一致。", MessageType.Info);
            
            GUILayout.Space(10);
            if (GUILayout.Button("执行重命名", GUILayout.Height(40))) RenameClips(rootPath);
        }

        private void RenameClips(string rootPath)
        {
            string[] guids = AssetDatabase.FindAssets("t:Model", new[] { rootPath });
            int count = 0;
            foreach (var g in guids)
            {
                string path = AssetDatabase.GUIDToAssetPath(g);
                if (!path.ToLower().EndsWith(".fbx")) continue;
                
                ModelImporter imp = AssetImporter.GetAtPath(path) as ModelImporter;
                if (!imp || !imp.importAnimation) continue;

                string fileName = Path.GetFileNameWithoutExtension(path);
                bool changed = false;

                // 修改 Clip 列表
                var clips = imp.clipAnimations;
                if (clips != null && clips.Length > 0)
                {
                    if (clips[0].name != fileName) { clips[0].name = fileName; imp.clipAnimations = clips; changed = true; }
                }
                else
                {
                    // 默认 Clip
                    var defs = imp.defaultClipAnimations;
                    if (defs != null && defs.Length > 0)
                    {
                        var newClips = new List<ModelImporterClipAnimation>();
                        var c = defs[0];
                        c.name = fileName;
                        newClips.Add(c);
                        imp.clipAnimations = newClips.ToArray();
                        changed = true;
                    }
                }

                if (changed) { imp.SaveAndReimport(); count++; }
            }
            Debug.Log($"重命名了 {count} 个动画 Clip。");
        }
    }
}