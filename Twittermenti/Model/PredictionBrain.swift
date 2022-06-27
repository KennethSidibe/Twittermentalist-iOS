//
//  PredictionBrain.swift
//  Twittermenti
//
//  Created by Kenneth Sidibe on 2022-06-21.
//  Copyright © 2022 London App Brewery. All rights reserved.
//

import Foundation
import NaturalLanguage
import CoreML

protocol PredictionBrainDelegate {
    func finishedFetchingTweets()
    func signalInvalidUsername()
}

class PredictionBrain {
    
    private var userName:String?
    var delegate: PredictionBrainDelegate?
    private var userID:String?
    var tweetsArray:[String] = []
    private let errorConstant = "ERROR_INVALID_NAME"
    private let maxTweets = "20"
    private let labels = ["Pos", "Neg", "Neutral"]
    
    private let baseUrl = "https://api.twitter.com/2/"
    
    //MARK: - Retrieving tweets
    
    func retrieveMentionsTweet(username: String) {
        self.userName = username
        retrieveUserId(userName: username) { response in
            
            if let userID = response {
                self.userID = userID
                self.retrieveMentionsTweetOf(id: userID)
                
            } else {
                
                print("username invalid")
                
                DispatchQueue.main.async {
                    self.delegate?.signalInvalidUsername()
                }
            }
            
        }
    }
    
    func retrieveMentionsTweetOf(id:String) {
        
        let baseUrl = "https://api.twitter.com/2/"
        let endpoint = "users/\(id)/mentions"
        
        let requestUrl = baseUrl + endpoint
        
        performTimelineRequest(urlString: requestUrl) { response in
            
            self.tweetsArray = response
            
            DispatchQueue.main.async {
                self.delegate?.finishedFetchingTweets()
            }
        }
        
    }
    
    func retrieveUserId(userName: String, completionHandler: @escaping (_ response: String?) -> Void){
        
        let baseUrl = "https://api.twitter.com/2/"
        let endpoint = "users/by/username/\(userName)"
        
        let requestUrl = baseUrl + endpoint
        
        
        performUserIDRequest(urlString: requestUrl) { response in
            
            if response != self.errorConstant {
                
                self.userID = response
                completionHandler(response)
                
            } else {
                completionHandler(nil)
            }
        }
    }
    
    //MARK: - performing GET Request
    
    func performTimelineRequest(urlString: String,  completionHandler: @escaping (_ response: [String]) -> Void) {
        
        let queryItems = [
            URLQueryItem(name: "max_results", value: maxTweets),
            URLQueryItem(name: "tweet.fields", value: "lang")
        ]
        var urlComponents = URLComponents(string: urlString)!
        urlComponents.queryItems = queryItems
        
        
        var request = URLRequest(url: urlComponents.url!)
        request.allHTTPHeaderFields = [
            "Authorization" : "Bearer \(bearerToken)",
        ]
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            
            if let safeData = data {
                
                if let tweetMentionsArray = self.parseJSON(tweetMentionsData: safeData) {
                    
                    var englishTweets = [String]()
                    
                    for tweet in tweetMentionsArray {
                        if tweet.lang == "en" {
                            englishTweets.append(tweet.text)
                        }
                    }
                    
                    completionHandler(englishTweets)
                }
                
            } else {
                print("Error while fetching the data, \(error)")
            }
        }
        
