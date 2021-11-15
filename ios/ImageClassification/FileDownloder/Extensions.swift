import UIKit
import VideoToolbox

extension Downloader {
    public convenience init(
        items: [(URL, String)],
        needsPreciseProgress: Bool = true,
        commonStrategy: Strategy = .ifUpdated,
        commonRequestHeaders: [String: String]? = nil
    ) {
        self.init(
            items: items.map { Item(url: $0.0, destination: $0.1) },
            needsPreciseProgress: needsPreciseProgress,
            commonStrategy: commonStrategy,
            commonRequestHeaders: commonRequestHeaders
        )
    }

    public func progress(
        _ handler: @escaping (
            _ bytesDownloaded: Int64,
            _ bytesExpectedToDownload: Int64?
        ) -> ()
    ) {
        progress { done, whole, _, _, _ in
            handler(done, whole)
        }
    }
    
    public func progress(_ handler: @escaping (Float?) -> ()) {
        if needsPreciseProgress {
            progress { done, whole in
                handler(whole.map { whole in Float(Double(done) / Double(whole)) })
            }
        } else {
            progress { _, _, itemIndex, done, whole in
                handler(whole.map { whole in (Float(itemIndex) + Float(Double(done) / Double(whole))) / Float(self.items.count) })
            }
        }
    }
}

extension String {
    internal var deletingLastPathComponent: String {
        return (self as NSString).deletingLastPathComponent
    }
    
    internal func appendingPathComponent(_ pathComponent: String) -> String {
        return (self as NSString).appendingPathComponent(pathComponent)
    }
}

extension FileManager {
    class func documentsDir() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as [String]
        return paths[0]
    }
    
    class func appendingPathComponent(_ pathComponent: String)->String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as [String]
        let mainPath = paths[0].appendingPathComponent(pathComponent)
        return mainPath
    }
    
    class func cachesDir() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true) as [String]
        return paths[0]
    }
}


extension UIImage {
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        if let cgImageVar = cgImage {
            self.init(cgImage: cgImageVar)
            return
        }
        return nil
    }
    
    func cropImage(rect: CGRect) -> UIImage? {
        
        if let cgImage = self.cgImage, let croppedCGImage = cgImage.cropping(to: rect) {
            return UIImage(cgImage: croppedCGImage)
        }
        return nil
    }
    
    func pixelBufferFromImage() -> CVPixelBuffer {
            
            
            let ciimage = CIImage(image: self)
            //let cgimage = convertCIImageToCGImage(inputImage: ciimage!)
            let tmpcontext = CIContext(options: nil)
            let cgimage =  tmpcontext.createCGImage(ciimage!, from: ciimage!.extent)
            
            let cfnumPointer = UnsafeMutablePointer<UnsafeRawPointer>.allocate(capacity: 1)
            let cfnum = CFNumberCreate(kCFAllocatorDefault, .intType, cfnumPointer)
            let keys: [CFString] = [kCVPixelBufferCGImageCompatibilityKey, kCVPixelBufferCGBitmapContextCompatibilityKey, kCVPixelBufferBytesPerRowAlignmentKey]
            let values: [CFTypeRef] = [kCFBooleanTrue, kCFBooleanTrue, cfnum!]
            let keysPointer = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: 1)
            let valuesPointer =  UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: 1)
            keysPointer.initialize(to: keys)
            valuesPointer.initialize(to: values)
            
            let options = CFDictionaryCreate(kCFAllocatorDefault, keysPointer, valuesPointer, keys.count, nil, nil)
           
            let width = cgimage!.width
            let height = cgimage!.height
         
            var pxbuffer: CVPixelBuffer?
            // if pxbuffer = nil, you will get status = -6661
            var status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                             kCVPixelFormatType_32BGRA, options, &pxbuffer)
            status = CVPixelBufferLockBaseAddress(pxbuffer!, CVPixelBufferLockFlags(rawValue: 0));
            
            let bufferAddress = CVPixelBufferGetBaseAddress(pxbuffer!);

            
            let rgbColorSpace = CGColorSpaceCreateDeviceRGB();
            let bytesperrow = CVPixelBufferGetBytesPerRow(pxbuffer!)
            let context = CGContext(data: bufferAddress,
                                    width: width,
                                    height: height,
                                    bitsPerComponent: 8,
                                    bytesPerRow: bytesperrow,
                                    space: rgbColorSpace,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue);
            context?.concatenate(CGAffineTransform(rotationAngle: 0))
            context?.concatenate(__CGAffineTransformMake( 1, 0, 0, -1, 0, CGFloat(height) )) //Flip Vertical
    //        context?.concatenate(__CGAffineTransformMake( -1.0, 0.0, 0.0, 1.0, CGFloat(width), 0.0)) //Flip Horizontal
            

            context?.draw(cgimage!, in: CGRect(x:0, y:0, width:CGFloat(width), height:CGFloat(height)));
            status = CVPixelBufferUnlockBaseAddress(pxbuffer!, CVPixelBufferLockFlags(rawValue: 0));
            return pxbuffer!;
            
        }
}
