// Copyright 2019 The TensorFlow Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import AVFoundation
import UIKit

protocol MirrorTestDelegate: AnyObject {
    func imageCaptureSuccesfully(image: UIImage?, attemptTakenTime: String?)
}

class ViewController: UIViewController {
    
    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var leftText: UILabel!
    @IBOutlet weak var rightText: UILabel!
    
    @IBOutlet weak var firstIMEI: H1BoldLabel!
    @IBOutlet weak var secondIMEI: H1BoldLabel!
    @IBOutlet weak var hashCode: H2BoldLabel!
    @IBOutlet weak var errorLabel: H1BoldLabel!
    
    // MARK: Instance Variables
    // Holds the results at any time
    private var previousInferenceTimeMs: TimeInterval = Date.distantPast.timeIntervalSince1970 * 1000
    
    // MARK: Controllers that manage functionality
    // Handles all the camera related functionality
    private lazy var cameraCapture = CameraFeedManager(previewView: previewView, isFrontCamera: isFrontCamera)
    
    var isFrontCamera: Bool = false
    
    private var maxMemoryUsage: UInt64 = 0
    private var maxCPUUsage: Double = 0
    
    private var mirrorTestOD_OCR_queue: OperationQueue?
    private var mirrorTestIC_queue: OperationQueue?
    private let oaLogger = OALogger(initiatedFor: .MirrorTest)
    private var performanceView: PerformanceMonitor?
    private var changeHashCodeTimer: Timer?
    private var eraseErrorTimer: Timer?
    private let lock = NSLock()
    private(set) var serverKey: Int64? = 1234
    private var lastIMEIandKeyAddition: Int64 = 0
    private var hashKeyMaxLength: Int8 = 19
    private var start = CFAbsoluteTimeGetCurrent()
    private var currentProcessedFramesForError = 0
    weak var delegate: MirrorTestDelegate?
    var isSupportMultiThreading = true
    var delayOfShowingMessages: Double = 0
    let queue = DispatchQueue(label: "com.oneassist")
    let stackForICqueueOperations = Stack<MirrorTest_IC_Far_Operation>()
    let maxConcurrentForIC_Queue = 1
    var currentRunningICOperationsInQueue = 0
    var isLockAquired = false
    var isImageCaptured = false
    var errorMessage: String? = nil {
        willSet {
            if !(newValue?.isEmpty ?? true) {
                resetEverythingToShowError()
                DispatchQueue.main.async { [weak self] in
                    self?.callEraseErrorMessageTimer()
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.errorLabel.text = newValue
            }
        }
    }
    
    // MARK: View Handling Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        leftText.transform = CGAffineTransform(scaleX: -1, y: 1);
        rightText.transform = CGAffineTransform(scaleX: -1, y: 1);
        firstIMEI.transform = CGAffineTransform(scaleX: -1, y: 1);
        secondIMEI.transform = CGAffineTransform(scaleX: -1, y: 1);
        hashCode.transform = CGAffineTransform(scaleX: -1, y: 1);
        errorLabel.transform = CGAffineTransform(scaleX: -1, y: 1);
        
        leftText.text = MirrorTestConstantParameters.shared.LeftLabelText
        rightText.text = MirrorTestConstantParameters.shared.RightLabelText
        firstIMEI.text = MirrorTestConstantParameters.shared.primaryIMEI
        secondIMEI.text = MirrorTestConstantParameters.shared.secondaryIMEI
        lastIMEIandKeyAddition = Int64(firstIMEI.text ?? "0") ?? 0
        
        mirrorTestOD_OCR_queue = OperationQueue()
        mirrorTestOD_OCR_queue?.qualityOfService = .userInitiated
        mirrorTestOD_OCR_queue?.name = "MirrorTestOD_OCRQueue"
        
        mirrorTestIC_queue = OperationQueue()
        //        mirrorTestIC_queue?.maxConcurrentOperationCount = 1
        mirrorTestIC_queue?.qualityOfService = .userInitiated
        mirrorTestIC_queue?.name = "MirrorTest_IC_Queue"
        
        self.performanceView = PerformanceMonitor()
        self.performanceView?.delegate = self
        self.performanceView?.start()
        self.performanceView?.hide()
        
        #if targetEnvironment(simulator)
        previewView.shouldUseClipboardImage = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(classifyPasteboardImage),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
        #endif
        cameraCapture.delegate = self
        addObserver()
        changeHashCodeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] timer in
            if let string = self?.getDisplayableHashKey(with: nil) {
                self?.hashCode.text = string
            }
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        #if !targetEnvironment(simulator)
        cameraCapture.checkCameraConfigurationAndStartSession()
        #endif
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    #if !targetEnvironment(simulator)
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraCapture.stopSession()
        UIApplication.shared.isIdleTimerDisabled = false
    }
    #endif
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    @IBAction func onClickBackAction(_ sende: UIButton?){
        self.dismiss(animated: true, completion: nil)
    }
    
    func presentUnableToResumeSessionAlert() {
        let alert = UIAlertController(
            title: "Unable to Resume Session",
            message: "There was an error while attempting to resume session.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        self.present(alert, animated: true)
    }
    
    // MARK: Storyboard Segue Handlers
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
    }
    
    @objc func classifyPasteboardImage() {
        guard let image = UIPasteboard.general.images?.first else {
            return
        }
        
        guard let buffer = CVImageBuffer.buffer(from: image) else {
            return
        }
        
        previewView.image = image
        
        DispatchQueue.global().async {
            self.didOutput(pixelBuffer: buffer)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        oaLogger.closeLogginSession()
        resetEverythingToShowError()
        changeHashCodeTimer?.invalidate()
        changeHashCodeTimer = nil
        stackForICqueueOperations.removeAll()
        print("deinitializing view controller")
    }
    
}

