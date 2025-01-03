using UnityEngine;

public class ShowFPS : MonoBehaviour
{
    //设置帧率

    public float f_UpdateInterval = 0.5F;

    private float f_LastInterval;

    private int i_Frames = 0;

    private float f_Fps;

    private void Start()
    {
        Application.targetFrameRate = -1;
        f_LastInterval = Time.realtimeSinceStartup;
        i_Frames = 0;
    }

    private void OnGUI()
    {
        GUI.Label(new Rect(0, 100, 200, 200), "FPS:" + f_Fps.ToString("f2"));
    }

    private void Update()
    {
        ++i_Frames;

        if (Time.realtimeSinceStartup > f_LastInterval + f_UpdateInterval)
        {
            f_Fps = i_Frames / (Time.realtimeSinceStartup - f_LastInterval);

            i_Frames = 0;

            f_LastInterval = Time.realtimeSinceStartup;
        }
    }
}