//
//  PodcastRemoteDataSource.swift
//  PodFast
//
//  Created by Orestis on 27/07/2019.
//  Copyright © 2019 Orestis Papadopoulos. All rights reserved.
//
import Promises

public struct PodcastRemoteDataSource: PodcastDataSource {

    public init() {}

    public func update(fromPodcasts podcasts: [Podcast]) -> Promise<Bool> {
        return Promise<Bool> { fulfill, reject in
            // Called asynchronously on the default queue.
            fulfill(true)
        }
    }

    public func fetchPodcasts() -> Promise<[Podcast]> {
        return Promise<[Podcast]> { fulfill, reject in
            // Get Podcast Top 100
            AppleTopPodcastsRequest().execute().then { topPodcastsResponse in
                guard let podcasts = topPodcastsResponse.podcasts else {
                    reject(APIRequestError.noValueInResponse)
                    return
                }
                let podcastIds = podcasts.compactMap { $0.id }
                // Find Podcasts on Itunes (in order to retrieve feedurl etc.)
                ApplePodcastLookupRequest(podcastIds).execute().then { itunesPodcastsResponse in
                    // Get their episodes
                    guard let podcasts = itunesPodcastsResponse.podcasts else {
                        reject(APIRequestError.noValueInResponse)
                        return
                    }

                    // any is similar to all, but it fulfills even if some of the promises in the provided array are rejected.
                    // If all promises in the input array are rejected, the returned promise rejects
                    // the same error as the last one that was rejected.
                    any(podcasts.map { PodcastFeedEpisodesRequest($0.toPodcastObject(), for: 1).execute() })
                        .then { podcastsOrErrors in
                            fulfill(podcastsOrErrors.compactMap{$0.value})
                        }.catch { error in
                            // all were rejected
                            print(error)
                    }
                }
                }.catch { error in
                    print(error)
            }
        }
    }

    public var lastUpdated: Promise<Date> {
        get{
            return Promise<Date> { fulfill, reject in
                AppleTopPodcastsRequest().execute().then { (topPodcastsResponse: AppleTopPodcastsResponse) in
                    guard let updated = topPodcastsResponse.updated else {
                        reject(APIRequestError.noValueInResponse)
                        return
                    }
                    fulfill(updated)
                }
            }
        }
    }

}