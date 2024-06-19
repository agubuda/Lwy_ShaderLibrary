// using System.Diagnostics;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class lightShining : MonoBehaviour
{
    // public List<Materials> Material;
    // public class Materials{
    //     public Material material;
    // }
    [SerializeField]
    public Material[] Materials;

    // public Material material1;
    public Color color;

    private Color color1;
    public float intensityMin = 0f;
    public float intensityMax = 11f;
    private float intensity;

    public int multiplier = 7;

    private float intensitySin;

    // Start is called before the first frame update
    private void Start()
    {
        // material1 = GetComponent<Renderer>().material;

        color1 = color;
        // Debug.Log(color);
        intensity = Random.Range(intensityMin, intensityMax);
        multiplier += Random.Range(0, 2);
    }

    // Update is called once per frame
    private void Update()
    {
        intensity += Time.deltaTime;
        intensitySin = Mathf.Abs(Mathf.Sin(intensity)) * multiplier;
        // Debug.Log(a);

        float factor = Mathf.Pow(2, intensitySin);

        foreach (Material mat in Materials)
        {
            color.r *= factor;
            color.g *= factor;
            color.b *= factor;

            // Debug.Log(color);
            mat.SetColor("_EmissionColor", color);
            // color = Color.red;
            color = color1;
            // Debug.Log(mat);
        }
    }
}