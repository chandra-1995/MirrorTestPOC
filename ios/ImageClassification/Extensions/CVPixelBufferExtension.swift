// Copyright 2019 The TensorFlow Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// =============================================================================

import UIKit
import Accelerate
import AVFoundation
import ImageIO

extension CVPixelBuffer {

  /**
   Returns thumbnail by cropping pixel buffer to biggest square and scaling the cropped image to
   model dimensions.
   */
  func centerThumbnail(ofSize size: CGSize ) -> CVPixelBuffer? {

    let imageWidth = CVPixelBufferGetWidth(self)
    let imageHeight = CVPixelBufferGetHeight(self)
    let pixelBufferType = CVPixelBufferGetPixelFormatType(self)

    assert(pixelBufferType == kCVPixelFormatType_32BGRA)

    let inputImageRowBytes = CVPixelBufferGetBytesPerRow(self)
    let imageChannels = 4

    let thumbnailSize = min(imageWidth, imageHeight)
    CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))

    var originX = 0
    var originY = 0

    if imageWidth > imageHeight {
      originX = (imageWidth - imageHeight) / 2
    }
    else {
      originY = (imageHeight - imageWidth) / 2
    }

    // Finds the biggest square in the pixel buffer and advances rows based on it.
    guard let inputBaseAddress = CVPixelBufferGetBaseAddress(self)?.advanced(
        by: originY * inputImageRowBytes + originX * imageChannels) else {
      return nil
    }

    // Gets vImage Buffer from input image
    var inputVImageBuffer = vImage_Buffer(
        data: inputBaseAddress, height: UInt(thumbnailSize), width: UInt(thumbnailSize),
        rowBytes: inputImageRowBytes)

    let thumbnailRowBytes = Int(size.width) * imageChannels
    guard  let thumbnailBytes = malloc(Int(size.height) * thumbnailRowBytes) else {
      return nil
    }

    // Allocates a vImage buffer for thumbnail image.
    var thumbnailVImageBuffer = vImage_Buffer(data: thumbnailBytes, height: UInt(size.height), width: UInt(size.width), rowBytes: thumbnailRowBytes)

    // Performs the scale operation on input image buffer and stores it in thumbnail image buffer.
    let scaleError = vImageScale_ARGB8888(&inputVImageBuffer, &thumbnailVImageBuffer, nil, vImage_Flags(0))

    CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))

    guard scaleError == kvImageNoError else {
      return nil
    }

    let releaseCallBack: CVPixelBufferReleaseBytesCallback = {mutablePointer, pointer in

      if let pointer = pointer {
        free(UnsafeMutableRawPointer(mutating: pointer))
      }
    }

    var thumbnailPixelBuffer: CVPixelBuffer?

    // Converts the thumbnail vImage buffer to CVPixelBuffer
    let conversionStatus = CVPixelBufferCreateWithBytes(
        nil, Int(size.width), Int(size.height), pixelBufferType, thumbnailBytes,
        thumbnailRowBytes, releaseCallBack, nil, nil, &thumbnailPixelBuffer)

    guard conversionStatus == kCVReturnSuccess else {

      free(thumbnailBytes)
      return nil
    }

    return thumbnailPixelBuffer
  }

  static func buffer(from image: UIImage) -> CVPixelBuffer? {
    let attrs = [
      kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
      kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
    ] as CFDictionary

    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                     Int(image.size.width),
                                     Int(image.size.height),
                                     kCVPixelFormatType_32BGRA,
                                     attrs,
                                     &pixelBuffer)

    guard let buffer = pixelBuffer, status == kCVReturnSuccess else {
      return nil
    }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    let pixelData = CVPixelBufferGetBaseAddress(buffer)

    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: pixelData,
                                  width: Int(image.size.width),
                                  height: Int(image.size.height),
                                  bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                  space: rgbColorSpace,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
      return nil
    }

    context.translateBy(x: 0, y: image.size.height)
    context.scaleBy(x: 1.0, y: -1.0)

    UIGraphicsPushContext(context)
    image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
    UIGraphicsPopContext()

    return pixelBuffer
  }
    
    
    /// Returns thumbnail by cropping pixel buffer to biggest square and scaling the cropped image
    /// to model dimensions.
    func resized(to size: CGSize ) -> CVPixelBuffer? {

      let imageWidth = CVPixelBufferGetWidth(self)
      let imageHeight = CVPixelBufferGetHeight(self)

      let pixelBufferType = CVPixelBufferGetPixelFormatType(self)

      assert(pixelBufferType == kCVPixelFormatType_32BGRA ||
             pixelBufferType == kCVPixelFormatType_32ARGB)

      let inputImageRowBytes = CVPixelBufferGetBytesPerRow(self)
      let imageChannels = 4

      CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))

      // Finds the biggest square in the pixel buffer and advances rows based on it.
      guard let inputBaseAddress = CVPixelBufferGetBaseAddress(self) else {
        return nil
      }

      // Gets vImage Buffer from input image
      var inputVImageBuffer = vImage_Buffer(data: inputBaseAddress, height: UInt(imageHeight), width: UInt(imageWidth), rowBytes: inputImageRowBytes)

      let scaledImageRowBytes = Int(size.width) * imageChannels
      guard  let scaledImageBytes = malloc(Int(size.height) * scaledImageRowBytes) else {
        return nil
      }

      // Allocates a vImage buffer for scaled image.
      var scaledVImageBuffer = vImage_Buffer(data: scaledImageBytes, height: UInt(size.height), width: UInt(size.width), rowBytes: scaledImageRowBytes)

      // Performs the scale operation on input image buffer and stores it in scaled image buffer.
      let scaleError = vImageScale_ARGB8888(&inputVImageBuffer, &scaledVImageBuffer, nil, vImage_Flags(0))

      CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))

      guard scaleError == kvImageNoError else {
        return nil
      }

      let releaseCallBack: CVPixelBufferReleaseBytesCallback = {mutablePointer, pointer in

        if let pointer = pointer {
          free(UnsafeMutableRawPointer(mutating: pointer))
        }
      }

      var scaledPixelBuffer: CVPixelBuffer?

      // Converts the scaled vImage buffer to CVPixelBuffer
      let conversionStatus = CVPixelBufferCreateWithBytes(nil, Int(size.width), Int(size.height), pixelBufferType, scaledImageBytes, scaledImageRowBytes, releaseCallBack, nil, nil, &scaledPixelBuffer)

      guard conversionStatus == kCVReturnSuccess else {

        free(scaledImageBytes)
        return nil
      }
        
      return scaledPixelBuffer
    }
    
    func getBrightness() -> Double {
        let rawMetadata = CMCopyDictionaryOfAttachments(allocator: nil, target: self, attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))
        let metadata = CFDictionaryCreateMutableCopy(nil, 0, rawMetadata) as NSMutableDictionary
        let exifData = metadata.value(forKey: "{Exif}") as? NSMutableDictionary
        let brightnessValue : Double = exifData?[kCGImagePropertyExifBrightnessValue as String] as! Double
        print(brightnessValue)
        return brightnessValue
    }
}

