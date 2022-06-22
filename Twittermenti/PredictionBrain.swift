//
//  PredictionBrain.swift
//  Twittermenti
//
//  Created by Kenneth Sidibe on 2022-06-21.
//  Copyright © 2022 London App Brewery. All rights reserved.
//

protocol PredictionBrainDelegate {
    func didFinishTask()
}

import Foundation
import TwitterAPIKit
import AuthenticationServices


class PredictionBrain {
    
    var userName:String?
    var delegate: PredictionBrainDelegate?
    var userID:String?
    var tweetsArray:[String] = []
    private let errorConstant = "ERROR_INVALID_NAME"
    
    let baseUrl = "https://api.twitter.com/2/"
    
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
        let endpoint = "users/\(appleID)/mentions"
        
        let requestUrl = baseUrl + endpoint
        
        
        performTimelineRequest(urlString: requestUrl) { response in
            self.tweetsArray = response
            
            DispatchQueue.main.async {
                self.delegate?.didFinishTask()
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
    
    func performTimelineRequest(urlString: String,  completionHandler: @escaping (_ response: [String]) -> Void) {
        
        let queryItems = [
            URLQueryItem(name: "max_results", value: "100"),
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
    
    func parseJSON(errorData: Data) -> String? {
        let decoder = JSONDecoder()

        let JSONText = String(data: errorData, encoding: .utf8)
        print(JSONText)

        do {
            let decodedData = try decoder.decode(Errors.self, from: errorData)
            let errorType = decodedData.errors
            return errorType[0].title
        } catch {
            print("error of parsing error message\(error)")
            return nil
        }
    }
    
}
