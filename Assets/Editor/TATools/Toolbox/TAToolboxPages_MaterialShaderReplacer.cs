using UnityEngine;
using UnityEditor;
using System.Collections.Generic;

namespace TAToolbox
{
    // =========================================================
    // 9. 材质 Shader 替换
    // =========================================================
    public class Page_MaterialShaderReplacer : TAToolPage
    {
        public override string PageName => "9. Shader 替换";
        
        private Shader fromShader;
        private Shader toShader;
        private bool autoLit = true;
        private List<Material> foundMats = new List<Material>();
        private List<Material> selMats = new List<Material>();
        private Vector2 scroll;

        public override void OnGUI(string rootPath)
        {
            DrawHeader("批量材质 Shader 替换");

            autoLit = EditorGUILayout.Toggle("自动选 Lit/Standard", autoLit);
            if (autoLit)
            {
                fromShader = Shader.Find("Universal Render Pipeline/Lit") ?? Shader.Find("Standard");
                EditorGUI.BeginDisabledGroup(true);
                EditorGUILayout.ObjectField("查找 (Auto)", fromShader, typeof(Shader), false);
                EditorGUI.EndDisabledGroup();
            }
            else
            {
                fromShader = (Shader)EditorGUILayout.ObjectField("查找 Shader", fromShader, typeof(Shader), false);
            }
            
            toShader = (Shader)EditorGUILayout.ObjectField("替换为 Shader", toShader, typeof(Shader), false);

            GUILayout.Space(10);
            if (GUILayout.Button("搜索当前文件夹")) Search(rootPath);

            if (foundMats.Count > 0)
            {
                GUILayout.Label($"找到 {foundMats.Count} 个材质:");
                GUILayout.BeginHorizontal();
                if (GUILayout.Button("全选")) { selMats.Clear(); selMats.AddRange(foundMats); }
                if (GUILayout.Button("清空")) { selMats.Clear(); }
                GUILayout.EndHorizontal();

                scroll = EditorGUILayout.BeginScrollView(scroll, EditorStyles.helpBox, GUILayout.Height(200));
                foreach (var m in foundMats)
                {
                    if (m == null) continue;
                    EditorGUILayout.BeginHorizontal();
                    bool sel = selMats.Contains(m);
                    bool nSel = EditorGUILayout.Toggle(sel, GUILayout.Width(20));
                    if (sel != nSel) { if (nSel) selMats.Add(m); else selMats.Remove(m); }
                    EditorGUILayout.ObjectField(m, typeof(Material), false);
                    EditorGUILayout.EndHorizontal();
                }
                EditorGUILayout.EndScrollView();

                GUILayout.Space(5);
                if (GUILayout.Button($"替换选中 ({selMats.Count})", GUILayout.Height(30))) Replace();
            }
        }

        private void Search(string rootPath)
        {
            foundMats.Clear(); selMats.Clear();
            if (!fromShader) return;
            string[] guids = AssetDatabase.FindAssets("t:Material", new[] { rootPath });
            foreach (var g in guids)
            {
                string p = AssetDatabase.GUIDToAssetPath(g);
                // 只处理独立材质球，不处理FBX内置
                if (!p.EndsWith(".mat")) continue;
                Material m = AssetDatabase.LoadAssetAtPath<Material>(p);
                if (m.shader == fromShader) foundMats.Add(m);
            }
        }

        private void Replace()
        {
            if (!toShader || selMats.Count == 0) return;
            foreach (var m in selMats)
            {
                Undo.RecordObject(m, "Shader Replace");
                m.shader = toShader;
                EditorUtility.SetDirty(m);
            }
            AssetDatabase.SaveAssets();
            Debug.Log($"替换了 {selMats.Count} 个材质的 Shader。");
            foundMats.Clear(); selMats.Clear();
        }
    }
}