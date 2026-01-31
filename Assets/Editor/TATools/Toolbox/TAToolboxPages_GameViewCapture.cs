using UnityEngine;
using UnityEditor;
using System.IO;
using System.Reflection;

namespace TAToolbox
{
    // =========================================================
    // 19. Game视窗截图工具 (修复版：确保按钮显示)
    // =========================================================
    public class Page_GameViewCapture : TAToolPage
    {
        public override string PageName => "19. Game视窗截图";

        private bool openAfterCapture = true;
        private bool transparentBackground = false; 
        private string lastPath = "";

        public override void OnGUI(string rootPath)
        {
            DrawHeader("Game View 截图工具");

            // --- 1. 先画最重要的按钮 (防止下面代码报错导致按钮不显示) ---
            GUILayout.Space(10);
            GUI.backgroundColor = new Color(0.6f, 0.8f, 1f);
            
            // 大按钮
            if (GUILayout.Button("📸 立即截图 (Capture)", GUILayout.Height(50)))
            {
                CaptureGameView();
            }
            GUI.backgroundColor = Color.white;

            // --- 2. 状态显示 (加了 Try-Catch 防止报错中断 UI) ---
            GUILayout.Space(5);
            try 
            {
                Vector2 res = GetGameViewSize();
                string resInfo = res.x > 0 ? $"当前分辨率: {(int)res.x} x {(int)res.y}" : "未检测到活跃 Game 窗口 (将使用默认 1920x1080)";
                EditorGUILayout.LabelField(resInfo, EditorStyles.centeredGreyMiniLabel);
            }
            catch
            {
                EditorGUILayout.LabelField("分辨率检测失败 (不影响截图功能)", EditorStyles.centeredGreyMiniLabel);
            }

            GUILayout.Space(15);

            // --- 3. 选项设置 ---
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            openAfterCapture = EditorGUILayout.Toggle("截图后打开文件夹", openAfterCapture);
            transparentBackground = EditorGUILayout.Toggle("保留透明背景", transparentBackground);
            
            if (transparentBackground)
                EditorGUILayout.HelpBox("透明背景要求：MainCamera 的 Clear Flags = Solid Color 且 Alpha = 0", MessageType.None);
            
            EditorGUILayout.EndVertical();

            // --- 4. 打开上一张 ---
            if (!string.IsNullOrEmpty(lastPath))
            {
                GUILayout.Space(10);
                if (GUILayout.Button($"打开上一张: {Path.GetFileName(lastPath)}"))
                {
                    EditorUtility.RevealInFinder(lastPath);
                }
            }
        }

        private void CaptureGameView()
        {
            Camera cam = Camera.main;
            if (cam == null)
            {
                EditorUtility.DisplayDialog("错误", "场景中找不到 MainCamera (Tag需为MainCamera)。", "OK");
                return;
            }

            // 获取分辨率 (带默认值)
            Vector2 size = new Vector2(1920, 1080);
            try {
                Vector2 s = GetGameViewSize();
                if (s.x > 0 && s.y > 0) size = s;
            } catch {}

            int width = (int)size.x;
            int height = (int)size.y;

            // 创建 RT
            RenderTexture rt = new RenderTexture(width, height, 24, RenderTextureFormat.ARGB32);
            rt.antiAliasing = Mathf.Max(1, QualitySettings.antiAliasing);

            // 记录旧状态
            RenderTexture oldTarget = cam.targetTexture;
            RenderTexture oldActive = RenderTexture.active;

            // 渲染
            cam.targetTexture = rt;
            cam.Render();

            // 读图
            RenderTexture.active = rt;
            Texture2D tex = new Texture2D(width, height, TextureFormat.RGBA32, false);
            tex.ReadPixels(new Rect(0, 0, width, height), 0, 0);
            tex.Apply();

            // 还原
            cam.targetTexture = oldTarget;
            RenderTexture.active = oldActive;
            rt.Release();
            Object.DestroyImmediate(rt);

            // 保存
            byte[] bytes = tex.EncodeToPNG();
            Object.DestroyImmediate(tex);

            string folder = Path.Combine(Directory.GetParent(Application.dataPath).FullName, "Captures");
            if (!Directory.Exists(folder)) Directory.CreateDirectory(folder);

            string fileName = $"Capture_{System.DateTime.Now:MMdd_HHmmss}.png";
            string fullPath = Path.Combine(folder, fileName);

            File.WriteAllBytes(fullPath, bytes);
            lastPath = fullPath;

            Debug.Log($"截图已保存: {fullPath}");
            if (openAfterCapture) EditorUtility.RevealInFinder(fullPath);
        }

        // 获取 GameView 分辨率 (反射)
        private Vector2 GetGameViewSize()
        {
            try {
                System.Type T = System.Type.GetType("UnityEditor.GameView,UnityEditor");
                System.Reflection.MethodInfo GetMainGameView = T.GetMethod("GetMainGameView", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
                System.Object Res = GetMainGameView.Invoke(null, null);
                if (Res != null)
                {
                    var prop = T.GetProperty("targetSize", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
                    return (Vector2)prop.GetValue(Res, null);
                }
            } catch {}
            return Vector2.zero;
        }
    }
}