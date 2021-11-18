//
//  MirrorTestConstantParameters.swift
//  ImageClassification
//
//  Created by Chandra Bhushan on 08/11/21.
//  Copyright © 2021 Y Media Labs. All rights reserved.
//

import Foundation
class MirrorTestConstantParameters{
    
    // OD Properties
    let objectDetectionConfidence: Float = 0.4
    let objectDetectionOtherClasses = ["tv", "laptop"]
    let objectDetectionReqClassName = "cell phone"
    
    // OCR Properties
    let LeftLabelText = "69"
    let RightLabelText = "37"
    let digitsComparisonForIMEIocr: Int  = 6
    
    // IC Properties
    let imageClassificationConfidence: Float =  0.25
    let imageClassificationMendatoryClass = "ok"
    
    // Far / Near Properties
    let requiredStripSize: Double = 0.2
    let requiredMinLeftRightBrighteness: Double = 10.0 // used for dark logic
    let requiredMinTopBottomBrighteness: Double = 5.0  // used for dark logic
    let requiredBoundingBoxPerUnit: Float = 0.11 // used for far logic in percentage
    let requiredBoundingBoxPerUnitNear: Float = 0.19  // used for near logic in percentage
    
    let primaryIMEI: String = "358353067774076"
    let secondaryIMEI: String = "358353067774098"
    
    let objectDetectionFailed = "Hold phone in front of the mirror"
    let okWithLowConfidence = "Hold the phone in front of the mirror"
    let obstractedImageDetected = "Remove fingers from screen"
    let objectIsFar = "Bring the phone slightly closer to the mirror"
    let objectIsNear = "Move the phone slightly back"
    let darkImageDetected = "Switch on more lights around you"
    let OCRFailed = "Capturing image..."
    let OCRLeftRightFailed = "Tilt your camera slightly downwards"
    let errorMessageAfterProcessFrames = 300
    static let shared = MirrorTestConstantParameters()
    
    //Initializer access level change now
    private init(){}
    
}
