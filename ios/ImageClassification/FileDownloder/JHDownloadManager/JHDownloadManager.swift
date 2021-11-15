//
//  JHDownloadManager.swift
//  Pods
//
//  Created by James Huynh on 21/2/16.
//
//

import UIKit
import Reachability
import ReachabilityManager
import UserNotifications

public protocol JHDownloadManagerDataDelegate: class {
    // required protocol functions
    func didFinishAllForDataDelegate()
    
    // optional protocol functions
    func didFinishDownloadTask(downloadTask:JHDownloadTask)
}

public protocol JHDownloadManagerUIDelegate: class {
    // required protocol functions
    func didFinishAll()
    
    // optional protocol functions
    func didReachProgress(progress:Float)
    func didHitDownloadErrorOnTask(task: JHDownloadTask)
    func didFinishOnDownloadTaskUI(task: JHDownloadTask)
    func didReachIndividualProgress(progress: Float, onDownloadTask:JHDownloadTask)
    func didFinishBackgroundDownloading()
    func didStartDownloading()
}

extension JHDownloadManagerDataDelegate {
    func didFinishDownloadTask(downloadTask:JHDownloadTask) {}
}

extension JHDownloadManagerUIDelegate {
    func didReachProgress(progress:Float) {}
    func didHitDownloadErrorOnTask(task: JHDownloadTask) {}
    func didFinishOnDownloadTaskUI(task: JHDownloadTask) {}
    func didReachIndividualProgress(progress: Float, onDownloadTask:JHDownloadTask) {}
    func didFinishBackgroundDownloading() {}
    func didStartDownloading() {}
}

public class JHDownloadManager: NSObject, URLSessionDownloadDelegate {
    private var downloadSession:URLSession?
    private var currentBatch:JHDownloadBatch?
    private var initialDownloadedBytes:Int64 = 0
    private var totalBytes:Int64 = 0
    private var internetReachability:Reachability?
    public var fileHashAlgorithm:FileHashAlgorithm = FileHashAlgorithm.SHA1
    public var onConnectionLost: (()->())? = nil
    public var onConnectionAppear: (()->())? = nil
    var requestTimeoutSeconds: Double = 90
    
    public static let sharedInstance = JHDownloadManager()
    static let session = Foundation.URLSession(configuration: URLSessionConfiguration.default, delegate: sharedInstance, delegateQueue: nil)
    
    public var dataDelegate:JHDownloadManagerDataDelegate?
    public var uiDelegate:JHDownloadManagerUIDelegate?
    
    private override init() {
        super.init()
        self.listenToInternetConnectionChange()
    }
    
    func setInitialDownloadBytes(initialDownloadedBytes:Int64) {
        self.initialDownloadedBytes = initialDownloadedBytes
    }
    
    func setTotalBytes(totalBytes:Int64) {
        self.totalBytes = totalBytes
    }
    
