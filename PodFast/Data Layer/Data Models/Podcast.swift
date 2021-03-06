//
//  Podcast.swift
//  PodFast
//
//  Created by Orestis on 13/07/2019.
//  Copyright © 2019 Orestis Papadopoulos. All rights reserved.
//

import Foundation
import RealmSwift
import AlamofireObjectMapper
import ObjectMapper
import Promises

public class Podcast: Object {
    @objc dynamic var feedUrl: String?
    @objc dynamic var itunesUrl: String?
    @objc dynamic var title: String?
    @objc dynamic var podcastDescription: String?
    @objc dynamic var hasBeenDiscovered: Bool = false
    public let _episodes = List<Episode>()
    public let categories = List<PodcastCategory>()
    public var episodes = Promise<[Episode]>([Episode]())
    public override static func primaryKey() -> String? {
        return "title"
    }
}
