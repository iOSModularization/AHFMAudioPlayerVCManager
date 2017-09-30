
//
//  ServiceManager.swift
//  Pods
//
//  Created by Andy Tong on 9/28/17.
//
//

import Foundation
import AHFMAudioPlayerVCServices

import AHFMModuleManager
import AHServiceRouter


//public var albumnId: Int
//public var trackId: Int
//public var audioURL: String
//public var fullCover: String?
//public var thumbCover: String?
//
//public var albumnTitle: String?
//public var trackTitle: String?
//public var duration: TimeInterval?
//
//public var lastPlayedTime: TimeInterval?


public struct AHFMAudioPlayerVCManager: AHFMModuleManager {
    
    public static func activate() {
        AHServiceRouter.registerVC(AHFMAudioPlayerVCServices.service, taskName: AHFMAudioPlayerVCServices.taskNavigation) { (userInfo) -> UIViewController? in
            guard let trackId = userInfo[AHFMAudioPlayerVCServices.keyTrackId] as? Int else {
                return nil
            }
            
            let objStr = "AHFMAudioPlayerVC.AHFMAudioPlayerVC"
            
            guard let objType = NSClassFromString(objStr) as? UIViewController.Type else {
                return nil
            }
            
            
            let vc = objType.init()
            let manager = AHFMManagerHandler()
            manager.initialTrackId = trackId
            vc.setValue(manager, forKey: "manager")
            
            return vc
        }
        
    }
    
    
}








