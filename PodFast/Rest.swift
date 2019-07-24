//
//  Rest.swift
//  PodFast
//
//  Created by Orestis on 10/07/2019.
//  Copyright © 2019 Orestis Papadopoulos. All rights reserved.
//

import Foundation
import AlamofireObjectMapper
import Alamofire
import FeedKit
import RealmSwift
import ReactiveSwift
import Result

class Rest {

    static let DefaultErrorHandler:(Error) -> Void = { error in
        print(error)
    }

    static func checkConfiguration() {
        if let path = Bundle.main.path(forResource: "data", ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                if let jsonData = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves) as? [String:Any] {
                    if let configData = ConfigFileData(JSON: jsonData), let configVersion = configData.version {
                        if configVersion > DBHelper.shared.getCurrentConfigVersion() {
                            DBHelper.shared.updatePodcasts(fromConfigData: configData)
                        }
                    }
                }
            } catch {
                // handle error
            }
        }
    }

    static func appleTopPodcastsRequest(completionBlock: @escaping (DataResponse<ItunesPodcastLookUpResponse>) -> Void,
                                        errorHandler: @escaping (Error) -> Void = DefaultErrorHandler)
    {
        let URL = "https://rss.itunes.apple.com/api/v1/us/podcasts/top-podcasts/all/100/explicit.json"
        Alamofire.request(URL).responseObject { (response: DataResponse<AppleTopPodcastsResponse>) in
            if response.result.isSuccess {
                if let pendingUpdateDate = response.result.value?.updated {
                    let lastUpdateDate = DBHelper.shared.getLastAppleTopPodcastsUpdateDate()
                    if  pendingUpdateDate > lastUpdateDate {

                        print("Will Update Podcast Info")

                        DBHelper.shared.updateLastAppleTopPodcastsUpdateDate(toDate: pendingUpdateDate)

                        // Itunes Lookup by id
                        var baseURL = "https://itunes.apple.com/lookup?id="
                        if let podcasts = response.result.value?.podcasts {
                            for podcast in podcasts {
                                if let podcastId = podcast.id {
                                    baseURL.append("\(podcastId),")
                                }
                            }
                            baseURL.removeLast()
                            print(baseURL)
                        }

                        // Request the podcast data from itunes
                        Alamofire.request(baseURL).responseObject { (response: DataResponse<ItunesPodcastLookUpResponse>) in
                            switch response.result {
                            case .success:
                                completionBlock(response)
                            case .failure:
                                print("Itunes lookup failed")
                            }
                        }
                    } else {
                         print("Podcast info already up to date!")
                    }
                }
//                completionBlock(response)
            } else {
                if let error = response.error {
                    errorHandler(error)
                }
            }
        }
    }

    // for all podcasts
    static func getEpisodeMetadata(){
        let realm = DBHelper.shared.getRealm()
        let podcasts = realm.objects(Podcast.self)
        for podcast in podcasts {
            // unmanaged copy
            let _podcast = Podcast(value: podcast)
            if _podcast._episodes.count == 0 {
                guard let feedUrlString = podcast.feedUrl,
                    let feedUrl = URL(string: feedUrlString) else {
                        print("GetEpisodes -- Invalid Url")
                        return
                }
                let parser = FeedParser(URL: feedUrl)
                print("Trying to fetch \(feedUrl)")
                parser.parseAsync(queue: DispatchQueue.global(qos: .userInitiated)) { (result) in
                    switch result {
                    case let .rss(feed):
                        guard result.isSuccess else {
                            print("GetEpisodes -- Could not parse feed URL from String")
                            return
                        }

                        guard let feedItems = feed.items else {
                            print("GetEpisodes -- Feed contains no items")
                            return
                        }

                        var episodes = [Episode]()
                        for feedItem in feedItems {
                            let episode = Episode()
                            episode.title = feedItem.title
                            episode.episodeDescription = feedItem.description
                            if let enclosure = feedItem.enclosure?.attributes {
                                episode.url = enclosure.url
                                episodes.append(episode)
                            }
                        }
                        autoreleasepool {
                            let realm = try! Realm(configuration: DBHelper.shared.defaultConfiguration)
                            _podcast._episodes.append(objectsIn: episodes)
                            // Write to Realm -- please work :)
                            try! realm.write {
                                realm.add(_podcast, update: .modified)
                                try! realm.commitWrite()
                            }
                        }
                    default:
                        break
                    }
                }
            }
        }
    }
}

enum RssFeedError: Error {
    case invalidURL
}

