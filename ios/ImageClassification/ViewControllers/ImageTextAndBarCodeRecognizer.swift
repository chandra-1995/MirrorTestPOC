//
//  ImageTextAndBarCodeRecognizer.swift
//  OneAssist-Swift
//
//  Created by Ankur Batham on 30/09/19.
//  Copyright © 2019 OneAssist. All rights reserved.
//

import UIKit
import Firebase
import AVFoundation

//import TesseractOCR

open class ImageTextAndBarCodeRecognizer {
    public enum TextReadType: String {
        case IMEI_READ
    }
    
    lazy var vision = Vision.vision()
    private var textRecognizer: VisionTextRecognizer?
    
    private var insertionOrderArr: [(numericKey: String, frame: CGRect)] = []
    private var originalImage: UIImage?
    private var croppedHeightFirstIMEI: CGFloat = 0.0
    
    
    //use these value only for tracking
    var isBarCodeScannerSupport = false
    var isBarCodeScannerValidate = false
    var isValueSaveToFireStore = false
    private var OCRText: String = ""
    private var validatedImeis: [String] = []
    private var barcodeScanText: String?
    
    public init() {
        textRecognizer = vision.onDeviceTextRecognizer()
    }
    
    public func getTextFromImage(image: UIImage?, readTextType:TextReadType?, isImageScaleReq: Bool = true, completionHandler: @escaping([String]?, UIImage?, String?) -> Void){
        if let scanimage =  image {
            originalImage = scanimage
            let scaledImage = originalImage
            let image = VisionImage(image: scaledImage!)
            textRecognizer?.process(image) { result, error in
                guard error == nil, let result = result else {
                    completionHandler(nil, scanimage, "Text not recognized")
                    return
                }
                var compleText: String? = nil;
                for block in result.blocks {
                    self.setFrameInList(with: block)
                    
                    if let text = compleText {
                        compleText = text + " " + block.text
                    }else {
                        compleText = block.text
                    }
                }
                print(" Recognized Text \(compleText)")
                if let text = compleText {
                    self.OCRText = text
                    self.getValidateText(text, scanimage: scaledImage, readTextType: readTextType, completionHandler: completionHandler)
                }else {
                    completionHandler(nil, scanimage, "Text not recognized")
                }
            }
        }else {
           completionHandler(nil, nil, nil)
        }
    }
    
    private func setFrameInList(with block: VisionTextBlock) {
        let removeNewLineText = String(block.text.replacingOccurrences(of: "[\\s\n\t\r]+", with: " ", options: .regularExpression, range: nil))
        let sepetateText: [String] = removeNewLineText.components(separatedBy: " ")
        
        for str in sepetateText {
            let trimmedString = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedString.count > 1 && trimmedString.isNumeric {
                self.insertionOrderArr.append((numericKey: trimmedString, frame: block.frame))
            }
        }
    }
    
    private func getValidateText(_ text: String, scanimage: UIImage?, readTextType:TextReadType?,  completionHandler: @escaping([String]?, UIImage?, String?) -> Void) {
        if readTextType == .IMEI_READ {
            
            let imeis = self.validateText(text)
            self.validatedImeis = imeis
            
            if !imeis.isEmpty {
                if isBarCodeScannerSupport {
                    detectBarcodes(in: scanimage, with: imeis, completionHandler: completionHandler)
                }else {
                    completionHandler(imeis, scanimage, nil)
                }
                
            } else {
                completionHandler(nil, scanimage, "Text not recognized")
            }
            
        }else {
            print("text === \(text)")
            let removeNewLineText = String(text.replacingOccurrences(of: "[\\s\n\t\r]+", with: " ", options: .regularExpression, range: nil))
            let sepetateText: [String] = removeNewLineText.components(separatedBy: " ")
            
            var textss:[String] = []
            for str in sepetateText {
                let trimmedString = str.trimmingCharacters(in: .whitespacesAndNewlines)
                textss.append(trimmedString)
            }
            completionHandler(textss, scanimage, nil)
        }
    }
}

