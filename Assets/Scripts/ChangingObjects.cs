using UnityEngine;

namespace Lwy.Scripts
{
    /// <summary>
    /// Handles cycling through a list of GameObjects, enabling one at a time.
    /// Useful for showcasing different models or variations.
    /// </summary>
    public class ChangingObjects : MonoBehaviour
    {
        [Tooltip("Array of GameObjects to cycle through.")]
        [SerializeField] private GameObject[] cars;

        private int currentIndex = 0;

        private void Start()
        {
            InitializeObjects();
        }

        /// <summary>
        /// Initializes the objects by disabling all except the first one.
        /// </summary>
        private void InitializeObjects()
        {
            if (cars == null || cars.Length == 0)
            {
                Debug.LogWarning("ChangingObjects: No objects assigned to 'cars' array.");
                return;
            }

            for (int i = 0; i < cars.Length; i++)
            {
                if (cars[i] != null)
                {
                    cars[i].SetActive(i == 0);
                }
            }
            currentIndex = 0;
        }

        /// <summary>
        /// Cyles to the next object in the list.
        /// Can be called via a UI Button event.
        /// </summary>
        public void OnStartButtonClick()
        {
            if (cars == null || cars.Length == 0) return;

            // Disable current object
            if (cars[currentIndex] != null)
            {
                cars[currentIndex].SetActive(false);
            }

            // Increment index and wrap around
            currentIndex = (currentIndex + 1) % cars.Length;

            // Enable new object
            if (cars[currentIndex] != null)
            {
                cars[currentIndex].SetActive(true);
            }

            Debug.Log($"Switched to object index: {currentIndex}");
        }
    }
}
