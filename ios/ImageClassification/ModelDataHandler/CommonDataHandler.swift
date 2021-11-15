//
//  CommonDataHandler.swift
//  ImageClassification
//
//  Created by Ankur Batham on 15/02/21.
//  Copyright © 2021 Y Media Labs. All rights reserved.
//

import CoreImage
import UIKit
import Accelerate

let objectDetectionModelURL = URL(string: "https://awein.000webhostapp.com/TFLite/objectDetectAndroid.tflite")!
let objectDetectionLabelsURL = URL(string: "https://sit10.1atesting.in/static/oaapp/TfliteModels/Models/objectDetectionLabels.txt")!
let imageClassificationLabelsURL = URL(string: "https://sit10.1atesting.in/static/oaapp/TfliteModels/Models/imageClassificationLabels.txt")!
let imageClassificationModelURL = URL(string: "https://sit10.1atesting.in/static/oaapp/TfliteModels/Models/imageClassificationModel.tflite")!

let modelsZippedFileURL = URL(string: "https://sit10.1atesting.in/static/oaapp/TfliteModels/Models.zip")


// TODO:- file name should came from firebase
let objectDetectionModel = Bundle.main.path(forResource: "objectDetectionModel", ofType: "tflite")! //FileManager.documentsDir().appendingPathComponent("TFModels/objectDetectionModel.tflite")
let objectDetectionLabels = Bundle.main.path(forResource: "objectDetectionLabels", ofType: "txt")! //FileManager.documentsDir().appendingPathComponent("TFModels/objectDetectionLabels.txt")

let imageClassificationLabels = Bundle.main.path(forResource: "imageClassificationLabels", ofType: "txt")!
let imageClassificationModel = Bundle.main.path(forResource: "imageClassificationModel", ofType: "tflite")!

/// A result from invoking the `Interpreter`.
struct Result {
  let inferenceTime: Double
  let inferences: [Inference]
}

/// An inference from invoking the `Interpreter`.
struct Inference {
    let confidence: Float
    let label: String
    
    let className: String
    let rect: CGRect
    let displayColor: UIColor
}

/// Information about a model file or labels file.
typealias FileInfo = (path: String, fileType: String)

/// Information about the MobileNet model.
class MobileNet {
    static let modelInfo: FileInfo = (path: imageClassificationModel, fileType: "tflite")
    static let labelsInfo: FileInfo = (path: imageClassificationLabels, fileType: "txtfile")
}

/// Information about the MobileNet SSD model.
class MobileNetSSD {
  static let modelInfo: FileInfo = (path: objectDetectionModel, fileType: "tflite")
  static let labelsInfo: FileInfo = (path: objectDetectionLabels, fileType: "txtfile")
}

