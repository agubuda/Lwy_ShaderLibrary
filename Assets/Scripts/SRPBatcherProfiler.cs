using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Profiling;
using UnityEngine.Rendering;

namespace Lwy.Scripts.Profiling
{
    /// <summary>
    /// Utility to profile SRP Batcher performance metrics.
    /// Toggles with F8, toggles Batcher with F9.
    /// </summary>
    public class SRPBatcherProfiler : MonoBehaviour
    {
        public bool isEnabled = true;
        private const float AverageStatDuration = 1.0f; // Stats refresh every second

        private int frameCount;
        private float accumulatedDeltaTime;
        private string statsLabel;
        private GUIStyle guiStyle;
        private bool oldBatcherState;

        private class RecorderEntry
        {
            public string name;
            public string oldName; // For backwards compatibility
            public int callCount;
            public float accTime;
            public Recorder recorder;
        }

        private enum MarkerId
        {
            StdRenderDraw,
            StdShadowDraw,
            SRPBRenderDraw,
            SRPBShadowDraw,
            RenderThreadIdle,
            StdRenderApplyShader,
            StdShadowApplyShader,
            SRPBRenderApplyShader,
            SRPBShadowApplyShader,
            PrepareBatchRendererGroupNodes,
        }

        // Must match MarkerId order
        private readonly RecorderEntry[] recordersList =
        {
            new RecorderEntry { name="RenderLoop.Draw" },
            new RecorderEntry { name="Shadows.Draw" },
            new RecorderEntry { name="SRPBatcher.Draw", oldName="RenderLoopNewBatcher.Draw" },
            new RecorderEntry { name="SRPBatcherShadow.Draw", oldName="ShadowLoopNewBatcher.Draw" },
            new RecorderEntry { name="RenderLoopDevice.Idle" },
            new RecorderEntry { name="StdRender.ApplyShader" },
            new RecorderEntry { name="StdShadow.ApplyShader" },
            new RecorderEntry { name="SRPBRender.ApplyShader" },
            new RecorderEntry { name="SRPBShadow.ApplyShader" },
            new RecorderEntry { name="PrepareBatchRendererGroupNodes" },
        };

        private void Awake()
        {
            InitializeRecorders();

            guiStyle = new GUIStyle
            {
                fontSize = 15
            };
            guiStyle.normal.textColor = Color.white;
            
            oldBatcherState = GraphicsSettings.useScriptableRenderPipelineBatching;
            ResetStats();
        }

        private void InitializeRecorders()
        {
            foreach (var entry in recordersList)
            {
                var sampler = Sampler.Get(entry.name);
                if (sampler.isValid)
                {
                    entry.recorder = sampler.GetRecorder();
                }
                else if (!string.IsNullOrEmpty(entry.oldName))
                {
                    sampler = Sampler.Get(entry.oldName);
                    if (sampler.isValid)
                        entry.recorder = sampler.GetRecorder();
                }
            }
        }

        private void ResetStats()
        {
            statsLabel = "Gathering data...";
            accumulatedDeltaTime = 0.0f;
            frameCount = 0;
            foreach (var entry in recordersList)
            {
                entry.accTime = 0.0f;
                entry.callCount = 0;
            }
        }

        private void Update()
        {
            // Toggle SRP Batcher
            if (Input.GetKeyDown(KeyCode.F9))
            {
                GraphicsSettings.useScriptableRenderPipelineBatching = !GraphicsSettings.useScriptableRenderPipelineBatching;
            }

            // Detect external change
            if (GraphicsSettings.useScriptableRenderPipelineBatching != oldBatcherState)
            {
                ResetStats();
                oldBatcherState = GraphicsSettings.useScriptableRenderPipelineBatching;
            }

            // Toggle Profiler UI
            if (Input.GetKeyDown(KeyCode.F8))
            {
                isEnabled = !isEnabled;
                ResetStats();
            }

            if (isEnabled)
            {
                UpdateProfilingData();
            }
        }