        task.resume()
    }
    
    func performUserIDRequest(urlString: String,  completionHandler: @escaping (_ response: String?) -> Void) {
        
        guard let url = URL(string: urlString) else {
            completionHandler(self.errorConstant)
            return
        }
        
        var request = URLRequest(url: url)
        
        request.allHTTPHeaderFields = [
            "Authorization" : "Bearer \(bearerToken)",
        ]
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            
            if let safeData = data {
                
                if let userIDString = self.parseJSON(userIDData: safeData) {
                    completionHandler(userIDString)
                } else {
                    completionHandler(self.errorConstant)

                }
                
            } else {
                print("Error while fetching the data, \(error)")
            }
        }
        
        task.resume()
    }
    
    //MARK: - JSON Parsing
    
    func parseJSON(tweetMentionsData: Data) -> [tweetMentions]? {
        
        let decoder = JSONDecoder()
        var mentions = [tweetMentions]()
        
        do {
            let mentionJson = try decoder.decode(MentionsData.self, from: tweetMentionsData)
            mentions = mentionJson.data
            
            return mentions
            
        } catch {
            print("could not parse, \(error)")
            return nil
        }
    }
    
    func parseJSON(userIDData:Data) -> String? {
        let decoder = JSONDecoder()
        
        do {
            let decodedData = try decoder.decode(UserIDData.self, from: userIDData)
            let userID = decodedData.data.id
            let name = decodedData.data.name
            
            return userID
            
        } catch {
            return nil
        }
    }
    
    //MARK: - predict text sentiment
    
    func predictTweetSentiment(tweet:String) -> String? {
        
        do {
            let classifier = try SentimentAnalyzer(configuration: MLModelConfiguration())
            
            do {
                let sentiment = try classifier.prediction(text: tweet)
                return sentiment.label
            } catch {
                print("No prediction could have been made from text, \(error)")
            }
            
            
        } catch {
            print("Error caught while loading the MLModel. \(error)")
        }
        return nil
    }
    
    func predictTweetsSentiment(tweets: [String]) -> [PredictionOutput]? {
        
        var predictions:[PredictionOutput] = [PredictionOutput]()
        
        do {
            
            let mlModel = try SentimentAnalyzer(configuration: MLModelConfiguration()).model
            
            let classifier = try NLModel(mlModel: mlModel)
            
            for tweet in tweets {
                
                let sentiment = classifier.predictedLabelHypotheses(for: tweet, maximumCount: 1)
                
                let label = sentiment.keys.first!
                let score = sentiment.values.first!
                
                let prediction = PredictionOutput(tweet:tweet, label: label, score: score)
                
                predictions.append(prediction)
            }
            
            let counts = countAllLabels(with: predictions)
            return predictions
            
        } catch {
            print("Error caught while loading the MLModel. \(error)")
            return nil
        }
    }
    
    //MARK: - Scoring the predictions
    
    func countLabel(label:String, predictions:[PredictionOutput]) -> (count:Int, tweet:String)? {
        
        var highestEmotion = ""
        var highestScore:Double = -1.0
        
        if !labels.contains(label) {
            print("Label is incorrect")
            return nil
        }
        
        var count = 0
        
        for prediction in predictions {
            
            if prediction.label == label {
                
                if prediction.score > highestScore {
                    highestScore = prediction.score
                    highestEmotion = prediction.tweet
                }
                
                count += 1
            }
        }
        
        return (count:count, tweet:highestEmotion)
    }
    
    func countAllLabels(with predictions:[PredictionOutput]) -> CountsWithEmotion? {
        
        var labelsCount = [
            "Pos" : 0,
            "Neg" : 0,
            "Neutral" : 0
        ]
        var labelsEmotion = [
            "Pos" : "",
            "Neg" : "",
            "Neutral" : ""
        ]
        
        var i = 0
        
        for _ in labels {
            
            let key = labels[i]
            
            if let countLabelAndEmotion = countLabel(label: key, predictions: predictions) {
                
                labelsCount[key] = countLabelAndEmotion.count
                labelsEmotion[key] = countLabelAndEmotion.tweet
                
                i += 1
                
            } else {
                return nil
            }
            
            
        }
        
        return CountsWithEmotion(labelsCount: labelsCount, strongestTweet: labelsEmotion)
    }
    
    func whatsTheStrongestEmotion(labelsCount:[String : Int]) -> String {
        let dominantEmotionScore = labelsCount.max {
            $0.value < $1.value
        }
        
        return dominantEmotionScore!.key
    }
    
    func retrieveStrongestTweet(with countsEmotions:CountsWithEmotion) -> (tweet:String, emotion:String) {
        let counts = countsEmotions.labelsCount
        let strongestLabel = self.whatsTheStrongestEmotion(labelsCount: counts)
        
        let tweet = countsEmotions.strongestTweet[strongestLabel]!
        
        
        return (tweet:tweet, emotion:strongestLabel)
    }
    func getUsername() -> String? {
        return self.userName
    }
    
}

//MARK: - Struct to store prediction outputs

struct PredictionOutput {
    let tweet:String
    let label:String
    let score:Double
}

//MARK: - Struct to store labels alongside their occurence and the strongest prediction score

struct CountsWithEmotion {
    let labelsCount: [String : Int]
    let strongestTweet:[String : String]
}