extension CGImage {
    var brightness: Double {
        get {
            var counter:Int = 0
            var r:Int = 0
            var g:Int = 0
            var b:Int = 0
            
            let width = Int(self.width)
            let height = Int(self.height)
            if let cfData = self.dataProvider?.data, let pointer = CFDataGetBytePtr(cfData) {
                for x in stride(from: 0, to: width, by: 2) {
                    for y in stride(from: 0, to: height, by: 2) {
                        let pixelAddress = x * 4 + y * width * 4
                        r += Int(pointer.advanced(by: pixelAddress).pointee)
                        g += Int(pointer.advanced(by: pixelAddress + 1).pointee)
                        b += Int(pointer.advanced(by: pixelAddress + 2).pointee)
                        counter += 1
                    }
                }
            }
            let bright = Double(Int(r+g+b) / (counter*3))
            return bright
        }
    }
}
extension UIImage {
    var brightness: Double {
        get {
            return (self.cgImage?.brightness)!
        }
    }
    
    var getBrightness: Double? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        let red = CGFloat(bitmap[0]) / 255
        let green = CGFloat(bitmap[1]) / 255
        let blue = CGFloat(bitmap[2]) / 255
        return Double((red+green+blue))/3
    }
    var extractBrightness: CGFloat {
        let pixel = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: 4)
        let colorSpace:CGColorSpace = CGColorSpaceCreateDeviceRGB()
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(data: pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        context?.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        
        if pixel[3] > 0 {
            var alpha:CGFloat = CGFloat(pixel[3]) / 255.0
            var multiplier:CGFloat = alpha / 255.0
            r = CGFloat(pixel[0]) * multiplier
            g = CGFloat(pixel[1]) * multiplier
            b = CGFloat(pixel[2]) * multiplier
        }else{
            r = CGFloat(pixel[0]) / 255.0
            g = CGFloat(pixel[1]) / 255.0
            b = CGFloat(pixel[2]) / 255.0
        }
        pixel.deallocate()
        return (r+g+b)/3
    }
    
    func scaledImage(_ maxDimension: CGFloat) -> UIImage? {
        var scaledSize = CGSize(width: maxDimension, height: maxDimension)
        
        if size.width > size.height {
            scaledSize.height = size.height / size.width * scaledSize.width
        } else {
            scaledSize.width = size.width / size.height * scaledSize.height
        }
        UIGraphicsBeginImageContext(scaledSize)
        
        draw(in: CGRect(x: 0, y: 0, width: scaledSize.width, height: scaledSize.height))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return scaledImage
    }
}
