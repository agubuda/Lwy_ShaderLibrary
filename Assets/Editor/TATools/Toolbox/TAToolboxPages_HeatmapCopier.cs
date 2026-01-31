using UnityEngine;
using UnityEditor;
using System.IO;
using System.Collections.Generic;
using System.Linq;

namespace TAToolbox
{
    // =========================================================
    // 17. 纯测地线 Heatmap (带完美吸附 + 4骨骼修正)
    // =========================================================
    public class Page_HeatmapCopier : TAToolPage
    {
        public override string PageName => "17. 纯测地线 Heatmap (高精度)";

        // 输入 (Mesh资源)
        private Mesh sourceMesh;
        private Mesh targetMesh;

        // 参数
        private float snapThreshold = 0.0001f; // 完美吸附阈值 (0.1毫米)
        private float searchRadius = 0.05f;    // 搜索半径
        private float geodesicPenalty = 2.5f;  // 拓扑隔离系数
        private int sampleCount = 4;           // 混合采样数

        public override void OnGUI(string rootPath)
        {
            DrawHeader("纯测地线 Heatmap 传递 (智能吸附)");

            EditorGUILayout.HelpBox(
                "针对【嘴唇微裂】问题的优化版：\n\n" +
                "1. 【完美吸附 (Snap)】：既然顶点基本对应，如果距离极近(<0.1mm)，直接 1:1 复制权重，不进行混合。这能防止嘴唇边缘因平滑而裂开。\n" +
                "2. 【拓扑混合】：只有没对齐的“分裂点”，才使用测地线混合。\n" +
                "3. 【4骨骼限制】：严格保证每个顶点最多受4根骨骼影响，且权重和为1。\n", 
                MessageType.Info);

            GUILayout.Space(10);

            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            GUILayout.Label("资源输入 (Project Mesh):", EditorStyles.boldLabel);
            sourceMesh = (Mesh)EditorGUILayout.ObjectField("源 Mesh (带权重)", sourceMesh, typeof(Mesh), false);
            targetMesh = (Mesh)EditorGUILayout.ObjectField("目标 Mesh (接收权重)", targetMesh, typeof(Mesh), false);
            
            if (sourceMesh != null && targetMesh != null)
            {
                EditorGUILayout.LabelField($"源: {sourceMesh.vertexCount} 顶点 | 目标: {targetMesh.vertexCount} 顶点", EditorStyles.miniLabel);
            }
            EditorGUILayout.EndVertical();

            GUILayout.Space(10);
            EditorGUILayout.LabelField("精度设置:", EditorStyles.boldLabel);
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            
            snapThreshold = EditorGUILayout.FloatField("完美吸附距离 (米)", snapThreshold);
            EditorGUILayout.HelpBox("如果距离小于此值，视为同一个点，直接复制权重 (防止过平滑)。默认 0.0001 (0.1mm)。", MessageType.None);

            searchRadius = EditorGUILayout.FloatField("热力扩散半径", searchRadius);
            
            geodesicPenalty = EditorGUILayout.Slider("拓扑隔离敏感度", geodesicPenalty, 1.1f, 5.0f);
            EditorGUILayout.HelpBox("隔离嘴唇/眼皮的关键。值越大越难跨越缝隙。", MessageType.None);

            sampleCount = EditorGUILayout.IntSlider("混合采样数", sampleCount, 2, 8);

            EditorGUILayout.EndVertical();

            GUILayout.Space(15);

            GUI.backgroundColor = new Color(1f, 0.5f, 0.5f);
            if (GUILayout.Button("开始高精度计算", GUILayout.Height(40)))
            {
                if (Validate())
                {
                    TransferWeightsHeatmap();
                }
            }
            GUI.backgroundColor = Color.white;
        }

        private bool Validate()
        {
            if (!sourceMesh || !targetMesh)
            {
                EditorUtility.DisplayDialog("错误", "请拖入 Mesh 资源。", "OK");
                return false;
            }
            if (sourceMesh.boneWeights.Length == 0)
            {
                EditorUtility.DisplayDialog("错误", "源 Mesh 没有骨骼权重。", "OK");
                return false;
            }
            return true;
        }

