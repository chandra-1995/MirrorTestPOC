//
//  OALogger.swift
//  OneAssist-Swift
//
//  Created by Chandra Bhushan on 04/06/21.
//  Copyright © 2021 OneAssist. All rights reserved.
//

import Foundation
import SSZipArchive

/*
 * File Structure For Logger
 |-OALogger_CUSTOMER_ID
 |--MirrorTest
 |---LogsSession_CurrentTimeInterval
 |---errors.txt
 |---a.jpg
 |----SecondaryImages
 |----b.jpg
 |
 */

enum OALoggerInitiatedFor: String {
    case MirrorTest = "MirrorTest"
    case PreMirrorTest = "PreMirrorTest"
}


class OALogger {
    
    // MARK: - Properties
    let documentDirectory = FileManager.documentsDir()
    var mainContainerFolderPath: String = ""
    var logsToWrite: String = ""
    var mirrorTestFBLogData = [String: Any]()
    static var customerID = ""
    static var fileManager: FileManager = FileManager.default
    static let logsTimeFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd_MMM_yyyy hh_mm_ss_SSSS"
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    } ()
    
    // MARK: - Object LifeCycle
    init(initiatedFor: OALoggerInitiatedFor) {
        #if DEBUG
        let currentDateTime = OALogger.logsTimeFormat.string(from: Date())
        mainContainerFolderPath = "\(documentDirectory)/OALogger_\(OALogger.customerID)/\(initiatedFor.rawValue)/LogsSession_\(currentDateTime)"
        if !createDirectoryIfRequired(forPath: mainContainerFolderPath) {
            print("Error Creating Session Logging Directory")
        }
        #endif
    }
    
    deinit {
        self.closeLogginSession()
    }
    
    // MARK: - Private Methods
    private func logImage(primaryImage: UIImage? = nil, primaryImageName: String?, secondaryImage: UIImage? = nil, secondaryImageName: String?, currentDateTime: String) {
        if let primaryImage = primaryImage {
            let fileURL = (mainContainerFolderPath )+"/\(currentDateTime)_\(primaryImageName).jpg"
            let data = primaryImage.jpegData(compressionQuality: 1.0)
            OALogger.fileManager.createFile(atPath: fileURL, contents: data, attributes: [:])
        }
        if let secondaryImage = secondaryImage {
            let secondaryImageDirectory = (mainContainerFolderPath )+"/SecondaryImages"
            if createDirectoryIfRequired(forPath: secondaryImageDirectory) {
                let fileURL = secondaryImageDirectory + "/\(currentDateTime)_\(secondaryImageName).jpg"
                let data = secondaryImage.jpegData(compressionQuality: 1.0)
                OALogger.fileManager.createFile(atPath: fileURL, contents: data, attributes: [:])
            } else {
                print("unable to create directory for secondary image")
            }
        }
    }
    
    private func createDirectoryIfRequired(forPath: String) -> Bool {
        if !OALogger.fileManager.fileExists(atPath: forPath) {
            do {
                try OALogger.fileManager.createDirectory(atPath: forPath, withIntermediateDirectories: true, attributes: nil)
                return true
            } catch let error as NSError {
                print("Create Directory Error: \(error.localizedDescription)")
            } catch {
                print("Create Directory Error - Something went wrong")
            }
        } else {
            return true
        }
        return false
    }
    
    // MARK: - Instance Methods
    func log(errorString: String?, primaryImage: UIImage? = nil, primaryImageName: String? = nil, secondaryImage: UIImage? = nil, secondaryImageName: String? = nil) {
        let currentDateTime = OALogger.logsTimeFormat.string(from: Date())
        if let error = errorString {
            logsToWrite.append("\n\n\(currentDateTime) "+error)
        }
        DispatchQueue.global(qos: .default).async { [weak self] in
            self?.logImage(primaryImage: primaryImage, primaryImageName: primaryImageName,secondaryImage: secondaryImage, secondaryImageName: secondaryImageName,currentDateTime: currentDateTime)
        }
    }
    
    func closeLogginSession() {
        let fileURL = (mainContainerFolderPath )+"/errors.txt"
        let logsToWrite = self.logsToWrite
        DispatchQueue.global(qos: .default).async {
            do {
                OALogger.removeZippedLogs()
                if !OALogger.fileManager.fileExists(atPath: fileURL) {
                    try logsToWrite.write(toFile: fileURL, atomically: true, encoding: .utf8)
                } else {
                    OALogger.fileManager.createFile(atPath: fileURL, contents: nil, attributes: [:])
                }
                OALogger.getZippedLogs()
            } catch let error as NSError {
                print("Error initiating session: \(error.localizedDescription)")
            } catch {
                print("Error initiating session - Something went wrong")
            }
        }
    }
    
    // MARK: - Class Methods
    @discardableResult
    class func getZippedLogs() -> String {
        let directoryToBeZip = FileManager.documentsDir() + "/OALogger_\(OALogger.customerID)"
        let zipPath = FileManager.documentsDir() + "/OALogger_\(OALogger.customerID).zip"
        SSZipArchive.createZipFile(atPath: zipPath, withContentsOfDirectory: directoryToBeZip)
        return zipPath
    }
    
    class func removeLogs() {
        let directoryToRemove = FileManager.documentsDir() + "/OALogger_\(OALogger.customerID)"
        if fileManager.fileExists(atPath: directoryToRemove) {
            do {
                try fileManager.removeItem(atPath: directoryToRemove)
            } catch let error as NSError {
                print("Removing Existing File Error: \(error.localizedDescription)")
            }
        }
    }
    
    class func removeZippedLogs() {
         let zipPath = FileManager.documentsDir() + "/OALogger_\(OALogger.customerID).zip"
        if fileManager.fileExists(atPath: zipPath) {
            do {
                try fileManager.removeItem(atPath: zipPath)
            } catch let error as NSError {
                print("Removing Existing File Error: \(error.localizedDescription)")
            }
        }
    }
}
