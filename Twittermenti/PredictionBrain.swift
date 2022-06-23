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
}

class PredictionBrain {
    
    var userName:String?
    var delegate: PredictionBrainDelegate?
    var userID:String?
    var tweetsArray:[String] = []
    private let errorConstant = "ERROR_INVALID_NAME"
    private let maxTweets = "100"
    private let labels = ["Pos", "Neg", "Neutral"]
    
    let baseUrl = "https://api.twitter.com/2/"
    
    //MARK: - Retrieving tweets
    
    func retrieveMentionsTweet(username: String) {
        
        retrieveUserId(userName: username) { response in
            if let userID = response {
                
                self.retrieveMentionsTweetOf(id: userID)
                
            } else {
                print("username invalid")
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
                completionHandler(self.errorConstant)
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
        
        var request = URLRequest(url: URL(string: urlString)!)
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
            print("Error caught while parsing JSON user ID, \(error)")
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
                
                let prediction = PredictionOutput(label: label, score: score)
                
                predictions.append(prediction)
            }
            
            let counts = countAllLabels(predictions: predictions)
            print(counts)
            return predictions
            
        } catch {
            print("Error caught while loading the MLModel. \(error)")
            return nil
        }
    }
    
    //MARK: - Scoring the predictions
    
    func countLabel(label:String, predictions:[PredictionOutput]) -> Int? {
        
        if !labels.contains(label) {
            return nil
        }
        
        var count = 0
        
        for prediction in predictions {
            if prediction.label == label {
                count += 1
            }
        }
        
        return count
    }
    
    func countAllLabels(predictions:[PredictionOutput]) -> [String : Int] {
        
        var labelsCount = [
            "Pos" : 0,
            "Neg" : 0,
            "Neutral" : 0
        ]
        
        var i = 0
        
        for label in labels {
            let key = labels[i]
            labelsCount[key] = countLabel(label: label, predictions: predictions)
            i += 1
        }
        
        return labelsCount
    }
    
}

//MARK: - Struct to store prediction outputs

struct PredictionOutput {
    let label:String
    let score:Double
}
