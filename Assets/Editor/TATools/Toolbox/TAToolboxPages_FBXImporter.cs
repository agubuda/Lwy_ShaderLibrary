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
}