        private Dictionary<int, List<KeyValuePair<int, float>>> BuildWeightedGraph(Mesh mesh)
        {
            var dict = new Dictionary<int, List<KeyValuePair<int, float>>>();
            int[] tris = mesh.triangles;
            Vector3[] verts = mesh.vertices;

            void AddEdge(int a, int b)
            {
                if (!dict.ContainsKey(a)) dict[a] = new List<KeyValuePair<int, float>>();
                if (!dict.ContainsKey(b)) dict[b] = new List<KeyValuePair<int, float>>();
                float dist = Vector3.Distance(verts[a], verts[b]);
                if (!dict[a].Any(x => x.Key == b)) dict[a].Add(new KeyValuePair<int, float>(b, dist));
                if (!dict[b].Any(x => x.Key == a)) dict[b].Add(new KeyValuePair<int, float>(a, dist));
            }

            for (int i = 0; i < tris.Length; i += 3)
            {
                AddEdge(tris[i], tris[i + 1]);
                AddEdge(tris[i + 1], tris[i + 2]);
                AddEdge(tris[i + 2], tris[i]);
            }
            return dict;
        }

        private void TransferWeightsHeatmap()
        {
            try
            {
                Mesh newMesh = Object.Instantiate(targetMesh);
                newMesh.name = targetMesh.name + "_HeatmapRigged";
                newMesh.bindposes = sourceMesh.bindposes;

                Vector3[] sVerts = sourceMesh.vertices;
                BoneWeight[] sWeights = sourceMesh.boneWeights;
                int sCount = sVerts.Length;

                Vector3[] tVerts = targetMesh.vertices;
                BoneWeight[] tNewWeights = new BoneWeight[tVerts.Length];
                int tCount = tVerts.Length;

                EditorUtility.DisplayProgressBar("预处理", "构建网格拓扑结构...", 0f);
                var graph = BuildWeightedGraph(sourceMesh);

                float maxSearchDistSq = searchRadius * searchRadius;
                float snapSq = snapThreshold * snapThreshold;

                int snappedCount = 0;

                for (int i = 0; i < tCount; i++)
                {
                    if (i % 20 == 0)
                    {
                        if (EditorUtility.DisplayCancelableProgressBar("计算中", $"Processing {i}/{tCount}", (float)i / tCount))
                            throw new System.Exception("用户取消");
                    }

                    Vector3 tPos = tVerts[i];

                    // 1. 寻找最近的种子点
                    int seedIndex = -1;
                    float minSeedDistSq = float.MaxValue;

                    for (int j = 0; j < sCount; j++)
                    {
                        float d = (tPos - sVerts[j]).sqrMagnitude;
                        if (d < minSeedDistSq)
                        {
                            minSeedDistSq = d;
                            seedIndex = j;
                        }
                    }

                    // --- 策略 A: 完美吸附 (Snap) ---
                    // 如果距离极其接近，视为完全匹配，直接复制，不进行混合
                    if (minSeedDistSq <= snapSq)
                    {
                        tNewWeights[i] = sWeights[seedIndex];
                        snappedCount++;
                        continue; // 跳过后续复杂计算
                    }

                    // --- 策略 B: Geodesic Heatmap 混合 ---
                    // 只有在没对齐的地方才进行平滑混合
                    
                    // 收集候选点
                    List<int> candidates = new List<int>();
                    for (int j = 0; j < sCount; j++)
                    {
                        if ((tPos - sVerts[j]).sqrMagnitude <= maxSearchDistSq)
                        {
                            candidates.Add(j);
                        }
                    }

                    // 拓扑路径判定
                    Dictionary<int, float> geoDists = RunDijkstra(graph, seedIndex, candidates, searchRadius * geodesicPenalty);

                    var validNeighbors = new List<KeyValuePair<int, float>>();

                    foreach (int candIdx in candidates)
                    {
                        if (!geoDists.ContainsKey(candIdx)) continue; // 不连通

                        float geoDist = geoDists[candIdx];
                        float spatialDist = Vector3.Distance(sVerts[seedIndex], sVerts[candIdx]);

                        // 拓扑隔离判定
                        if (geoDist > (spatialDist * geodesicPenalty) + 0.0001f) continue;

                        float distToTarget = Vector3.Distance(tPos, sVerts[candIdx]);
                        float score = 1.0f / (distToTarget * distToTarget + 0.000001f);
                        
                        validNeighbors.Add(new KeyValuePair<int, float>(candIdx, score));
                    }

                    // 混合
                    var finalSamples = validNeighbors.OrderByDescending(x => x.Value).Take(sampleCount).ToList();

                    if (finalSamples.Count > 0)
                    {
                        Dictionary<int, float> weightAccumulator = new Dictionary<int, float>();
                        foreach (var sample in finalSamples)
                        {
                            AddBoneWeight(weightAccumulator, sWeights[sample.Key], sample.Value);
                        }
                        tNewWeights[i] = NormalizeAndConvert(weightAccumulator);
                    }
                    else
                    {
                        tNewWeights[i] = sWeights[seedIndex];
                    }
                }

                newMesh.boneWeights = tNewWeights;
                SaveAndSelect(newMesh);

                EditorUtility.DisplayDialog("完成", 
                    $"计算完成！\n\n" +
                    $"总顶点数: {tCount}\n" +
                    $"完美吸附数: {snappedCount} (直接复制)\n" +
                    $"混合处理数: {tCount - snappedCount} (Heatmap平滑)\n\n" +
                    "吸附比例高说明模型对应良好，嘴裂问题应已解决。", 
                    "OK");
            }
            catch (System.Exception e)
            {
                Debug.LogError(e);
                EditorUtility.DisplayDialog("错误", e.Message, "OK");
            }
            finally
            {
                EditorUtility.ClearProgressBar();
            }
        }

