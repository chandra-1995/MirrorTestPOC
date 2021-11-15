//
//  MirrorTest_IC_Far_Operation.swift
//  ImageClassification
//
//  Created by Chandra Bhushan on 08/11/21.
//  Copyright © 2021 Y Media Labs. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

class MirrorTest_IC_Far_Operation: AsyncOperation {
    private let pixelBuffer: CVPixelBuffer
    private let oaLogger: OALogger
    var originalImage: UIImage?
    var detectedObjectRect: CGRect?
    var imeiError: String?
    var operationError: String?
    
    // MARK: - INSTANCE METHODS
    init(pixelBuffer: CVPixelBuffer, logger: OALogger, originalImage: UIImage, detectedObjectRect: CGRect, imeiError: String? = nil) {
        self.pixelBuffer = pixelBuffer
        self.oaLogger = logger
        self.originalImage = originalImage
        self.detectedObjectRect = detectedObjectRect
        self.imeiError = imeiError
    }
    
    override func main() {
        
        guard !isCancelled, let detectedObjectRect = self.detectedObjectRect else {
            return
        }
        
        let detectedObjImage = originalImage?.cropImage(rect: detectedObjectRect)
        let result = checkIfFarOrNear(image: originalImage, croppedImage: detectedObjImage)
        // Test far & near
        if !result.far && !result.near {
            let detectedObjCVBuffer = detectedObjImage?.pixelBufferFromImage()
            // Test Dark logic
            if !isDark(capturedImage: originalImage), let detectedObjCVBuffer = detectedObjCVBuffer {
                guard !self.isCancelled else {return}
                // Run image classification
                if let results = runImageClassification(pixelBuffer: detectedObjCVBuffer, isSkipNonMendatoryClasses: false) {
                    // if classification failed
                    if results.filter({$0.label == MirrorTestConstantParameters.shared.imageClassificationMendatoryClass && $0.confidence >= MirrorTestConstantParameters.shared.imageClassificationConfidence}).first == nil {
                        let resultWithMaxConfidence = results.max{ prev, next in prev.confidence < next.confidence }
                        
                        if resultWithMaxConfidence?.label == MirrorTestConstantParameters.shared.imageClassificationMendatoryClass { // low confidence with ok
                            debugPrint("classification failed ImageClassificationLowConfidence \(self.name)")
                            oaLogger.log(errorString: "classification failed ImageClassificationLowConfidence", primaryImage: originalImage, primaryImageName: self.name, secondaryImage: detectedObjImage, secondaryImageName: self.name)
                            operationError = MirrorTestConstantParameters.shared.okWithLowConfidence
                        } else { // result found other than ok
                            debugPrint("Obstracted Image Detected \(self.name)")
                            oaLogger.log(errorString: "Obstracted Image Detected", primaryImage: originalImage, primaryImageName: self.name, secondaryImage: detectedObjImage, secondaryImageName: self.name)
                            operationError = MirrorTestConstantParameters.shared.obstractedImageDetected
                        }
                    }
                } else { // no result from classification
                    debugPrint("image classification failed  \(self.name)")
                    self.oaLogger.log(errorString: "image classification failed  \(self.name)", primaryImage: originalImage, primaryImageName: self.name ?? "")
                }
            } else { // dark logic failed
                debugPrint("dark logic failed  \(String(describing: self.name))")
                self.oaLogger.log(errorString: "dark logic failed  \(String(describing: self.name))", primaryImage: originalImage, primaryImageName: self.name ?? "")
                operationError = MirrorTestConstantParameters.shared.darkImageDetected
            }
        } else { // far or near failed
            debugPrint("far & near logic failed far value = \(result.far) , near value = \(result.near)  \(String(describing: self.name))")
            self.oaLogger.log(errorString: "far & near logic failed far value = \(result.far) , near value = \(result.near)  \(String(describing: self.name))", primaryImage: originalImage, primaryImageName: self.name ?? "")
            operationError = result.far ? MirrorTestConstantParameters.shared.objectIsFar : MirrorTestConstantParameters.shared.objectIsNear
        }
        
        guard !self.isCancelled else {return}
        self.finish()
    }
}

extension MirrorTest_IC_Far_Operation {
    
    private func runImageClassification(pixelBuffer: CVPixelBuffer, isSkipNonMendatoryClasses: Bool = false) -> [Inference]? {
        let imageDataHandler = ModelDataHandler(modelFileInfo: MobileNet.modelInfo, labelsFileInfo: MobileNet.labelsInfo, inputWidth: 224, inputHeight: 224)
        debugPrint("Runing image classfication , \(self.name)")
        oaLogger.log(errorString: "Runing image classfication , \(self.name)")
        let results = imageDataHandler?.runImageModel(onFrame: pixelBuffer)
        debugPrint("\(self.name) : Result from image classification :- \n \(String(describing: results))  ")
        oaLogger.log(errorString: "\(self.name) : Result from image classification :- \n \(self.name)")
        return results?.inferences
    }
    
