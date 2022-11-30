#if UNITY_EDITOR
  using System.Collections;
  using System.Collections.Generic;
  using UnityEngine;
  using UnityEditor;
  using System.IO;
  public class CreateLUT : MonoBehaviour
  {
      static string FilePath = "Assets/BaseLUT.png";
      [MenuItem("Tools/Generate BaseLUT")]
      static void CreatLutTex()
      {
          var tex = new Texture2D(1024,32);
          var colors = new Color[1024,32];
          for (var b = 0; b < 32; b++)
          {
              for (var g = 0; g < 32; g++)
              {
                  for (var r = 0; r < 32; r++)
                  {
                      colors[r + b * 32, g] = new Color(r/32f,g/32f,b/32f);
                  }
              }
          }
          for (var h = 0; h < 1024; h++)
          {
              for (var v = 0; v < 32; v++)
              {
                  tex.SetPixel(h, v, colors[h, v]) ;
              }
          }
          tex.Apply();
          var btys=tex.EncodeToPNG();
          File.WriteAllBytes(FilePath,btys);
      }
  }
  #endif