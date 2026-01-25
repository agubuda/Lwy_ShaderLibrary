using UnityEngine;
using UnityEditor;
using System.Collections.Generic;

namespace TAToolbox
{
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
}