extension ImageTextAndBarCodeRecognizer {
    private func validateText(_ text: String)->[String]{
        let removeNewLineText = String(text.replacingOccurrences(of: "[\\s\n\t\r]+", with: " ", options: .regularExpression, range: nil))
        let sepetateText: [String] = removeNewLineText.components(separatedBy: " ")
        
        var imeis:[String] = []
        for str in sepetateText {
            let trimmedString = str.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedString.count > 10 {
                if trimmedString.luhnCheckForValidImei(), trimmedString.isNumeric {
                    imeis.append(trimmedString)
                }
            }
        }
        
        return imeis
    }
}

extension ImageTextAndBarCodeRecognizer {
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            // we got back an error!
            let ac = UIAlertController(title: "Save error", message: error.localizedDescription, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            
        } else {
            let ac = UIAlertController(title: "Saved!", message: "Your altered image has been saved to your photos.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
        }
    }
    
    private func getFrameAndIndex(of imei: String, in arrOfTuple: [(numericKey: String, frame: CGRect)]) -> (frame: CGRect,index: Int) {
        for (index,tuple) in arrOfTuple.enumerated() { if tuple.numericKey == imei { return (frame: tuple.frame, index: index) } }
        return (frame: CGRect.zero, index: -1)
    }
    
    private func getImeiFrame(in originalImage: UIImage, and scaledImage: UIImage, imei: String, case: String) -> CGRect {
        let imeiFrameAndIndex = getFrameAndIndex(of: imei, in: insertionOrderArr)
        
        let imeiFrame = imeiFrameAndIndex.frame
        
        var croppedHeight: CGFloat = 0.0
        
        var yPosIMEI = imeiFrame.origin.y + imeiFrame.height + 10
        
        // For cropped Height case
        if `case` == "IMEI_FIRST" {
            var nextNumericKeyFrame: CGRect?
            if imeiFrameAndIndex.index < insertionOrderArr.count - 1 {
                nextNumericKeyFrame = insertionOrderArr[imeiFrameAndIndex.index + 1].frame
            }
            
            // 40 is to remove bottom bar
            croppedHeight = (scaledImage.size.height - yPosIMEI) - 40
            
            if let nextNumericKeyFrame = nextNumericKeyFrame {
                croppedHeight = (nextNumericKeyFrame.origin.y - 10) - yPosIMEI
            }
            
            croppedHeightFirstIMEI = croppedHeight
        } else if `case` == "IMEI_SECOND" {
            croppedHeight = croppedHeightFirstIMEI
        }
        
        let heightFactor = scaledImage.size.height / originalImage.size.height
        
        yPosIMEI /= heightFactor
        croppedHeight /= heightFactor
        
        return CGRect(x: 0, y: yPosIMEI, width: originalImage.size.width, height: croppedHeight)
    }
    
    private func getCroppedImage(of originalImage: UIImage, and scaledImage: UIImage, with imeis: [String]) -> [UIImage] {
        var croppedImages: [UIImage] = []
        let originalCGImage = originalImage.cgImage!
        
        let firstCroppedImage = UIImage(cgImage: originalCGImage.cropping(to: getImeiFrame(in: originalImage, and: scaledImage, imei: imeis[0], case: "IMEI_FIRST"))!)
        let firstScaledCroppedImage = firstCroppedImage.scaledImage(3000) ?? firstCroppedImage
        croppedImages.append(firstScaledCroppedImage)
        
        if imeis.count > 1 {
            let secondCroppedImage = UIImage(cgImage: originalCGImage.cropping(to: getImeiFrame(in: originalImage, and: scaledImage, imei: imeis[1], case: "IMEI_SECOND"))!)
            let secondScaledCroppedImage = secondCroppedImage.scaledImage(3000) ?? secondCroppedImage
            croppedImages.append(secondScaledCroppedImage)
        }
        
        return croppedImages
    }
    
