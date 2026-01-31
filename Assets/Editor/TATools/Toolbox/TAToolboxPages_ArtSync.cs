using UnityEngine;
using UnityEditor;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using System;

namespace TAToolbox
{
    // =========================================================
    // Data Profile for Art Sync
    // =========================================================
    public class ArtSyncProfile : ScriptableObject
    {
        [System.Serializable]
        public class SyncPair
        {
            public string name = "New Sync";
            public bool active = true;
            public UnityEngine.Object targetUnityFolder; // Expecting DefaultAsset (Folder)
            public string sourceExternalPath = "";
            public string fileExtensions = ".png;.jpg;.tga";
            public bool includeSubFolders = false;
            public bool deleteOrphanFiles = false;
        }

        public List<SyncPair> syncPairs = new List<SyncPair>();
    }

    // =========================================================
    // 21. 外部美术资源同步工具 (Art Sync) - 修复版
    // =========================================================
    public class Page_ArtSync : TAToolPage
    {
        public override string PageName => "21. 外部资源同步 (Art Sync)";

        private ArtSyncProfile activeProfile;
        private Vector2 scrollPos;

        public override void OnGUI(string rootPath)
        {
            DrawHeader("外部美术资源同步工具");

            EditorGUILayout.HelpBox(
                "功能说明：\n" +
                "将外部工作目录(Work Folder)的文件一键同步到 Unity 工程内。\n" +
                "1. 请先创建一个 [Art Sync Profile] 配置文件并拖入下方。\n" +
                "2. 配置源文件夹路径和目标文件夹。\n" +
                "3. 点击同步即可自动拷贝并刷新。", 
                MessageType.Info);

            GUILayout.Space(10);

            // 1. 配置文件选择槽
            EditorGUILayout.BeginHorizontal();
            GUILayout.Label("配置文件 (Profile):", GUILayout.Width(120));
            activeProfile = (ArtSyncProfile)EditorGUILayout.ObjectField(activeProfile, typeof(ArtSyncProfile), false);
            
            if (GUILayout.Button("新建配置", GUILayout.Width(80)))
            {
                CreateNewProfile(rootPath);
            }
            EditorGUILayout.EndHorizontal();

            if (activeProfile == null)
            {
                GUILayout.Space(20);
                EditorGUILayout.LabelField("请选择或新建一个配置文件以开始。", EditorStyles.centeredGreyMiniLabel);
                return;
            }

            // --- 修复点：手动绘制分割线，代替不存在的 DrawSeparator() ---
            GUILayout.Space(10);
            EditorGUILayout.LabelField("", GUI.skin.horizontalSlider);
            GUILayout.Space(10);
            // -------------------------------------------------------

            // 2. 绘制同步列表
            scrollPos = EditorGUILayout.BeginScrollView(scrollPos);
            SerializedObject so = new SerializedObject(activeProfile);
            SerializedProperty pairsProp = so.FindProperty("syncPairs");

            for (int i = 0; i < pairsProp.arraySize; i++)
            {
                SerializedProperty item = pairsProp.GetArrayElementAtIndex(i);
                DrawSyncPair(item, i);
                GUILayout.Space(5);
            }

            GUILayout.Space(10);
            
            // 添加按钮
            if (GUILayout.Button("+ 添加新的同步关联", GUILayout.Height(30)))
            {
                activeProfile.syncPairs.Add(new ArtSyncProfile.SyncPair());
                EditorUtility.SetDirty(activeProfile);
            }

            EditorGUILayout.EndScrollView();

            so.ApplyModifiedProperties();

            // 3. 底部执行按钮
            GUILayout.Space(10);
            GUI.backgroundColor = new Color(0.6f, 1f, 0.6f);
            if (GUILayout.Button("🔄 执行所有同步 (Sync All)", GUILayout.Height(40)))
            {
                SyncAll();
            }
            GUI.backgroundColor = Color.white;
        }

