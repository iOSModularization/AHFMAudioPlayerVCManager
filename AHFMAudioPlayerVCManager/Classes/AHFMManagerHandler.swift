//
//  AHFMAudioPlayerVCServices.swift
//  AHFMAudioPlayerVC
//
//  Created by Andy Tong on 9/29/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import AHFMDataTransformers
import AHFMNetworking
import AHFMDataCenter
import SwiftyJSON


public class AHFMManagerHandler: NSObject {
    
    public static let keyTrackId = "keyTrackId"
    
    var initialTrackId: Int?
    
    
    
    
    /// episodes for the this show, will be cached.
    lazy var episodes = [AHFMEpisode]()
    
    lazy var networking = AHFMNetworking()
    
    func audioPlayerVCListBarTapped(_ vc: UIViewController, trackId: Int, albumnId: Int){
        
    }
    func audioPlayerVCAlbumnCoverTapped(_ vc: UIViewController, atIndex index:Int, trackId: Int, albumnId: Int){
        
    }
    
    /// When the data is ready, call reload()
    func audioPlayerVCFetchInitialTrack(_ vc: UIViewController){
        guard let id = initialTrackId else {
            return
        }
        
        self.getEpisodeAndPerform(vc, trackId: id)
        
    }
    func audioPlayerVCFetchTrack(_ vc: UIViewController, trackId: Int){
        self.getEpisodeAndPerform(vc, trackId: trackId)
    }
    func audioPlayerVCFetchNextTrack(_ vc: UIViewController, trackId: Int, albumnId: Int){
        handleNextOrPrevious(vc, trackId: trackId, albumnId: albumnId, shouldGetNext: true)
    }
    func audioPlayerVCFetchPreviousTrack(_ vc: UIViewController, trackId: Int, albumnId: Int){
        handleNextOrPrevious(vc, trackId: trackId, albumnId: albumnId, shouldGetNext: false)
    }
    
    deinit {
        networking.cancelAllRequests()
    }
    
}

extension AHFMManagerHandler {
    func handleNextOrPrevious(_ vc: UIViewController,trackId: Int, albumnId:Int,shouldGetNext: Bool) {
        if self.episodes.count > 0, let preEp = getPrevious(trackId, self.episodes) {
            getEpisodeAndPerform(vc, trackId: preEp.id)
            return
        }
        
        
        let eps = AHFMEpisode.query("showId", "=", albumnId).OrderBy("createdAt", isASC: true).run()
        self.episodes.append(contentsOf: eps)
        if eps.count > 0, let preEp = getPrevious(trackId, self.episodes) {
            
            getEpisodeAndPerform(vc, trackId: preEp.id)
            
        }else{
            requestEpisodes(byShowID: albumnId, {[weak self] (epModels) in
                guard self != nil else {return}
                
                let shouldGetNext = shouldGetNext
                let trackId = trackId
                
                self?.episodes.append(contentsOf: epModels)
                
                AHFMEpisode.write {
                    guard self != nil else {return}
                    do {
                        try AHFMEpisode.insert(models: self!.episodes)
                    }catch _ {
                        
                    }
                    
                    DispatchQueue.main.async {
                        var ep: AHFMEpisode?
                        if shouldGetNext {
                            ep = self?.getNext(trackId, self!.episodes)
                        }else{
                            ep = self?.getPrevious(trackId, self!.episodes)
                        }
                        self?.getEpisodeAndPerform(vc, trackId: ep?.id ?? nil)
                    }
                    
                }
            })
        }
    }
    
    func requestEpisodes(byShowID: Int, _ completion: @escaping (_ episodeModels: [AHFMEpisode])->Void) {
        networking.episodes(byShowID: byShowID, { (data, _) in
            DispatchQueue.global().async {
                if let data = data, let jsonEpisodes = JSON(data).array {
                    let episodes = AHFMEpisodeTransform.transformJsonEpisodes(jsonEpisodes)
                    var episodeModels = [AHFMEpisode]()
                    for ep in episodes {
                        let model = AHFMEpisode(with: ep)
                        episodeModels.append(model)
                    }
                    DispatchQueue.main.async {
                        completion(episodeModels)
                    }
                    
                }
            }
        })
    }
    
    func getNext(_ currentEpisodeId: Int, _ eps: [AHFMEpisode]) -> AHFMEpisode? {
        let ep = eps.filter { (ep) -> Bool in
            return ep.id == currentEpisodeId
            }.first
        
        guard let currentEp = ep else {
            return nil
        }
        
        guard let index = eps.index(of: currentEp) else {
            return nil
        }
        
        guard index >= 0 && index < eps.count - 1 else {
            return nil
        }
        
        return eps[index + 1]
    }
    
    func getPrevious(_ currentEpisodeId: Int, _ eps: [AHFMEpisode]) -> AHFMEpisode? {
        let ep = eps.filter { (ep) -> Bool in
            return ep.id == currentEpisodeId
            }.first
        
        guard let currentEp = ep else {
            return nil
        }
        
        guard let index = eps.index(of: currentEp) else {
            return nil
        }
        
        guard index > 0 && index < eps.count else {
            return nil
        }
        
        return eps[index - 1]
    }
    
    func getEpisodeAndPerform(_ vc:UIViewController,trackId: Int?){
        guard let trackId = trackId else {
            vc.perform(Selector(("reload:")), with: nil)
            return
        }
        
        if let ep = AHFMEpisode.query(byPrimaryKey: trackId) {
            let epInfo = AHFMEpisodeInfo.query(byPrimaryKey: trackId)
            let dict = mergeInfo(ep: ep, epInfo: epInfo)
            vc.perform(Selector(("reload:")), with: dict)
        }else{
            networking.episode(byEpisodeId: trackId, { (data, _) in
                if let data = data {
                    let epJson = JSON(data)
                    if let epDict = AHFMEpisodeTransform.jsonToEpisode(epJson) {
                        let ep = AHFMEpisode(with: epDict)
                        AHFMEpisode.write {
                            if ep.save() {
                                DispatchQueue.main.async {
                                    // since there's no ep before saving it, there's no epInfo in the DB for sure.
                                    let dict = self.mergeInfo(ep: ep, epInfo: nil)
                                    vc.perform(Selector(("reload:")), with: dict)
                                    return
                                }
                            }
                        }
                        
                    }
                }
                vc.perform(Selector(("reload:")), with: nil)
                
            })
        }
    }
    func mergeInfo(ep: AHFMEpisode, epInfo: AHFMEpisodeInfo?) -> [String: Any] {
        var dict = [String: Any]()
        
        dict["albumnId"] = ep.showId
        dict["trackId"] = ep.id
        dict["audioURL"] = ep.audioURL
        dict["fullCover"] = ep.showFullCover
        dict["thumbCover"] = ep.showThumbCover
        dict["albumnTitle"] = ep.showTitle
        dict["trackTitle"] = ep.title
        dict["duration"] = ep.duration
        
        if let epInfo = epInfo {
            dict["lastPlayedTime"] = epInfo.lastPlayedTime
        }
        return dict
    }
}
