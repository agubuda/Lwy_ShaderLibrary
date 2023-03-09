using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ChangingObejects : MonoBehaviour
{

    public GameObject[] cars;
    private int i;

    public void OnStartButtonClick(){
        i++;

        if(i>=cars.Length){
            i= 0;
            cars[cars.Length-1].SetActive(false);
        }

        if(i>0)
            cars[i-1].SetActive(false);

        cars[i].SetActive(true);

        Debug.Log(i);
    }

    // Start is called before the first frame update
    void Start()
    {
        int i = 0;
        cars[i].SetActive(true);
        // GameObject[] cars = new ;
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