    // Detects barcodes on the specified image
    func detectBarcodes(in image: UIImage?, with imeis: [String], completionHandler: @escaping([String]?, UIImage?, String?) -> Void) {
        guard let image = image else { return }
        
        var croppedImages: [UIImage] = []
        
        croppedImages = getCroppedImage(of: originalImage!, and: image, with: imeis)
        
        let barcodeOptions = VisionBarcodeDetectorOptions(formats: .all)
        
        // Create a barcode detector.
        let barcodeDetector = vision.barcodeDetector(options: barcodeOptions)
        
        let metadata = VisionImageMetadata()
        metadata.orientation = ImageTextAndBarCodeRecognizer.visionImageOrientation(from: image.imageOrientation)
        
        let group = DispatchGroup()
        
        if croppedImages.count > 0 {
            for croppedImage in croppedImages {
                group.enter()
                let visionImage = VisionImage(image: croppedImage)
                visionImage.metadata = metadata
                
                let dispatchQueue = DispatchQueue(label: "queueIdentification", qos: .background)
                dispatchQueue.async(group: group, execute: {
                    barcodeDetector.detect(in: visionImage) { (features, error) in
                        guard error == nil, let features = features, !features.isEmpty else {
                            group.leave()
                            return
                        }
                        
                        let resultsText
                            = features.map { feature in
                                return "DisplayValue: \(feature.displayValue ?? ""), RawValue: "
                                    + "\(feature.rawValue ?? ""), Frame: \(feature.frame)"
                                }.joined(separator: "\n")
                        print(resultsText)
                        
                        if self.barcodeScanText != nil {
                            self.barcodeScanText = "\(self.barcodeScanText ?? "") - \(features.first?.displayValue ?? "")"
                        } else {
                            self.barcodeScanText = features.first?.displayValue ?? ""
                        }
                        
                        group.leave()
                    }
                })
            }
        }else {
            completionHandler(imeis, image, nil)
        }
        
        group.notify(queue: .main) {[weak self] in
            guard let self = self else { return }
            if self.isBarCodeScannerValidate {
                var isStringMatch = true
                let sepetateText: [String] = self.barcodeScanText?.components(separatedBy: "-") ?? [""]
                for str in sepetateText {
                    let trimmedString = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !imeis.contains(trimmedString) {
                        isStringMatch = false
                    }
                }
                if isStringMatch {
                    completionHandler(imeis, image, nil)
                    
                }else {
                    completionHandler(nil, image, "Text not recognized")
                }
                
            }else {
                completionHandler(imeis, image, nil)
            }
        }
    }
    
    public static func visionImageOrientation(
        from imageOrientation: UIImage.Orientation
        ) -> VisionDetectorImageOrientation {
        switch imageOrientation {
        case .up:
            return .topLeft
        case .down:
            return .bottomRight
        case .left:
            return .leftBottom
        case .right:
            return .rightTop
        case .upMirrored:
            return .topRight
        case .downMirrored:
            return .bottomLeft
        case .leftMirrored:
            return .leftTop
        case .rightMirrored:
            return .rightBottom
        }
    }
}


/* func getTesseractOCRFromImage(image: UIImage?, readTextType:TextReadType?,  completionHandler: @escaping(String?, UIImage?, String?) -> Void){
 if let scanimage =  image {
 DispatchQueue.global(qos: .background).async {[unowned self] in
 let scaledImage = scanimage.scaledImage(1000)
 if let tesseract = G8Tesseract(language: "eng") {
 tesseract.engineMode = .tesseractOnly
 tesseract.maximumRecognitionTime = 60
 tesseract.pageSegmentationMode = .auto
 tesseract.image = scaledImage ?? UIImage()
 tesseract.rect = CGRect(x: 0.0, y: 0.0, width: (scaledImage?.size.width)!, height: (scaledImage?.size.height)!/2.0)
 tesseract.recognize()
 print(tesseract.recognizedText as Any)
 if let screenTest = tesseract.recognizedText {
 self.getValidateText(screenTest, scanimage: scaledImage, readTextType: readTextType, completionHandler: completionHandler)
 
 }else {
 completionHandler(nil, scanimage, Strings.iOSFraudDetection.imageTextReadError)
 
 }
 }else {
 completionHandler(nil, scanimage, Strings.iOSFraudDetection.imageTextReadError)
 }
 }
 }else {
 completionHandler(nil, nil, Strings.iOSFraudDetection.imageTextReadError)
 }
 }
 */

