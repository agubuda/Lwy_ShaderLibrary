using UnityEngine;
using UnityEditor;
using System.IO;
using System.Collections.Generic;

namespace TAToolbox
{
    // =========================================================
    // 1. 批量重命名工具
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

            using (new AssetEditingScope())
            {
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
            }
            AssetDatabase.Refresh();
        }
    }
}
