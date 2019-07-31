//
//  PodcastLocalDataSource.swift
//  PodFast
//
//  Created by Orestis on 27/07/2019.
//  Copyright © 2019 Orestis Papadopoulos. All rights reserved.
//
import Realm
import RealmSwift
import Promises

public struct PodcastRealmDataSource: LocalDataSource {

    private let realm: Realm

    public init(realm: Realm? = nil) {
        self.realm = realm ?? DBHelper.shared.getRealm()
    }

    // MARK: Data Source Conformance
    public var description = "realm_db_podcast"

    public func fetchAll() -> Promise<[Podcast]>{
        // potential realm fuck here
        return Promise<[Podcast]> { fulfill, reject in
            fulfill(self.realm.objects(Podcast.self).map { object in
                return object
            })
        }
    }

    public func lastUpdated() -> Promise<Date> {
        return Promise<Date> (self.get(lastUpdatedDatasourceDate: self))
    }

    // MARK: Local Data Source Conformance
    public typealias DataType = Podcast

    public func update<D>(fromSource dataSource: D) -> Promise<Bool> where D : DataSource, D.DataType == Podcast {
        return Promise<Bool> { fulfill, reject in
            self.isUpToDate(with: AnyDataSource<Podcast>(base: dataSource)).then { dbIsUpToDateWithDataSource in
                if !dbIsUpToDateWithDataSource {
                    dataSource.fetchAll().then { podcasts in
                        do {
                            self.realm.beginWrite()
                            self.realm.add(podcasts, update: Realm.UpdatePolicy.modified)
                            try self.realm.commitWrite()
                            try self.update(lastUpdatedDatasource: dataSource, to: Date())
                            fulfill(true)
                        } catch let error as NSError {
                            reject(error)
                        }
                    }
                } else {
                    fulfill(false)
                }
            }
        }
    }

    // MARK: Private Methods
    private func update<D>(lastUpdatedDatasource dataSource: D, to date: Date) throws where D: DataSource {
        let updatedStats = DataSetUpdated()
        updatedStats.dataSource = dataSource.description
        updatedStats.date = date
        realm.beginWrite()
        realm.add(updatedStats, update: .modified)
        try realm.commitWrite()
    }

    private func isUpToDate(with dataSource: AnyDataSource<Podcast>) -> Promise<Bool> {
        return Promise<Bool> { fulfill, reject in
            let savedDataSourceUpdatedDate = self.get(lastUpdatedDatasourceDate: dataSource)
            dataSource.lastUpdated().then { dataSourceUpdatedDate in
                fulfill(savedDataSourceUpdatedDate >= dataSourceUpdatedDate)
            }
        }
    }

    private func get<D>(lastUpdatedDatasourceDate dataSource: D) -> Date where D: DataSource {
        if let stats = self.realm.objects(DataSetUpdated.self).filter("dataSource == %@ ", dataSource.description).first,
            let lastUpdate = stats.date {
            return lastUpdate
        } else {
            return Date(timeIntervalSince1970: 0)
        }
    }

}