        private void DrawSyncPair(SerializedProperty item, int index)
        {
            SerializedProperty name = item.FindPropertyRelative("name");
            SerializedProperty active = item.FindPropertyRelative("active");
            SerializedProperty targetFolder = item.FindPropertyRelative("targetUnityFolder");
            SerializedProperty sourcePath = item.FindPropertyRelative("sourceExternalPath");
            SerializedProperty extensions = item.FindPropertyRelative("fileExtensions");
            SerializedProperty deleteOrphans = item.FindPropertyRelative("deleteOrphanFiles");
            SerializedProperty subFolders = item.FindPropertyRelative("includeSubFolders");

            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            
            // 标题栏
            EditorGUILayout.BeginHorizontal();
            active.boolValue = EditorGUILayout.Toggle(active.boolValue, GUILayout.Width(20));
            name.stringValue = EditorGUILayout.TextField(name.stringValue, EditorStyles.boldLabel);
            if (GUILayout.Button("执行此项", GUILayout.Width(70)))
            {
                SyncSingle(index);
            }
            if (GUILayout.Button("X", GUILayout.Width(25)))
            {
                activeProfile.syncPairs.RemoveAt(index);
                return; 
            }
            EditorGUILayout.EndHorizontal();

            if (!active.boolValue)
            {
                EditorGUILayout.EndVertical();
                return; // 折叠
            }

            EditorGUI.indentLevel++;

            // 路径配置
            EditorGUILayout.BeginHorizontal();
            EditorGUILayout.LabelField("外部源目录:", GUILayout.Width(80));
            sourcePath.stringValue = EditorGUILayout.TextField(sourcePath.stringValue);
            if (GUILayout.Button("浏览", GUILayout.Width(50)))
            {
                string path = EditorUtility.OpenFolderPanel("选择外部源文件夹", sourcePath.stringValue, "");
                if (!string.IsNullOrEmpty(path)) sourcePath.stringValue = path;
            }
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();
            EditorGUILayout.LabelField("Unity目录:", GUILayout.Width(80));
            targetFolder.objectReferenceValue = EditorGUILayout.ObjectField(targetFolder.objectReferenceValue, typeof(UnityEngine.Object), false);
            EditorGUILayout.EndHorizontal();

            // 详细设置
            EditorGUILayout.PropertyField(extensions, new GUIContent("包含后缀 (分号隔开)"));
            EditorGUILayout.BeginHorizontal();
            EditorGUILayout.PropertyField(subFolders, new GUIContent("包含子文件夹"));
            EditorGUILayout.PropertyField(deleteOrphans, new GUIContent("镜像同步 (删除多余文件)"));
            EditorGUILayout.EndHorizontal();

            EditorGUI.indentLevel--;
            EditorGUILayout.EndVertical();
        }

        // ================= 逻辑核心 =================

        private void SyncAll()
        {
            for (int i = 0; i < activeProfile.syncPairs.Count; i++)
            {
                if (activeProfile.syncPairs[i].active) SyncSingle(i);
            }
            AssetDatabase.Refresh();
            EditorUtility.DisplayDialog("完成", "所有资源同步完成！", "OK");
        }