// MARK: CameraFeedManagerDelegate Methods
extension ViewController: CameraFeedManagerDelegate {
    
    func didOutput(pixelBuffer: CVPixelBuffer) {
        self.runModel(onPixelBuffer: pixelBuffer)
    }
    
    
    /** This method runs the live camera pixelBuffer through tensorFlow to get the result.
     */
    @objc  func runModel(onPixelBuffer pixelBuffer: CVPixelBuffer) {
        // Run the live camera pixelBuffer through tensorFlow to get the result
        
        let currentTimeMs = Date().timeIntervalSince1970 * 1000
        
        guard (errorMessage?.isEmpty ?? true) else {
            return
        }
        
        previousInferenceTimeMs = currentTimeMs
        
        let newOperation = MirrorTestOD_OCR_Operation(pixelBuffer: pixelBuffer, logger: oaLogger)
        newOperation.name = UUID().uuidString
        newOperation.completionBlock = { [weak newOperation, weak self] in
            guard let newOperation = newOperation,
                  !newOperation.isCancelled,
                  let image = newOperation.originalImage
            else { return }
            
            if newOperation.isIMEIMatched {
                self?.onImageCaptureSuccess(image: image, fromOperation: newOperation)
            } else {
                if newOperation.isObjectDetected, let objectRect = newOperation.detectedObjectRect {
                    self?.handOverFrameForClassification(pixelBuffer: pixelBuffer, originalImage: image, detectedObjectRect: objectRect, imeiError: newOperation.operationError)
                } else {
                    print("showing error from q1")
                    self?.showError(message: newOperation.operationError)
                }
            }
        }
        mirrorTestOD_OCR_queue?.addOperation(newOperation)
    }
    
    // MARK: Session Handling Alerts
    func sessionWasInterrupted(canResumeManually resumeManually: Bool) {
        
        // Updates the UI when session is interupted.
        oaLogger.log(errorString: "Camera Interrupted")
        exit(0)
    }
    
    func sessionInterruptionEnded() {
        // Updates UI once session interruption has ended.
        oaLogger.log(errorString: "Camera Interruption ended")
    }
    
    func sessionRunTimeErrorOccured() {
        // Handles session run time error by updating the UI and providing a button if session can be manually resumed.
        oaLogger.log(errorString: "Camera Runtime Interrupted")
        previewView.shouldUseClipboardImage = true
        exit(0)
    }
    
