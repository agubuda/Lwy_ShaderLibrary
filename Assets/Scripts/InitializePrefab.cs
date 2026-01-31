using UnityEngine;

namespace Lwy.Scripts
{
    /// <summary>
    /// Instantiates a grid of prefabs at runtime.
    /// Useful for generating test scenes or patterns.
    /// </summary>
    public class InitializePrefab : MonoBehaviour
    {
        [Header("Prefabs")]
        [SerializeField] private GameObject standardPrefab;
        [SerializeField] private GameObject highlightPrefab;

        [Header("Grid Settings")]
        [Tooltip("The dimension of the grid (size x size x 3).")]
        [SerializeField] private int gridSize = 8;
        
        [Tooltip("Interval for placing the highlight prefab.")]
        [SerializeField] private int highlightInterval = 3;

        [Tooltip("Distance between prefabs.")]
        [SerializeField] private float spacing = 0.5f;

        private void Awake()
        {
            GenerateGrid();
        }

        private void GenerateGrid()
        {
            if (standardPrefab == null)
            {
                Debug.LogWarning("InitializePrefab: Standard Prefab is not assigned.");
                return;
            }

            float offset = (gridSize / 2f) * spacing;

            for (int x = 0; x < gridSize; x++)
            {
                for (int y = 0; y < gridSize; y++)
                {
                    // Fixed depth of 3 layers as per original code
                    for (int z = 0; z < 3; z++) 
                    {
                        // Calculate position centered around (0,0,0)
                        Vector3 position = new Vector3(
                            y * spacing - offset, 
                            x * spacing - offset, 
                            z * spacing - offset
                        );

                        // Always spawn standard prefab
                        Instantiate(standardPrefab, position, Quaternion.identity, transform);

                        // conditionally spawn highlight prefab on top/instead? 
                        // Original code spawned BOTH at the same location. 
                        // Preserving original behavior: spawning highlight prefab overlapping.
                        bool isHighlightPosition = (x % highlightInterval == 0) && 
                                                   (y % highlightInterval == 0) && 
                                                   (z % highlightInterval == 0);

                        if (isHighlightPosition && highlightPrefab != null)
                        {
                            Instantiate(highlightPrefab, position, Quaternion.identity, transform);
                        }
                    }
                }
            }
        }
    }
}