    private func checkIfFarOrNear(image:UIImage?, croppedImage: UIImage?) -> (far: Bool,near: Bool) { // far logic
        debugPrint("Runing far logic  \(String(describing: self.name))")
        oaLogger.log(errorString: "Runing far logic  \(String(describing: self.name))")
        var result = (far: true, near: true)
        let areaOfActualImage = (image?.size.height ?? 0) * (image?.size.width ?? 0) // area of actual image
        let areaOfCroppedImage = (croppedImage?.size.height ?? 0) * (croppedImage?.size.width ?? 0) // area of cropped image
        
        let precentageAreaofCroppedInImage = areaOfCroppedImage/areaOfActualImage
        result.far = precentageAreaofCroppedInImage <= CGFloat(MirrorTestConstantParameters.shared.requiredBoundingBoxPerUnit)
        result.near = precentageAreaofCroppedInImage >= CGFloat(MirrorTestConstantParameters.shared.requiredBoundingBoxPerUnitNear)
        
        debugPrint("area of actual image \(areaOfActualImage) area of cropped image \(areaOfCroppedImage) precentageAreaofCroppedInImage \(precentageAreaofCroppedInImage)")
        oaLogger.log(errorString: "\(String(describing: self.name)) :: area of actual image \(areaOfActualImage) area of cropped image \(areaOfCroppedImage) precentageAreaofCroppedInImage \(precentageAreaofCroppedInImage)")
        return result
    }
    
    private func isDark(capturedImage: UIImage?) -> Bool { // Dark logic
        var result = false
        if let image = capturedImage, let detectedObjectRect = detectedObjectRect {
            let values = getBrightnessOutSideBoundingBox(originalImage: image, objectImageRect: detectedObjectRect)
            debugPrint("dark values \(values)")
            oaLogger.log(errorString: "dark values \(values)")
            if values.left < MirrorTestConstantParameters.shared.requiredMinLeftRightBrighteness
                || values.right < MirrorTestConstantParameters.shared.requiredMinLeftRightBrighteness
                || values.top < MirrorTestConstantParameters.shared.requiredMinTopBottomBrighteness
                || values.bottom < MirrorTestConstantParameters.shared.requiredMinTopBottomBrighteness  {
                result = true
            }
        }
        return result
    }
    
    
    private func getBrightnessOutSideBoundingBox(originalImage: UIImage, objectImageRect: CGRect) -> (left: Double,right: Double,top: Double, bottom: Double) {
        let stripeSize = CGFloat(MirrorTestConstantParameters.shared.requiredStripSize)
        let strippedSize = Int(objectImageRect.width * stripeSize)
        
        let leftBoxImageBrightness = getLeftBoxImageBrightness(originalImage: originalImage, objectImageRect: objectImageRect, strippedSize: strippedSize)
        
        let rightBoxImageBrightness = getRightBoxImageBrightness(originalImage: originalImage, objectImageRect: objectImageRect, strippedSize: strippedSize)
        
        let topBoxImageBrighness = getTopBoxImageBrightness(originalImage: originalImage, objectImageRect: objectImageRect, strippedSize: strippedSize)
        
        let bottomBoxImageBrightness = getBottomBoxImageBrightness(originalImage: originalImage, objectImageRect: objectImageRect, strippedSize: strippedSize)
        return (left: leftBoxImageBrightness, right: rightBoxImageBrightness,top: topBoxImageBrighness, bottom: bottomBoxImageBrightness)
    }
    
    func getLeftBoxImageBrightness(originalImage: UIImage, objectImageRect: CGRect, strippedSize: Int) -> Double {
        let newX = -strippedSize + Int(objectImageRect.minX)
        if newX >= 0 {
            return originalImage.cropImage(rect: CGRect(x: newX, y: Int(objectImageRect.minY), width: strippedSize, height: Int(objectImageRect.height)))?.brightness ?? 0
        }
        return 220 // default brightness
    }
    func getRightBoxImageBrightness(originalImage: UIImage, objectImageRect: CGRect, strippedSize: Int) -> Double {
        if (objectImageRect.maxX + CGFloat(strippedSize)) <= originalImage.size.width {
            return originalImage.cropImage(rect: CGRect(x: Int(objectImageRect.maxX), y: Int(objectImageRect.minY), width: strippedSize, height: Int(objectImageRect.height)))?.brightness ?? 0
        }
        return 220
    }
    func getTopBoxImageBrightness(originalImage: UIImage, objectImageRect: CGRect, strippedSize: Int) -> Double {
        let newY = Int(objectImageRect.minY) - strippedSize
        if newY >= 0 {
            return originalImage.cropImage(rect: CGRect(x: Int(objectImageRect.minX), y: newY, width: Int(objectImageRect.width), height: strippedSize))?.brightness ?? 0
        }
        return 220
    }
    func getBottomBoxImageBrightness(originalImage: UIImage, objectImageRect: CGRect, strippedSize: Int) -> Double {
        if (CGFloat(strippedSize) + objectImageRect.maxY) <= originalImage.size.height {
            return originalImage.cropImage(rect: CGRect(x: Int(objectImageRect.minX), y: Int(objectImageRect.maxY), width: Int(objectImageRect.width), height: strippedSize))?.brightness ?? 0
        }
        return 220
    }
}
