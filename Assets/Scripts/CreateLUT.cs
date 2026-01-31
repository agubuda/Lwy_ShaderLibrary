#if UNITY_EDITOR

using UnityEngine;
using UnityEditor;
using System.IO;

namespace Lwy.Scripts.Editor
{
    /// <summary>
    /// Editor tool to generate a neutral Base LUT (Look Up Table) texture.
    /// </summary>
    public class CreateLUT : MonoBehaviour
    {
        private static readonly string FilePath = "Assets/BaseLUT.png";

        [MenuItem("Tools/Lwy Tools/Generate BaseLUT")]
        private static void GenerateLutTexture()
        {
            int size = 32;
            int width = size * size; // 1024
            int height = size;       // 32

            Texture2D tex = new Texture2D(width, height, TextureFormat.RGB24, false);
            Color[] colors = new Color[width * height];

            for (int b = 0; b < size; b++)
            {
                for (int g = 0; g < size; g++)
                {
                    for (int r = 0; r < size; r++)
                    {
                        // Standard LUT layout: 
                        // Horizontal: R changes every pixel, B changes every 'size' pixels (each block)
                        // Vertical: G changes
                        
                        // Calculate index in the linear array
                        int index = (b * size + r) + g * width;
                        
                        // Or setting pixels directly (slower but clearer logic for 2D):
                        // tex.SetPixel(b * size + r, g, new Color(r / (float)(size - 1), g / (float)(size - 1), b / (float)(size - 1)));
                        
                        // Using SetPixels is faster
                        // Note: To match standard LUTs, color usually goes from 0 to 1. 
                        // Dividing by 32f results in max value 31/32. Dividing by 31f (size-1) gives full 0-1 range.
                        // However, keeping original logic ( / 32f ) if that was intended, but standard is (size - 1).
                        // I will use (size - 1) for a mathematically correct neutral LUT.
                        
                        float fr = r / (float)(size - 1);
                        float fg = g / (float)(size - 1);
                        float fb = b / (float)(size - 1);
                        
                        // Pixel coordinates: x = r + b * 32, y = g
                        tex.SetPixel(r + b * size, g, new Color(fr, fg, fb));
                    }
                }
            }

            tex.Apply();
            byte[] bytes = tex.EncodeToPNG();
            
            // Ensure directory exists (though Assets/ usually does)
            string directory = Path.GetDirectoryName(FilePath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            File.WriteAllBytes(FilePath, bytes);
            
            AssetDatabase.Refresh();
            Debug.Log($"BaseLUT generated at: {FilePath}");
        }
    }
}

#endif