        private Dictionary<int, float> RunDijkstra(Dictionary<int, List<KeyValuePair<int, float>>> graph, int startNode, List<int> potentialTargets, float maxScanDist)
        {
            var distances = new Dictionary<int, float>();
            var pq = new PriorityQueue<int>();

            distances[startNode] = 0f;
            pq.Enqueue(startNode, 0f);

            while (pq.Count > 0)
            {
                var current = pq.Dequeue();
                float currentDist = distances[current];

                if (currentDist > maxScanDist) continue; 

                if (!graph.ContainsKey(current)) continue;

                foreach (var edge in graph[current])
                {
                    int neighbor = edge.Key;
                    float weight = edge.Value;
                    float newDist = currentDist + weight;

                    if (newDist < maxScanDist)
                    {
                        if (!distances.ContainsKey(neighbor) || newDist < distances[neighbor])
                        {
                            distances[neighbor] = newDist;
                            pq.Enqueue(neighbor, newDist);
                        }
                    }
                }
            }
            return distances;
        }

        private void AddBoneWeight(Dictionary<int, float> acc, BoneWeight bw, float scale)
        {
            if (bw.weight0 > 0) AddW(acc, bw.boneIndex0, bw.weight0 * scale);
            if (bw.weight1 > 0) AddW(acc, bw.boneIndex1, bw.weight1 * scale);
            if (bw.weight2 > 0) AddW(acc, bw.boneIndex2, bw.weight2 * scale);
            if (bw.weight3 > 0) AddW(acc, bw.boneIndex3, bw.weight3 * scale);
        }

        private void AddW(Dictionary<int, float> d, int bIdx, float w)
        {
            if (!d.ContainsKey(bIdx)) d[bIdx] = 0f;
            d[bIdx] += w;
        }

        private BoneWeight NormalizeAndConvert(Dictionary<int, float> acc)
        {
            // 1. 排序取前4大
            var sorted = acc.OrderByDescending(x => x.Value).Take(4).ToList();
            
            // 2. 求和
            float sum = 0f;
            foreach (var kv in sorted) sum += kv.Value;

            BoneWeight bw = new BoneWeight();
            if (sum > 0)
            {
                // 3. 归一化 (确保和为 1.0)
                float scale = 1.0f / sum;
                
                if (sorted.Count > 0) { bw.boneIndex0 = sorted[0].Key; bw.weight0 = sorted[0].Value * scale; }
                if (sorted.Count > 1) { bw.boneIndex1 = sorted[1].Key; bw.weight1 = sorted[1].Value * scale; }
                if (sorted.Count > 2) { bw.boneIndex2 = sorted[2].Key; bw.weight2 = sorted[2].Value * scale; }
                if (sorted.Count > 3) { bw.boneIndex3 = sorted[3].Key; bw.weight3 = sorted[3].Value * scale; }
            }
            return bw;
        }

        private void SaveAndSelect(Mesh newMesh)
        {
            string targetAssetPath = AssetDatabase.GetAssetPath(targetMesh);
            string saveDirectory = string.IsNullOrEmpty(targetAssetPath) ? "Assets" : Path.GetDirectoryName(targetAssetPath);
            string fullPath = Path.Combine(saveDirectory, newMesh.name + ".asset").Replace("\\", "/");
            fullPath = AssetDatabase.GenerateUniqueAssetPath(fullPath);
            AssetDatabase.CreateAsset(newMesh, fullPath);
            AssetDatabase.SaveAssets();
            Selection.activeObject = newMesh;
            EditorGUIUtility.PingObject(newMesh);
        }

        class PriorityQueue<T>
        {
            private List<KeyValuePair<T, float>> elements = new List<KeyValuePair<T, float>>();
            public int Count => elements.Count;
            public void Enqueue(T item, float priority) { elements.Add(new KeyValuePair<T, float>(item, priority)); }
            public T Dequeue()
            {
                int bestIndex = 0;
                for (int i = 0; i < elements.Count; i++) if (elements[i].Value < elements[bestIndex].Value) bestIndex = i;
                T bestItem = elements[bestIndex].Key;
                elements.RemoveAt(bestIndex);
                return bestItem;
            }
        }
    }
}