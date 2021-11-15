//
//  TFLiteModelsDownloadManager.swift
//  ImageClassification
//
//  Created by Chandra Bhushan on 06/05/21.
//  Copyright © 2021 Y Media Labs. All rights reserved.
//

import UIKit
import ReachabilityManager

protocol TFLiteModelsDownloadManagerDelegate {
    func onError()
}

enum TFLiteModelsDownloadError {
    case ModelsLoadingError
    case DownloadTaskError
    case InternetAvialability
}

class TFLiteModelsDownloadManager {
    
    weak var progressView: UIProgressView?
    weak var estimatedTimeLabel: UILabel?
    
    lazy var sharedInstance: TFLiteModelsDownloadManager = TFLiteModelsDownloadManager()
    var delegate: TFLiteModelsDownloadManagerDelegate?
    
    private let models = [objectDetectionModel,objectDetectionLabels,imageClassificationModel,imageClassificationLabels]
    private lazy var downloadManager: JHDownloadManager = JHDownloadManager.sharedInstance
    private var downloadRemainingTimeTimer: Timer?
    private var internetGoneRetryErrorTimer: Timer? // When internet is gone and user presses retry on error screen after specific amount of time if internet not appeared show error screen again
    private var isInternetGone: Bool = false
    private var objectDetectionHandler: ModelDataHandler? = nil
    private var imageClassificationHandler: ModelDataHandler? = nil
    
    private init() {
        downloadManager.uiDelegate = self
        downloadManager.requestTimeoutSeconds = 30
        downloadManager.onConnectionLost = { [weak self] in
            self?.isInternetGone = true
            // TODO:- SHOW ERROR VIEW
        }
        
        downloadManager.onConnectionAppear = { [weak self] in
            self?.isInternetGone = false
            self?.internetGoneRetryErrorTimer?.invalidate()
            // TODO:- HIDE ERROR VIEW
        }
    }
    
    
    @objc private func updateRemainingTime() {
        if let downloadRateAndRemaining = JHDownloadManager.sharedInstance.downloadRateAndRemainingTime(){
            let downloadRate:String = downloadRateAndRemaining[0];
            let remainingTime:String = downloadRateAndRemaining[1];
            self.estimatedTimeLabel?.text = String(format: "Time Left: %@", downloadRate, remainingTime)
        }
    }
    
    private func runDownloadRemainingTimeTimer() {
        // Timer is fruitfull only when we need to show remaining time on label and label instance is set
        if let _ = estimatedTimeLabel {
            downloadRemainingTimeTimer?.invalidate()
            downloadRemainingTimeTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updateRemainingTime), userInfo: nil, repeats: true)
        }
    }
    
    // When internet is gone and user presses retry on error screen after specific amount of time if internet not appeared show error screen again
    private func runInternetGoneTimer() {
        internetGoneRetryErrorTimer?.invalidate()
        internetGoneRetryErrorTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false, block: { (timer) in
            if self.isInternetGone {
                //TODO:- SHOW ERROR SCREEN
            }
        })
    }
    
    func startModelDownloading() {
        self.progressView?.progress = 0
        self.estimatedTimeLabel?.text = "Time Left: "
        downloadRemainingTimeTimer?.invalidate()
        internetGoneRetryErrorTimer?.invalidate()
        // TODO:- Need to move url on firebase
        downloadManager.downloadBatch(downloadInformation: [["url":"https://sit10.1atesting.in/static/oaapp/TfliteModels/Models.zip","destination":"TFModels/Models.zip"]])
        runDownloadRemainingTimeTimer()
    }
    
    func isModelsDownloaded() -> Bool {
        var isDownloaded = true
        for fileLocation in models {
            if !FileManager.default.fileExists(atPath: fileLocation) {
                isDownloaded = false
                break
            }
        }
        return isDownloaded
    }
    
    func removeDownloadedModels() -> Bool {
        let fileManager = FileManager.default
        var isRemoved = true
        
        for fileLocation in models {
            if fileManager.fileExists(atPath: fileLocation) {
                do {
                    try fileManager.removeItem(atPath: fileLocation)
                } catch {
                    print("Something went wrong when removing the file at \(fileLocation)")
                    isRemoved = false
                    break
                }
            }
        }
        return isRemoved
    }
    
    func checkModelsCouldLoad() -> TFLiteModelsDownloadError? {
        objectDetectionHandler = ModelDataHandler(modelFileInfo: MobileNetSSD.modelInfo, labelsFileInfo: MobileNetSSD.labelsInfo, inputWidth: 300, inputHeight: 300)
        imageClassificationHandler = ModelDataHandler(modelFileInfo: MobileNet.modelInfo, labelsFileInfo: MobileNet.labelsInfo, inputWidth: 800, inputHeight: 800)
        guard imageClassificationHandler != nil,
              objectDetectionHandler != nil else {
              fatalError("Model set up failed")
            //TODO: ERROR HANDLING
        }
        objectDetectionHandler = nil
        imageClassificationHandler = nil
        return nil
    }
}


extension TFLiteModelsDownloadManager: JHDownloadManagerUIDelegate {
    
    func didReachProgress(progress:Float) {
        self.progressView?.progress = progress
    }
    
    func didFinishAll() {
        self.progressView?.progress = 1
        self.estimatedTimeLabel?.text = ""
        downloadRemainingTimeTimer?.invalidate()
        internetGoneRetryErrorTimer?.invalidate()
    }
    
    func didHitDownloadErrorOnTask(task: JHDownloadTask) {
        downloadManager.cancelAllOutStandingTasks()
        downloadRemainingTimeTimer?.invalidate()
        internetGoneRetryErrorTimer?.invalidate()
        delegate?.onError()
        //TODO:- SHOW ERROR HANDLING VIEW
    }
    
    func didStartDownloading() {
        runDownloadRemainingTimeTimer()
    }
    
    func didFinishBackgroundDownloading() {
        // TODO: FIRE LOCAL NOTIFICATION & REMOVE NOTIFICATION CODE FROM JHDOWNLOAD MANAGER
        let content = UNMutableNotificationContent()
        content.title = "Activation setup complete"
        content.subtitle = "Tap to start activation"
        content.sound = UNNotificationSound.default
        // show this notification zero seconds from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0, repeats: false)
        // choose a random identifier
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        // add our notification request
        UNUserNotificationCenter.current().add(request)
    }
}


// TODO:- DELEGATE HANDLING FOR DOWNLOAD ERROR SCREEN & START SDT SCREEN
extension TFLiteModelsDownloadManager {
    
    func onRetry() {
        if isInternetGone { // if internet is not available
            runInternetGoneTimer()
        } else {
            startModelDownloading()
        }
    }
    
    func onStartSDTFlow() {
        
    }
}


