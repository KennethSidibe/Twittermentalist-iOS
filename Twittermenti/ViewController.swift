//
//  ViewController.swift
//  Twittermenti
//
//  Created by Angela Yu on 17/07/2019.
//  Copyright © 2019 London App Brewery. All rights reserved.
//

import UIKit
import TwitterAPIKit
import AuthenticationServices
import CoreML
let appleID:String = "380749300"


class ViewController: UIViewController, PredictionBrainDelegate {
    
    
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var sentimentLabel: UILabel!
    var predictBrain = PredictionBrain()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        predictBrain.delegate = self
        
    }

    @IBAction func predictPressed(_ sender: Any) {
        let text = textField.text!
        predictBrain.retrieveMentionsTweet(username: text)
    }
    
    func didFinishTask() {
        print("got the shit")
        
        for tweet in predictBrain.tweetsArray {
            print(tweet)
        }
        print(predictBrain.tweetsArray.count)
    }
    
}