    class func getURLSessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration
            .background(withIdentifier: "com.oneassis.networking.\(Bundle.main.bundleURL.lastPathComponent.lowercased().replacingOccurrences(of: " ", with: "."))")
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        return config
    }
    
    func overallProgress() -> Float {
        if let unwrappedCurrentBatch = currentBatch {
            var actualTotalBytes:Int64 = 0
            let bytesInfo = unwrappedCurrentBatch.totalBytesWrittenAndReceived()
            if totalBytes == 0 {
                actualTotalBytes = bytesInfo["totalToBeReceivedBytes"]!
            } else {
                actualTotalBytes = totalBytes
            }//end else
            
            let actualDownloadedBytes = bytesInfo["totalDownloadedBytes"]! + initialDownloadedBytes
            if actualTotalBytes == 0 {
                return 0
            }//end if
            
            let progress = Float(actualDownloadedBytes) / Float(actualTotalBytes)
            return progress
        } else {
            return 0
        }//end else
    }
    
    public func isDownloading() -> Bool {
        if let unwrappedCurrentBatch = currentBatch {
            return unwrappedCurrentBatch.completed == false
        } else {
            return false
        }
    }
    
    public func addBatch(arrayOfDownloadInformation:[[String: Any]]) -> [JHDownloadTask] {
        let batch = JHDownloadBatch(fileHashAlgorithm: self.fileHashAlgorithm)
        batch.requestTimeoutSeconds = requestTimeoutSeconds
        for downloadTask in arrayOfDownloadInformation {
            batch.addTask(taskInfo: downloadTask)
        }
        self.currentBatch = batch
        return batch.downloadObjects()
    }
    
    public func downloadingTasks() -> [JHDownloadTask] {
        if let unwrappedCurrentBatch = self.currentBatch {
            return unwrappedCurrentBatch.downloadObjects()
        } else {
            return [JHDownloadTask]()
        }
    }
    
    public func downloadRateAndRemainingTime() -> [String]? {
        if let unwrappedCurrentBatch = currentBatch {
            let rate = unwrappedCurrentBatch.downloadRate()
            let bytesPerSeconds = String(format: "%@/s", ByteCountFormatter.string(fromByteCount: rate, countStyle: ByteCountFormatter.CountStyle.file))
            let remainingTime = self.remainingTimeGivenDownloadingRate(downloadRate: rate)
            return [bytesPerSeconds, remainingTime]
        } else {
            return nil
        }
    }
    
    func remainingTimeGivenDownloadingRate(downloadRate:Int64) -> String {
        if downloadRate == 0 {
            return "Unknown"
        }
        
        var actualTotalBytes:Int64 = 0
        if let currentBatchUnwrapped = currentBatch {
            let bytesInfo = currentBatchUnwrapped.totalBytesWrittenAndReceived()
            if totalBytes == 0 {
                actualTotalBytes = bytesInfo["totalToBeReceivedBytes"]!
            } else {
                actualTotalBytes = totalBytes
            }
            let actualDownloadedBytes = bytesInfo["totalDownloadedBytes"]! + initialDownloadedBytes
            let timeRemaining:Float = Float(actualTotalBytes - actualDownloadedBytes) / Float(downloadRate)
            return self.formatTimeFromSeconds(numberOfSeconds: Int64(timeRemaining))
        }
        
        return "Unknown"
    }
    
    func formatTimeFromSeconds(numberOfSeconds:Int64) -> String {
        let seconds = numberOfSeconds % 60
        let minutes = (numberOfSeconds / 60) % 60
        let hours = (numberOfSeconds / 3600)
        
        if hours > 0, minutes > 0, seconds > 0 {
            return String(NSString(format: "%02lld hours %02lld mins %02lld secs", hours, minutes, seconds))
        } else if minutes > 0, seconds > 0 {
            return String(NSString(format: "%02lld mins %02lld secs", minutes, seconds))
        }
        return String(NSString(format: "%02lld secs", seconds))
    }
    
    public func startDownloadingCurrentBatch() {
        if let currentBatchUnwrapped = currentBatch {
            self.startADownloadBatch(batch: currentBatchUnwrapped)
            uiDelegate?.didStartDownloading()
        }
    }
    
    func downloadBatch(downloadInformation:[[String: Any]]) {
        self.addBatch(arrayOfDownloadInformation: downloadInformation)
        self.startDownloadingCurrentBatch()
    }
    
    public func addDownloadTask(task:[String: Any]) -> JHDownloadTask? {
        if self.currentBatch == nil {
            currentBatch = JHDownloadBatch.init(fileHashAlgorithm: self.fileHashAlgorithm)
            currentBatch?.requestTimeoutSeconds = requestTimeoutSeconds
        }//end if
        
        if let downloadTaskInfo = self.currentBatch!.addTask(taskInfo: task) {
            if downloadTaskInfo.completed {
                self.processCompletedDownload(task: downloadTaskInfo)
                self.postToUIDelegateOnIndividualDownload(task: downloadTaskInfo)
            } else if(currentBatch!.isDownloading()) {
                currentBatch!.startDownloadTask(downloadTask: downloadTaskInfo)
            }
           
            currentBatch!.updateCompleteStatus()
            if let unwrappedUIDelegate = self.uiDelegate {
                DispatchQueue.main.async {
                    unwrappedUIDelegate.didReachProgress(progress: self.overallProgress())
                }
            }
            if currentBatch!.completed {
                self.postCompleteAll()
            }
            
            return downloadTaskInfo
        }
        
        return nil
    }
    
    func listenToInternetConnectionChange() {
        do {
            self.internetReachability = try Reachability.init()
        } catch {
            print("Unable to create Reachability")
            return
        }
       
        self.internetReachability?.whenReachable = { reachability in
            DispatchQueue.main.async {
                self.continueIncompletedDownloads()
                if let closure = self.onConnectionAppear {
                    closure()
                }
            }
        }
        
        self.internetReachability?.whenUnreachable = { reachability in
            DispatchQueue.main.async {
                self.suspendAllOngoingDownloads()
                if let closure = self.onConnectionLost {
                    closure()
                }
            }
        }
        
        do {
            try self.internetReachability?.startNotifier()
        } catch {
            print("Unable to satrt notifier")
        }
    }
    
    public func continueIncompletedDownloads() {
        if let unwrappedCurrentBatch = currentBatch {
            unwrappedCurrentBatch.resumeAllSuspendedTasks()
        }
    }
    
    public func suspendAllOngoingDownloads() {
        if let unwrappedCurrentBatch = currentBatch {
            unwrappedCurrentBatch.suspendAllOngoingDownloadTasks()
        }
    }
    
    func processCompletedDownload(task:JHDownloadTask) {
        if let dataDelegateUnwrapped = self.dataDelegate {
            dataDelegateUnwrapped.didFinishDownloadTask(downloadTask: task)
        }
        
        if let uiDelegateUnwrapped = self.uiDelegate {
            DispatchQueue.main.async {
                uiDelegateUnwrapped.didFinishOnDownloadTaskUI(task: task)
            }
        }
        
        if let currentBatchUnwrapped = currentBatch, currentBatchUnwrapped.completed {
            self.postCompleteAll()
        }
    }
    
    func postCompleteAll() {
        if let dataDelegateUnwrapped = self.dataDelegate {
            dataDelegateUnwrapped.didFinishAllForDataDelegate()
        }
        
        if let uiDelegateUnwrapped = self.uiDelegate {
            DispatchQueue.main.async {
                uiDelegateUnwrapped.didFinishAll()
            }
        }
    }
    
    // MARK: - NSURLSessionDelegate
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let unwrappedError = error {
            if let downloadURL = task.originalRequest?.url?.absoluteString, let unwrappedCurrentBatch = currentBatch {
                if let downloadTaskInfo = unwrappedCurrentBatch.downloadInfoOfTaskUrl(url: downloadURL) {
                    downloadTaskInfo.captureReceivedError(error: unwrappedError as NSError)
                    currentBatch?.redownloadRequestOfTask(task: downloadTaskInfo)
                    self.postDownloadErrorToUIDelegate(task: downloadTaskInfo)
                }
            }
        }
    }
    
    func cancelAllOutStandingTasks() {
        JHDownloadManager.session.invalidateAndCancel()
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        print("buytes writted \(bytesWritten) progress = \(Float(totalBytesWritten) / Float(totalBytesExpectedToWrite))")
        if let downloadURL = downloadTask.originalRequest?.url?.absoluteString, let currentBatchUnwrapped = currentBatch {
            let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            if let downloadTaskInfo = currentBatchUnwrapped.updateProgressOfDownloadURL(url: downloadURL, progressPercentage: progress, totalBytesWritten: totalBytesWritten) {
                self.postProgressToUIDelegate()
                self.postToUIDelegateOnIndividualDownload(task: downloadTaskInfo)
            }
        }
    }
   
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        // do nothing for now
    }
    
    
    func startADownloadBatch(batch:JHDownloadBatch) {
        let session = JHDownloadManager.session
        batch.setDownloadingSession(inputSession: session)
        session.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) -> Void in
            for task in batch.downloadObjects() {
                var isDownloading = false
                let url = task.getURL()
                for downloadTask in downloadTasks {
                    if url.absoluteString == downloadTask.originalRequest?.url?.absoluteString {
                        if let downloadTaskInfo = batch.captureDownloadingInfoOfDownloadTask(downloadTask: downloadTask) {
                            self.postToUIDelegateOnIndividualDownload(task: downloadTaskInfo)
                            isDownloading = true
                            if downloadTask.state == URLSessionTask.State.suspended {
                                downloadTask.resume()
                            }//end if
                        }
                    }
                }//end for
             
                if task.completed == true {
                    self.processCompletedDownload(task: task)
                    self.postToUIDelegateOnIndividualDownload(task: task)
                } else if isDownloading == false {
                    batch.startDownloadTask(downloadTask: task)
                }
            }//end for
            
            batch.updateCompleteStatus()
            if let uiDelegateUnwrapped = self.uiDelegate {
                DispatchQueue.main.async {
                    uiDelegateUnwrapped.didReachProgress(progress: self.overallProgress())
                }
            }
            if batch.completed {
                self.postCompleteAll()
            }
        }
    }
   
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("didfinish called with url \(location)")
        if let downloadURL = downloadTask.originalRequest?.url?.absoluteString, let currentBatchUnwrapped = self.currentBatch {
            if let downloadTask = currentBatchUnwrapped.downloadInfoOfTaskUrl(url: downloadURL) {
                let finalResult = currentBatchUnwrapped.handleDownloadFileAt(downloadFileLocation: location, forDownloadURL: downloadURL)
                if finalResult {
                    self.processCompletedDownload(task: downloadTask)
                } else {
                    downloadTask.cleanUp()
                    currentBatchUnwrapped.startDownloadTask(downloadTask: downloadTask)
                    self.postProgressToUIDelegate()
                }
            } else {
                // ignore - not my task
            }
        }

    }
    
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                  let backgroundCompletionHandler =
                    appDelegate.backgroundCompletionHandler else {
                return
            }
            backgroundCompletionHandler()
            self.uiDelegate?.didFinishBackgroundDownloading()
        }
    }
    
    func postProgressToUIDelegate() {
        if let uiDelegateUnwrapped = self.uiDelegate {
            DispatchQueue.main.async {
                let overallProgress = self.overallProgress()
                uiDelegateUnwrapped.didReachProgress(progress: overallProgress)
            }
        }
    }
    
    func postToUIDelegateOnIndividualDownload(task:JHDownloadTask) {
        if let uiDelegateUnwrapped = self.uiDelegate {
            DispatchQueue.main.async {
                task.cachedProgress = task.downloadingProgress()
                uiDelegateUnwrapped.didReachIndividualProgress(progress: task.cachedProgress, onDownloadTask: task)
            }
        }
    }
    
    func postDownloadErrorToUIDelegate(task:JHDownloadTask) {
        if let uiDelegateUnwrapped = self.uiDelegate {
            DispatchQueue.main.async {
                uiDelegateUnwrapped.didHitDownloadErrorOnTask(task: task)
            }
        }
    }
}
