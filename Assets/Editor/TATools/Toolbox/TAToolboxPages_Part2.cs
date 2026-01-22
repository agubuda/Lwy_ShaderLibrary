using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;

namespace TAToolbox
{
    // =========================================================
    // 6. FBX 批量导入设置
    // =========================================================
    public class Page_FBXImporter : TAToolPage
    {
        public override string PageName => "6. FBX 导入设置";
        
        private bool impConstraints = false;
        private bool impAnim = true;
        private bool bakeAnim = false;
        private bool resample = true;
        private ModelImporterAnimationCompression comp = ModelImporterAnimationCompression.KeyframeReduction;
        private float rotErr = 0.1f, posErr = 0f, sclErr = 0.5f;

        public override void OnGUI(string rootPath)
        {
            DrawHeader("FBX Animation Batch Settings");
            
            impConstraints = EditorGUILayout.Toggle("Import Constraints", impConstraints);
            impAnim = EditorGUILayout.Toggle("Import Animation", impAnim);
            bakeAnim = EditorGUILayout.Toggle("Bake Animations", bakeAnim);
            resample = EditorGUILayout.Toggle("Resample Curves", resample);
            comp = (ModelImporterAnimationCompression)EditorGUILayout.EnumPopup("Compression", comp);
            
            if (comp != ModelImporterAnimationCompression.Off)
            {
                EditorGUI.indentLevel++;
                rotErr = EditorGUILayout.FloatField("Rot Error", rotErr);
                posErr = EditorGUILayout.FloatField("Pos Error", posErr);
                sclErr = EditorGUILayout.FloatField("Scl Error", sclErr);
                EditorGUI.indentLevel--;
            }

            GUILayout.Space(15);
            if (GUILayout.Button("应用到当前文件夹", GUILayout.Height(40))) Apply(rootPath);
        }

        private void Apply(string rootPath)
        {
            string[] guids = AssetDatabase.FindAssets("t:Model", new[] { rootPath });
            int count = 0;
            AssetDatabase.StartAssetEditing();
            foreach (var g in guids)
            {
                string p = AssetDatabase.GUIDToAssetPath(g);
                if (!p.ToLower().EndsWith(".fbx")) continue;
                
                ModelImporter imp = AssetImporter.GetAtPath(p) as ModelImporter;
                if (imp)
                {
                    SerializedObject so = new SerializedObject(imp);
                    bool dirty = false;
                    
                    if (imp.importConstraints != impConstraints) { imp.importConstraints = impConstraints; dirty = true; }
                    if (imp.importAnimation != impAnim) { imp.importAnimation = impAnim; dirty = true; }
                    if (imp.resampleCurves != resample) { imp.resampleCurves = resample; dirty = true; }
                    if (imp.animationCompression != comp) { imp.animationCompression = comp; dirty = true; }
                    
                    // Bake Simulation (SerializedProp)
                    var bakeProp = so.FindProperty("m_BakeSimulation");
                    if (bakeProp != null && bakeProp.boolValue != bakeAnim) { bakeProp.boolValue = bakeAnim; dirty = true; }

                    if (dirty)
                    {
                        imp.animationRotationError = rotErr;
                        imp.animationPositionError = posErr;
                        imp.animationScaleError = sclErr;
                        so.ApplyModifiedProperties();
                        imp.SaveAndReimport();
                        count++;
                    }
                }
            }
            AssetDatabase.StopAssetEditing();
            Debug.Log($"更新了 {count} 个 FBX 文件。");
        }
    }

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

    // =========================================================
    // 8. 材质属性批量修改
    // =========================================================
    public class Page_MaterialPropertyBatcher : TAToolPage
    {
        public override string PageName => "8. 材质属性修改";
        
        public enum PType { Float, Color }
        private Shader targetShader;
        private PType pType = PType.Float;
        private int propIndex = 0;
        private float fVal = 0;
        private Color cVal = Color.white;
        private string[] displayNames;
        private string[] internalNames;

        public override void OnGUI(string rootPath)
        {
            DrawHeader("批量材质属性修改");

            EditorGUI.BeginChangeCheck();
            targetShader = (Shader)EditorGUILayout.ObjectField("目标 Shader", targetShader, typeof(Shader), false);
            pType = (PType)EditorGUILayout.EnumPopup("属性类型", pType);
            if (EditorGUI.EndChangeCheck()) FetchProps();

            if (targetShader && internalNames != null && internalNames.Length > 0)
            {
                propIndex = EditorGUILayout.Popup("选择属性", propIndex, displayNames);
                if (propIndex >= internalNames.Length) propIndex = 0;
                
                if (pType == PType.Float) fVal = EditorGUILayout.FloatField("新值 (Float)", fVal);
                else cVal = EditorGUILayout.ColorField("新颜色", cVal);

                GUILayout.Space(15);
                if (GUILayout.Button("应用到当前文件夹", GUILayout.Height(40))) Apply(rootPath);
            }
            else if (targetShader)
            {
                EditorGUILayout.HelpBox("该 Shader 无此类型属性", MessageType.Warning);
            }
        }

        private void FetchProps()
        {
            if (!targetShader) return;
            var d = new List<string>();
            var n = new List<string>();
            int count = ShaderUtil.GetPropertyCount(targetShader);
            for(int i=0; i<count; i++)
            {
                var t = ShaderUtil.GetPropertyType(targetShader, i);
                if ((pType == PType.Float && (t == ShaderUtil.ShaderPropertyType.Float || t == ShaderUtil.ShaderPropertyType.Range)) ||
                    (pType == PType.Color && t == ShaderUtil.ShaderPropertyType.Color))
                {
                    n.Add(ShaderUtil.GetPropertyName(targetShader, i));
                    d.Add(ShaderUtil.GetPropertyDescription(targetShader, i));
                }
            }
            displayNames = d.ToArray(); internalNames = n.ToArray(); propIndex = 0;
        }

        private void Apply(string rootPath)
        {
            string prop = internalNames[propIndex];
            string[] guids = AssetDatabase.FindAssets("t:Material", new[] { rootPath });
            int count = 0;
            foreach (var g in guids)
            {
                Material m = AssetDatabase.LoadAssetAtPath<Material>(AssetDatabase.GUIDToAssetPath(g));
                if (m.shader == targetShader)
                {
                    Undo.RecordObject(m, "Batch Mat Prop");
                    if (pType == PType.Float) m.SetFloat(prop, fVal);
                    else m.SetColor(prop, cVal);
                    EditorUtility.SetDirty(m);
                    count++;
                }
            }
            AssetDatabase.SaveAssets();
            Debug.Log($"修改了 {count} 个材质。");
        }
    }

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