    func presentCameraPermissionsDeniedAlert() {
        let alertController = UIAlertController(title: "Camera Permissions Denied", message: "Camera permissions have been denied for this app. You can change this by going to Settings", preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let settingsAction = UIAlertAction(title: "Settings", style: .default) { (action) in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
        }
        alertController.addAction(cancelAction)
        alertController.addAction(settingsAction)
        
        present(alertController, animated: true, completion: nil)
        
        previewView.shouldUseClipboardImage = true
    }
    
    func presentVideoConfigurationErrorAlert() {
        let alert = UIAlertController(title: "Camera Configuration Failed", message: "There was an error while configuring camera.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        self.present(alert, animated: true)
        previewView.shouldUseClipboardImage = true
    }
}


extension ViewController {
    
    fileprivate func callEraseErrorMessageTimer() {
        eraseErrorTimer = nil
        eraseErrorTimer = Timer.scheduledTimer(withTimeInterval: Double(round(100 * delayOfShowingMessages)/100), repeats: false, block: { timer in
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = nil
                self?.startProcessAgain()
            }
        })
    }
    
    fileprivate func addOperationToICQueue(_ classificationOperation: MirrorTest_IC_Far_Operation) {
        guard !self.isLockAquired else {
            print("frame drop 1")
            return
        }
        print("--- starting to lock 1")
        lock.lock()
        isLockAquired = true
        print("going to lock 1")
            if (self.currentRunningICOperationsInQueue ) > (self.maxConcurrentForIC_Queue) {
                self.stackForICqueueOperations.push(classificationOperation)
                print(":: directly added to IC Operations Stack count after adding \(self.stackForICqueueOperations.count)")
            } else {
                print(":: directly added to IC Queue")
                self.currentRunningICOperationsInQueue += 1
                self.mirrorTestIC_queue?.addOperation(classificationOperation)
            }
        print("going to unlock 1")
        isLockAquired = false
        lock.unlock()
    }
    
    fileprivate func handOverFrameForClassification(pixelBuffer: CVPixelBuffer, originalImage: UIImage, detectedObjectRect: CGRect, imeiError: String?) {
        
        let classificationOperation = MirrorTest_IC_Far_Operation(pixelBuffer: pixelBuffer, logger: oaLogger, originalImage: originalImage, detectedObjectRect: detectedObjectRect, imeiError: imeiError)
        classificationOperation.name = UUID().uuidString
        classificationOperation.completionBlock = { [weak classificationOperation, weak self] in
            print("**** under operation completion")
            guard let operation = classificationOperation,!operation.isCancelled else {
                return
            }
            // will improve imeieRROR vairables and opeationError with model as suggested ankur sir
            if let error = operation.operationError, !(error.isEmpty) {
                print("showing error from q2")
                self?.showError(message: error)
            } else if let error = operation.imeiError, !(error.isEmpty) {
                print("showing error from q2")
                self?.showError(message: error)
            } else if let image = operation.originalImage {
                self?.onImageCaptureSuccess(image: image, fromOperation: operation)
            }
        }
        addOperationToICQueue(classificationOperation)
    }
    
    fileprivate func showError(message: String?) {
        guard !self.isLockAquired else {
            print("frame drop 2")
            return
        }
        print("--- starting to lock 2")
        lock.lock()
        isLockAquired = true
        print("going to lock 2")
        if (self.currentProcessedFramesForError) >= MirrorTestConstantParameters.shared.errorMessageAfterProcessFrames,
           (self.errorMessage?.isEmpty ?? true)
           , !(message?.isEmpty ?? true) {
            self.errorMessage = message
            print(":: removed stack data for message isEmpty \(self.stackForICqueueOperations.isEmpty)")
        } else {
            self.currentProcessedFramesForError += 1
            if !(self.stackForICqueueOperations.isEmpty),
               let operation = self.stackForICqueueOperations.pop() {
                print(":: added from stack to IC Queue")
                self.currentRunningICOperationsInQueue += 1
                self.mirrorTestIC_queue?.addOperation(operation)
            } else {
                print(":: error popping empty is \(!(self.stackForICqueueOperations.isEmpty)) \(self.stackForICqueueOperations.peek())")
            }
        }
        print("going to unlock 2")
        isLockAquired = false
        lock.unlock()
    }
    
    fileprivate func onImageCaptureSuccess(image: UIImage, fromOperation: Operation) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isLockAquired else {
                print("frame drop 3")
                return
            }
            print("--- starting to lock 3")
            self.lock.lock()
            self.isLockAquired = true
            print("going to lock 3")
            if self.isImageCaptured {
                self.lock.unlock()
                return
            }
            self.mirrorTestIC_queue?.cancelAllOperations()
            self.mirrorTestOD_OCR_queue?.cancelAllOperations()
            let diff = CFAbsoluteTimeGetCurrent() - (self.start)
            ImageSaver().writeToPhotoAlbum(image: image)
            self.delegate?.imageCaptureSuccesfully(image: image, attemptTakenTime: "Whole Process Took  \(diff.rounded()) seconds Max Memory Usage:: \(self.formattedMemory(memory: self.maxMemoryUsage)) CPU Usage:: \(round(self.maxCPUUsage))%")
            self.resetEverythingToShowError()
            print("-- Whole Process Took  \(diff) seconds \n Max Memory Usage:: \(self.formattedMemory(memory: self.maxMemoryUsage)) CPU Usage:: \(round(self.maxCPUUsage))%")
            
            self.oaLogger.log(errorString: "-- Whole Process Took  \(diff) seconds \n Max Memory Usage:: \(self.formattedMemory(memory: self.maxMemoryUsage)) CPU Usage:: \(round(self.maxCPUUsage))%")
            print("going to unlock 3")
            self.isImageCaptured = true
            self.isLockAquired = false
            self.lock.unlock()
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    fileprivate func getDisplayableHashKey(with hashKey: String?) -> String? {
        if let imei = Int64(firstIMEI.text ?? "0") {
            if let hashKey = hashKey { // if new hash key came reset and generate hash key to show
                lastIMEIandKeyAddition = imei
                serverKey = Int64(hashKey)
            }
            if let key = serverKey {
                lastIMEIandKeyAddition += key
                let octalString = String(lastIMEIandKeyAddition,radix: 8) // get octal representation
                // add padding
                let stringToShow = octalString.count < hashKeyMaxLength ? octalString.leftPadding(toLength: Int(hashKeyMaxLength), withPad: "0") : octalString
                return stringToShow
            }
        }
        return nil
    }
    
    fileprivate func startProcessAgain() {
        self.cameraCapture.checkCameraConfigurationAndStartSession()
        self.performanceView?.start()
    }
    
    fileprivate func resetEverythingToShowError() {
        self.cameraCapture.stopSession()
        self.mirrorTestIC_queue?.cancelAllOperations()
        self.stackForICqueueOperations.removeAll()
        self.performanceView?.pause()
        currentProcessedFramesForError = 0
        currentRunningICOperationsInQueue = 0
    }
}

extension ViewController: PerformanceMonitorDelegate {
    fileprivate func formattedMemory(memory: UInt64) -> String {
        let bytesInMegabyte = 1024.0 * 1024.0
        let usedMemory = Double(memory) / bytesInMegabyte
        let memory = String(format: "%.1f MB used", usedMemory)
        return memory
    }
    
    func performanceMonitor(didReport performanceReport: PerformanceReport) {
        maxMemoryUsage = max(maxMemoryUsage, performanceReport.memoryUsage.used)
        maxCPUUsage = max(maxCPUUsage, performanceReport.cpuUsage)
    }
}

// MARK: - Brightness Setup
extension ViewController {
    fileprivate func addObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    fileprivate func removeObserver() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func appDidBecomeActive() {
        setUpNewBrightnessValue()
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    @objc func applicationWillResignActive() {
        setUpPreviousBrightnessValue()
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    func setUpNewBrightnessValue() {
        let preValue = UIScreen.main.brightness
        UserDefaults.standard.set(preValue, forKey: "previousBrightnessValue")
        UIScreen.main.brightness = CGFloat(0.8)
    }
    
    func setUpPreviousBrightnessValue() {
        if let preValue = UserDefaults.standard.value(forKey: "previousBrightnessValue") as? Float {
            UIScreen.main.brightness = CGFloat(preValue)
        }
    }
}

class ImageSaver: NSObject {
    
    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveError), nil)
    }
    
    @objc func saveError(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        print("Save finished!")
    }
}

