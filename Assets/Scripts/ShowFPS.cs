using UnityEngine;

namespace Lwy.Scripts.UI
{
    /// <summary>
    /// Displays a simple Frame Per Second (FPS) counter on the screen using OnGUI.
    /// </summary>
    public class ShowFPS : MonoBehaviour
    {
        [Tooltip("How often to update the FPS text (in seconds).")]
        public float updateInterval = 0.5f;

        private float lastIntervalTime;
        private int framesCount = 0;
        private float currentFps;

        private void Start()
        {
            // Don't limit frame rate to let it go as high as possible for testing
            Application.targetFrameRate = -1; 
            
            lastIntervalTime = Time.realtimeSinceStartup;
            framesCount = 0;
        }

        private void Update()
        {
            framesCount++;
            float timeNow = Time.realtimeSinceStartup;

            if (timeNow > lastIntervalTime + updateInterval)
            {
                currentFps = framesCount / (timeNow - lastIntervalTime);
                framesCount = 0;
                lastIntervalTime = timeNow;
            }
        }

        private void OnGUI()
        {
            // Draw a simple label
            // GUI.Label is legacy but fine for simple debug tools
            GUIStyle style = new GUIStyle();
            style.fontSize = 24;
            style.normal.textColor = Color.green;

            GUI.Label(new Rect(20, 20, 200, 50), $"FPS: {currentFps:F2}", style);
        }
    }
}
