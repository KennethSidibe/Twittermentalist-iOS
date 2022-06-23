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
    var brain = PredictionBrain()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        brain.delegate = self
        
    }

    @IBAction func predictPressed(_ sender: Any) {
        
        let username = textField.text!
        
        if !username.isEmpty {
            brain.retrieveMentionsTweet(username: username)
        } else {
            print("text field is empty")
        }
        
    }
    
    func finishedFetchingTweets() {
        
        if let predictions = brain.predictTweetsSentiment(tweets: brain.tweetsArray) {
            
            if let countsWithEmotion = brain.countAllLabels(predictions: predictions) {
                
                let counts = countsWithEmotion.labelsCount
                let emotions = countsWithEmotion.strongestTweet
                
                let strongestLabel = brain.whatsTheStrongestEmotion(labelsCount: counts)
                let strongestTweet = brain.retrieveStrongestTweet(label: strongestLabel, emotionDict: emotions)
                
                print(strongestTweet)
            }
            
        }
        
    }
    
    func signalInvalidUsername() {
        sentimentLabel.text = "🔨"
    }
    
    func setEmoji(counts: [String:Int] ) {
        
        let positiveLabel = counts["Pos"]!
        let negativeLabel = counts["Neg"]!
        
        let score = positiveLabel - negativeLabel
        
        if score > 50 {
            sentimentLabel.text = "🤩"
        }
        else if score > 20 {
            sentimentLabel.text = "😍"
        }
        else if score > 10 {
            sentimentLabel.text = "😄"
        }
        else if score == 0 {
            sentimentLabel.text = "🫥"
        }
        else if score < -50 {
            sentimentLabel.text = "🤮"
        }
        else if score < -20 {
            sentimentLabel.text = "🤬"
        }
        else if score < -10 {
            sentimentLabel.text = "😑"
        }
        else if score < -5 {
            sentimentLabel.text = "🫤"
        }
        else if score < 0 {
            sentimentLabel.text = "😠"
        }
        else {
            sentimentLabel.text = "🫠"
        }
        
    }
    
}

