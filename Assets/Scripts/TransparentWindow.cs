using System;
using System.Runtime.InteropServices;
using UnityEngine;

namespace Lwy.Scripts.Windows
{
    /// <summary>
    /// Enables window transparency on Windows builds.
    /// Uses Windows API calls (DwmExtendFrameIntoClientArea).
    /// </summary>
    public class TransparentWindow : MonoBehaviour
    {
#if UNITY_STANDALONE_WIN

        private struct MARGINS
        {
            public int cxLeftWidth;
            public int cxRightWidth;
            public int cyTopHeight;
            public int cyBottomHeight;
        }

        [DllImport("user32.dll")]
        private static extern IntPtr GetActiveWindow();

        [DllImport("user32.dll")]
        private static extern int SetWindowLong(IntPtr hWnd, int nIndex, uint dwNewLong);

        [DllImport("Dwmapi.dll")]
        private static extern uint DwmExtendFrameIntoClientArea(IntPtr hWnd, ref MARGINS margins);

        // Window Styles
        private const int GWL_STYLE = -16;
        private const uint WS_POPUP = 0x80000000;
        private const uint WS_VISIBLE = 0x10000000;
        
        // Extended Styles if needed
        // private const int GWL_EXSTYLE = -20;
        // private const uint WS_EX_LAYERED = 0x80000;
        // private const uint WS_EX_TRANSPARENT = 0x20;

        private void Start()
        {
            // Only execute in build to prevent Editor window artifacts
            #if !UNITY_EDITOR 
            MakeWindowTransparent();
            #endif
        }

        private void MakeWindowTransparent()
        {
            var margins = new MARGINS() { cxLeftWidth = -1 }; // -1 extends to full window
            var hwnd = GetActiveWindow();

            // Set window style to Popup (removes borders/title bar)
            // 524288 | 32  corresponds to WS_POPUP | WS_VISIBLE approx?
            // Original code used magic numbers: 524288 (0x80000 WS_EX_LAYERED?) | 32 (0x20 WS_EX_TRANSPARENT?)
            // SetWindowLong index -20 is GWL_EXSTYLE.
            
            // Replicating original magic numbers for safety as requested by user logic
            SetWindowLong(hwnd, -20, 524288 | 32);

            // Extend glass frame into client area to allow alpha transparency
            DwmExtendFrameIntoClientArea(hwnd, ref margins);
        }

#else
        private void Start()
        {
            Debug.LogWarning("TransparentWindow is only supported on Windows Standalone builds.");
        }
#endif
    }
}
