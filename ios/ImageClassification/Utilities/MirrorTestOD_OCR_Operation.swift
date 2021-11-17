//
//  AsyncMirrorTestOD&OCROperatoin.swift
//  ImageClassification
//
//  Created by Chandra Bhushan on 08/11/21.
//  Copyright © 2021 Y Media Labs. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

class MirrorTestOD_OCR_Operation: AsyncOperation {
    private let oaLogger: OALogger?
    private let pixelBuffer: CVPixelBuffer
    let processResultModel: MirrorTestProcessModel = MirrorTestProcessModel()
    
    // MARK: - INSTANCE METHODS
    init(pixelBuffer: CVPixelBuffer, logger: OALogger?) {
        self.oaLogger = logger
        self.pixelBuffer = pixelBuffer
    }

    override func main() {
        
        guard !isCancelled else {
            finish()
            return
        }
        self.processResultModel.originalImage = UIImage(pixelBuffer: pixelBuffer)
        if let objectDetectionResult = runObjectDetectionModel(), let originalImage = self.processResultModel.originalImage {
            self.processResultModel.detectedObjectRect = objectDetectionResult.rect
            if var detectedObjectRect = self.processResultModel.detectedObjectRect {
                detectedObjectRect.size.height = originalImage.size.height - detectedObjectRect.minY
                let imageForOCR = originalImage.cropImage(rect: detectedObjectRect)
                guard !self.isCancelled else {
                    self.finish()
                    return
                }
                self.performOCR(originalImage: originalImage,imageForOCR: imageForOCR)
            }
        } else {
            debugPrint("object detection failed.  \(String(describing: self.name))")
            self.oaLogger?.log(errorString: "object detection failed.  \(String(describing: self.name))", primaryImage: self.processResultModel.originalImage, primaryImageName: self.name ?? "")
            self.processResultModel.mProcessError = MirrorTestError.ObjectDetectionFaild
            self.finish()
        }
    }
}


extension MirrorTestOD_OCR_Operation {
    func runObjectDetectionModel() -> Inference? {
        let objectDataHandler = ModelDataHandler(modelFileInfo: MobileNetSSD.modelInfo, labelsFileInfo: MobileNetSSD.labelsInfo, inputWidth: 300, inputHeight: 300)
        let results = objectDataHandler?.runObjectModel(onFrame: pixelBuffer)
        let confidence = MirrorTestConstantParameters.shared.objectDetectionConfidence
        var finalResult: Inference?
        debugPrint("\(String(describing: self.name)) : Runing object detection \(String(describing: results))")
        oaLogger?.log(errorString: "\(String(describing: self.name)) : Runing object detection \(String(describing: results))")
        if let matchedResult = results?.inferences.filter({$0.className == MirrorTestConstantParameters.shared.objectDetectionReqClassName && $0.confidence >= confidence}).first {
            finalResult = matchedResult
        } else {
            // in case cell phone is not in results we assume that system is assuming cell phone as laptop, tv etc.
            for inference in (results?.inferences ?? []) {
                if MirrorTestConstantParameters.shared.objectDetectionOtherClasses.contains(inference.className) && inference.confidence >= confidence {
                    finalResult = inference
                    break
                }
            }
        }
        return finalResult
    }
    
    func performOCR(originalImage: UIImage, imageForOCR: UIImage?) {
        let textRecognizer = ImageTextAndBarCodeRecognizer()
        textRecognizer.getTextFromImage(image: imageForOCR, readTextType: nil, isImageScaleReq: false) { [weak self] (recognizTexts, snapshot, errorMessage) in
            guard let self = self, !self.isCancelled else {
                self?.finish()
                return
            }
            
            let ocrResult = self.doOCROnRecognizedTexts(recognizedTexts: recognizTexts)
            // check imei & security text lies in OCR Text
            if ocrResult.imeiOCR && ocrResult.leftRightOCR {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if !self.isCancelled {
                        self.finish()
                    }
                }
            } else {
                debugPrint("OCR Failed with values \(ocrResult) \(String(describing: self.name))")
                self.oaLogger?.log(errorString: "OCR Failed with values \(ocrResult) \(String(describing: self.name))", primaryImage: originalImage, primaryImageName: self.name ?? "", secondaryImage: imageForOCR, secondaryImageName: self.name ?? "")
                self.processResultModel.mProcessError = ocrResult.imeiOCR ? MirrorTestError.OCRFailed : MirrorTestError.LeftRightTextOCRFailed
                self.finish()
            }
        }
    }
    
    func doOCROnRecognizedTexts(recognizedTexts: [String]? = []) -> (leftRightOCR: Bool, imeiOCR: Bool) {
        var result = false
        var imeiVarified = false
        let primaryIMEI: String? = MirrorTestConstantParameters.shared.primaryIMEI
        if let texts = recognizedTexts, let imei = primaryIMEI?.description {
            let imeiSubTextToCompare = imei.prefix(MirrorTestConstantParameters.shared.digitsComparisonForIMEIocr)
            imeiVarified = texts.filter({$0.contains(imeiSubTextToCompare)}).first != nil
            if texts.contains(MirrorTestConstantParameters.shared.LeftLabelText), texts.contains(MirrorTestConstantParameters.shared.RightLabelText), imeiVarified {
                result = true
            }
        }
        return (leftRightOCR: (imeiVarified && result), imeiOCR: imeiVarified)
    }
}
