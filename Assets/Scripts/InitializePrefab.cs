using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class InitializePrefab : MonoBehaviour
{
    public GameObject prefab; 
    public GameObject prefab1; 
    int T= 8;
    int lightIntensity= 3;
    // Start is called before the first frame update
    void Awake()
    {
        for(int x = 0; x<T; x++){
            for(int y = 0; y<T; y++){
                for(int z = 0; z<3; z++){  
                    Instantiate(prefab, new Vector3(y * 0.5f - T/2*0.5f,x * 0.5f - T/2 *0.5f,z * 0.5f - T/2 *0.5f), Quaternion.identity);

                    if(x%lightIntensity == 0 && y%lightIntensity == 0 && z%lightIntensity==0){
                        Instantiate(prefab1, new Vector3(y * 0.5f - T/2*0.5f,x * 0.5f - T/2 *0.5f,z * 0.5f - T/2 *0.5f), Quaternion.identity);
                }
                }
            }
        }
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
