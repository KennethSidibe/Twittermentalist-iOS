//
//  JSONStruct.swift
//  Twittermenti
//
//  Created by Kenneth Sidibe on 2022-06-22.
//  Copyright © 2022 London App Brewery. All rights reserved.
//

import Foundation

struct MentionsData:Codable {
    let data: [tweetMentions]
}

struct tweetMentions:Codable {
    let text: String
    let lang: String
}

struct UserID:Codable {
    let id:String
    let name:String
    let username:String
}

struct UserIDData:Codable {
    let data: UserID
}