        private void UpdateProfilingData()
        {
            accumulatedDeltaTime += Time.unscaledDeltaTime;
            frameCount++;

            // Accumulate timings
            foreach (var entry in recordersList)
            {
                if (entry.recorder != null)
                {
                    entry.accTime += entry.recorder.elapsedNanoseconds / 1_000_000.0f; // ns to ms
                    entry.callCount += entry.recorder.sampleBlockCount;
                }
            }

            // Refresh stats text
            if (accumulatedDeltaTime >= AverageStatDuration)
            {
                float invFrameCount = 1.0f / frameCount;

                float avgStdRender = recordersList[(int)MarkerId.StdRenderDraw].accTime * invFrameCount;
                float avgStdShadow = recordersList[(int)MarkerId.StdShadowDraw].accTime * invFrameCount;
                float avgSRPBRender = recordersList[(int)MarkerId.SRPBRenderDraw].accTime * invFrameCount;
                float avgSRPBShadow = recordersList[(int)MarkerId.SRPBShadowDraw].accTime * invFrameCount;
                float rtIdleTime = recordersList[(int)MarkerId.RenderThreadIdle].accTime * invFrameCount;
                float avgPrepareNodes = recordersList[(int)MarkerId.PrepareBatchRendererGroupNodes].accTime * invFrameCount;

                bool batcherOn = GraphicsSettings.useScriptableRenderPipelineBatching;
                float totalCpuRender = avgStdRender + avgStdShadow + avgSRPBRender + avgSRPBShadow + avgPrepareNodes;

                var sb = new System.Text.StringBuilder();
                sb.AppendLine($"Accumulated time for RenderLoop.Draw and ShadowLoop.Draw (all threads)");
                sb.AppendLine($"{totalCpuRender:F2}ms CPU Rendering time ( incl {rtIdleTime:F2}ms RT idle )");

                if (batcherOn)
                {
                    sb.AppendLine($"  {avgSRPBRender + avgSRPBShadow:F2}ms SRP Batcher code path");
                    sb.AppendLine($"    {avgSRPBRender:F2}ms All objects ( {recordersList[(int)MarkerId.SRPBRenderApplyShader].callCount / frameCount} ApplyShader calls )");
                    sb.AppendLine($"    {avgSRPBShadow:F2}ms Shadows ( {recordersList[(int)MarkerId.SRPBShadowApplyShader].callCount / frameCount} ApplyShader calls )");
                }

                sb.AppendLine($"  {avgStdRender + avgStdShadow:F2}ms Standard code path");
                sb.AppendLine($"    {avgStdRender:F2}ms All objects ( {recordersList[(int)MarkerId.StdRenderApplyShader].callCount / frameCount} ApplyShader calls )");
                sb.AppendLine($"    {avgStdShadow:F2}ms Shadows ( {recordersList[(int)MarkerId.StdShadowApplyShader].callCount / frameCount} ApplyShader calls )");
                sb.AppendLine($"  {avgPrepareNodes:F2}ms PIR Prepare Group Nodes ( {recordersList[(int)MarkerId.PrepareBatchRendererGroupNodes].callCount / frameCount} calls )");
                
                float fps = frameCount / accumulatedDeltaTime;
                sb.AppendLine($"Global Main Loop: {accumulatedDeltaTime * 1000.0f * invFrameCount:F2}ms ({fps:F0} FPS)");

                statsLabel = sb.ToString();

                ResetStats();
            }
        }

        private void OnGUI()
        {
            if (!isEnabled) return;

            bool batcherOn = GraphicsSettings.useScriptableRenderPipelineBatching;
            
            float width = 700;
            float height = 280;

            string title = batcherOn ? "SRP Batcher ON (F9)" : "SRP Batcher OFF (F9)";
            
            GUILayout.BeginArea(new Rect(32, 50, width, height), title, GUI.skin.window);
            GUILayout.Label(statsLabel, guiStyle);
            GUILayout.EndArea();
        }
    }
}