        private void SyncSingle(int index)
        {
            var pair = activeProfile.syncPairs[index];
            if (pair.targetUnityFolder == null)
            {
                Debug.LogError($"[{pair.name}] Unity 目标文件夹未设置！");
                return;
            }
            if (string.IsNullOrEmpty(pair.sourceExternalPath) || !Directory.Exists(pair.sourceExternalPath))
            {
                Debug.LogError($"[{pair.name}] 外部路径不存在: {pair.sourceExternalPath}");
                return;
            }

            string targetPath = AssetDatabase.GetAssetPath(pair.targetUnityFolder);
            // 将 Unity 相对路径转换为系统绝对路径
            string targetFullPath = Path.GetFullPath(Path.Combine(Application.dataPath, "..", targetPath));

            string[] exts = pair.fileExtensions.ToLower().Split(';');
            SearchOption searchOpt = pair.includeSubFolders ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly;

            try
            {
                // 1. 获取源文件列表
                var sourceFiles = Directory.GetFiles(pair.sourceExternalPath, "*.*", searchOpt)
                    .Where(f => exts.Any(e => f.ToLower().EndsWith(e)))
                    .ToList();

                int count = 0;
                EditorUtility.DisplayProgressBar($"同步中: {pair.name}", "正在拷贝文件...", 0);

                foreach (var srcFile in sourceFiles)
                {
                    // 计算相对路径，以便在目标端重建结构
                    // 注意：Path.GetRelativePath 需要 .NET Standard 2.1 或 .NET Core
                    // Unity 2021+ 通常支持。如果报错，我会提供一个兼容写法。
                    string relPath = GetRelativePath(pair.sourceExternalPath, srcFile);
                    string destFile = Path.Combine(targetFullPath, relPath);

                    // 确保目标子文件夹存在
                    string destDir = Path.GetDirectoryName(destFile);
                    if (!Directory.Exists(destDir)) Directory.CreateDirectory(destDir);

                    // 检查是否需要更新 (时间戳比较)
                    bool needCopy = true;
                    if (File.Exists(destFile))
                    {
                        DateTime srcTime = File.GetLastWriteTime(srcFile);
                        DateTime destTime = File.GetLastWriteTime(destFile);
                        // 如果源文件时间 <= 目标文件时间，说明没更新
                        if (srcTime <= destTime) needCopy = false;
                    }

                    if (needCopy)
                    {
                        File.Copy(srcFile, destFile, true);
                        count++;
                    }
                }

                // 2. 处理删除 (镜像同步)
                if (pair.deleteOrphanFiles)
                {
                    var destFiles = Directory.GetFiles(targetFullPath, "*.*", searchOpt)
                        .Where(f => !f.EndsWith(".meta")) 
                        .ToList();

                    foreach (var destF in destFiles)
                    {
                        string relPath = GetRelativePath(targetFullPath, destF);
                        string srcF = Path.Combine(pair.sourceExternalPath, relPath);

                        bool extMatch = exts.Any(e => destF.ToLower().EndsWith(e));
                        if (extMatch && !File.Exists(srcF))
                        {
                            File.Delete(destF);
                            if (File.Exists(destF + ".meta")) File.Delete(destF + ".meta");
                            Debug.Log($"[已删除] 外部源已删除，同步删除: {relPath}");
                        }
                    }
                }

                Debug.Log($"<b>[{pair.name}]</b> 同步完成。更新了 {count} 个文件。");
            }
            catch (System.Exception e)
            {
                Debug.LogError($"同步出错: {e.Message}");
            }
            finally
            {
                EditorUtility.ClearProgressBar();
            }
        }

        // 手动实现 GetRelativePath 以防 Unity 版本过低不支持 System.IO.Path.GetRelativePath
        private string GetRelativePath(string fromPath, string toPath)
        {
            if (string.IsNullOrEmpty(fromPath)) return toPath;
            if (string.IsNullOrEmpty(toPath)) return "";

            System.Uri fromUri = new System.Uri(fromPath.EndsWith("/") || fromPath.EndsWith("\\") ? fromPath : fromPath + "\\");
            System.Uri toUri = new System.Uri(toPath);

            if (fromUri.Scheme != toUri.Scheme) { return toPath; }

            System.Uri relativeUri = fromUri.MakeRelativeUri(toUri);
            string relativePath = System.Uri.UnescapeDataString(relativeUri.ToString());

            return relativePath.Replace('/', Path.DirectorySeparatorChar);
        }

        private void CreateNewProfile(string rootPath)
        {
            // 强制指定保存路径到脚本所在目录下的 ArtSyncProfiles 子文件夹
            string folderPath = "Assets/Editor/TATools/Toolbox/ArtSyncProfiles";
            
            if (!Directory.Exists(folderPath))
            {
                Directory.CreateDirectory(folderPath);
                AssetDatabase.Refresh();
            }

            ArtSyncProfile newProfile = ScriptableObject.CreateInstance<ArtSyncProfile>();
            string path = Path.Combine(folderPath, "NewArtSyncProfile.asset");
            path = AssetDatabase.GenerateUniqueAssetPath(path);
            
            AssetDatabase.CreateAsset(newProfile, path);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            
            activeProfile = newProfile;
            EditorGUIUtility.PingObject(newProfile);
        }
    }
}