class CommonDataHandler {
    
    
    /// Returns the RGB data representation of the given image buffer with the specified `byteCount`.
    ///
    /// - Parameters
    ///   - buffer: The pixel buffer to convert to RGB data.
    ///   - byteCount: The expected byte count for the RGB data calculated using the values that the
    ///       model was trained on: `batchSize * imageWidth * imageHeight * componentsCount`.
    ///   - isModelQuantized: Whether the model is quantized (i.e. fixed point values rather than
    ///       floating point values).
    /// - Returns: The RGB data representation of the image buffer or `nil` if the buffer could not be
    ///     converted.
    
//    private let alphaComponent = (baseOffset: 4, moduloRemainder: 3)
//    func rgbDataFromBuffer(
//      _ buffer: CVPixelBuffer,
//      byteCount: Int,
//      isModelQuantized: Bool
//    ) -> Data? {
//      CVPixelBufferLockBaseAddress(buffer, .readOnly)
//      defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
//      guard let mutableRawPointer = CVPixelBufferGetBaseAddress(buffer) else {
//        return nil
//      }
//      let count = CVPixelBufferGetDataSize(buffer)
//      let bufferData = Data(bytesNoCopy: mutableRawPointer, count: count, deallocator: .none)
//      var rgbBytes = [UInt8](repeating: 0, count: byteCount)
//      var index = 0
//      for component in bufferData.enumerated() {
//        let offset = component.offset
//        let isAlphaComponent = (offset % alphaComponent.baseOffset) == alphaComponent.moduloRemainder
//        guard !isAlphaComponent else { continue }
//        rgbBytes[index] = component.element
//        index += 1
//      }
//      if isModelQuantized { return Data(bytes: rgbBytes) }
//      return Data(copyingBufferOf: rgbBytes.map { Float($0) / 255.0 })
//    }
    func rgbDataFromBuffer(
      _ buffer: CVPixelBuffer,
      byteCount: Int,
      isModelQuantized: Bool
    ) -> Data? {
        var start = CFAbsoluteTimeGetCurrent()
      CVPixelBufferLockBaseAddress(buffer, .readOnly)
      defer {
        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
      }
      guard let sourceData = CVPixelBufferGetBaseAddress(buffer) else {
        return nil
      }

      let width = CVPixelBufferGetWidth(buffer)
      let height = CVPixelBufferGetHeight(buffer)
      let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
      let destinationChannelCount = 3
      let destinationBytesPerRow = destinationChannelCount * width

      var sourceBuffer = vImage_Buffer(data: sourceData,
                                       height: vImagePixelCount(height),
                                       width: vImagePixelCount(width),
                                       rowBytes: sourceBytesPerRow)

      guard let destinationData = malloc(height * destinationBytesPerRow) else {
        print("Error: out of memory")
        return nil
      }

      defer {
          free(destinationData)
      }

      var destinationBuffer = vImage_Buffer(data: destinationData,
                                            height: vImagePixelCount(height),
                                            width: vImagePixelCount(width),
                                            rowBytes: destinationBytesPerRow)

      let pixelBufferFormat = CVPixelBufferGetPixelFormatType(buffer)

      switch (pixelBufferFormat) {
      case kCVPixelFormatType_32BGRA:
          vImageConvert_BGRA8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
      case kCVPixelFormatType_32ARGB:
          vImageConvert_ARGB8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
      case kCVPixelFormatType_32RGBA:
          vImageConvert_RGBA8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
      default:
          // Unknown pixel format.
          return nil
      }

      let byteData = Data(bytes: destinationBuffer.data, count: destinationBuffer.rowBytes * height)
      if isModelQuantized {
          return byteData
      }
      var diff = CFAbsoluteTimeGetCurrent() - start
      print("outside rgbDataFromBuffer buytes loop  \(diff) seconds")
      // Not quantized, convert to floats
      start = CFAbsoluteTimeGetCurrent()
      let bytes = Array<UInt8>(unsafeData: byteData)!
      var floats = [Float]()
      for i in 0..<bytes.count {
          floats.append(Float(bytes[i]) / 255.0)
      }
      diff = CFAbsoluteTimeGetCurrent() - start
      print("Inside rgbDataFromBuffer buytes loop  \(diff) seconds")
      return Data(copyingBufferOf: floats)
    }
    
  
}

// MARK: - Extensions

extension Data {
  /// Creates a new buffer by copying the buffer pointer of the given array.
  ///
  /// - Warning: The given array's element type `T` must be trivial in that it can be copied bit
  ///     for bit with no indirection or reference-counting operations; otherwise, reinterpreting
  ///     data from the resulting buffer has undefined behavior.
  /// - Parameter array: An array with elements of type `T`.
  init<T>(copyingBufferOf array: [T]) {
    self = array.withUnsafeBufferPointer(Data.init)
  }
}

extension Array {
  /// Creates a new array from the bytes of the given unsafe data.
  ///
  /// - Warning: The array's `Element` type must be trivial in that it can be copied bit for bit
  ///     with no indirection or reference-counting operations; otherwise, copying the raw bytes in
  ///     the `unsafeData`'s buffer to a new array returns an unsafe copy.
  /// - Note: Returns `nil` if `unsafeData.count` is not a multiple of
  ///     `MemoryLayout<Element>.stride`.
  /// - Parameter unsafeData: The data containing the bytes to turn into an array.
  init?(unsafeData: Data) {
    guard unsafeData.count % MemoryLayout<Element>.stride == 0 else { return nil }
    #if swift(>=5.0)
    self = unsafeData.withUnsafeBytes { .init($0.bindMemory(to: Element.self)) }
    #else
    self = unsafeData.withUnsafeBytes {
      .init(UnsafeBufferPointer<Element>(
        start: $0,
        count: unsafeData.count / MemoryLayout<Element>.stride
      ))
    }
    #endif  // swift(>=5.0)
  }
}
