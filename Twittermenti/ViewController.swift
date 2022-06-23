//
//  ViewController.swift
//  Twittermenti
//
//  Created by Angela Yu on 17/07/2019.
//  Copyright © 2019 London App Brewery. All rights reserved.
//

import UIKit
import NaturalLanguage
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
    
    func finishedFetchingTweets() {
        
        if let predictionsIn = predictBrain.predictTweetsSentiment(tweets: predictBrain.tweetsArray) {
            let countLabel = predictBrain.countAllLabels(predictions: predictionsIn)
            
            setEmoji(emotions: countLabel)
        } else {
            sentimentLabel.text = "🔨"
        }
        
    }
    
    func setEmoji(emotions:[String:Int]) {
        let dominantEmotionScore = emotions.max {
            $0.value < $1.value
        }
        
        let dominantEmotion = dominantEmotionScore!.key
        
        if dominantEmotion == "Neg" {
            sentimentLabel.text = "😡"
        } else if dominantEmotion == "Pos" {
            sentimentLabel.text = "🤩"
        } else if dominantEmotion == "Neutral" {
            sentimentLabel.text = "🙂"
        } else {
            sentimentLabel.text = "🙃"
        }
        
    }
    
}

