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

import TensorFlowLite

class ModelDataHandler: CommonDataHandler {
  /// The current thread count used by the TensorFlow Lite Interpreter.
  let threadCount: Int

  let resultCount = 5
  let threadCountLimit = 10
    let threshold: Float = 0.5
  // MARK: - Model Parameters

  let batchSize = 1
  let inputChannels = 3
    var inputWidth: Int
    var inputHeight: Int
    
  // MARK: - Private Properties

  /// List of labels from the given labels file.
  private var labels: [String] = []

  /// TensorFlow Lite `Interpreter` object for performing inference on a given model.
  private var interpreter: Interpreter
    
    private let bgraPixel = (channels: 4, alphaComponent: 3, lastBgrComponent: 2)
    private let rgbPixelChannels = 3
    private let colorStrideValue = 10
    private let colors = [
      UIColor.red,
      UIColor(displayP3Red: 90.0/255.0, green: 200.0/255.0, blue: 250.0/255.0, alpha: 1.0),
      UIColor.green,
      UIColor.orange,
      UIColor.blue,
      UIColor.purple,
      UIColor.magenta,
      UIColor.yellow,
      UIColor.cyan,
      UIColor.brown
    ]
    
  /// Information about the alpha component in RGBA data.
  private let alphaComponent = (baseOffset: 4, moduloRemainder: 3)

  // MARK: - Initialization

  /// A failable initializer for `ModelDataHandler`. A new instance is created if the model and
  /// labels files are successfully loaded from the app's main bundle. Default `threadCount` is 1.
    init?(modelFileInfo: FileInfo, labelsFileInfo: FileInfo, inputWidth: Int, inputHeight: Int,  threadCount: Int = 4) {
    // Construct the path to the model file.

    // Specify the options for the `Interpreter`.
    self.threadCount = threadCount
        self.inputWidth = inputWidth
        self.inputHeight = inputHeight
    var options = InterpreterOptions()
    options.threadCount = threadCount
    do {
      // Create the `Interpreter`.
        interpreter = try Interpreter(modelPath: modelFileInfo.path, options: options)
      // Allocate memory for the model's input `Tensor`s.
      try interpreter.allocateTensors()
    } catch let error {
      print("Failed to create the interpreter with error: \(error.localizedDescription)")
      return nil
    }
    super.init()
        // Load the classes listed in the labels file.
    loadLabels(fileInfo: labelsFileInfo)
  }
    
    
    /// Loads the labels from the labels file and stores them in the `labels` property.
    private func loadLabels(fileInfo: FileInfo) {
        let url = URL(fileURLWithPath: fileInfo.path)
            do {
              let contents = try String(contentsOf: url, encoding: .utf8)
              labels = contents.components(separatedBy: .newlines)
            } catch {
             
            }
          
    }

}

typealias ImageClasification = ModelDataHandler

extension ImageClasification {
    // MARK: - Internal Methods

    /// Performs image preprocessing, invokes the `Interpreter`, and processes the inference results.
    func runImageModel(onFrame pixelBuffer: CVPixelBuffer) -> Result? {
        var start = CFAbsoluteTimeGetCurrent()
      let sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
      assert(sourcePixelFormat == kCVPixelFormatType_32ARGB ||
               sourcePixelFormat == kCVPixelFormatType_32BGRA ||
                 sourcePixelFormat == kCVPixelFormatType_32RGBA)


      let imageChannels = 4
      assert(imageChannels >= inputChannels)
      // Crops the image to the biggest square in the center and scales it down to model dimensions.
      let scaledSize = CGSize(width: inputWidth, height: inputHeight)
      guard let thumbnailPixelBuffer = pixelBuffer.centerThumbnail(ofSize: scaledSize) else {
        return nil
      }
        
        var diff = CFAbsoluteTimeGetCurrent() - start
        print("Time Taken During creating thumbnailPixelBuffer  \(diff) seconds")

      let interval: TimeInterval
      let outputTensor: Tensor
      do {
        
        let inputTensor = try interpreter.input(at: 0)
        start = CFAbsoluteTimeGetCurrent()
        // Remove the alpha component from the image buffer to get the RGB data.
        guard let rgbData = rgbDataFromBuffer(
          thumbnailPixelBuffer,
          byteCount: batchSize * inputWidth * inputHeight * inputChannels,
          isModelQuantized: inputTensor.dataType == .uInt8
        ) else {
          print("Failed to convert the image buffer to RGB data.")
          return nil
        }
        
        diff = CFAbsoluteTimeGetCurrent() - start
        print("Time Taken During interpreter input & rgbDataFromBuffer  \(diff) seconds")
        // Copy the RGB data to the input `Tensor`.
        start = CFAbsoluteTimeGetCurrent()
        try interpreter.copy(rgbData, toInputAt: 0)

        // Run inference by invoking the `Interpreter`.
        let startDate = Date()
        try interpreter.invoke()
        interval = Date().timeIntervalSince(startDate) * 1000

        // Get the output `Tensor` to process the inference results.
        outputTensor = try interpreter.output(at: 0)
        diff = CFAbsoluteTimeGetCurrent() - start
        print("Time Taken During interpreter invoking & getting output  \(diff) seconds")
      } catch let error {
        print("Failed to invoke the interpreter with error: \(error.localizedDescription)")
        return nil
      }

      let results: [Float]
      switch outputTensor.dataType {
      case .uInt8:
        guard let quantization = outputTensor.quantizationParameters else {
          print("No results returned because the quantization values for the output tensor are nil.")
          return nil
        }
        let quantizedResults = [UInt8](outputTensor.data)
        results = quantizedResults.map {
          quantization.scale * Float(Int($0) - quantization.zeroPoint)
        }
      case .float32:
        results = [Float32](unsafeData: outputTensor.data) ?? []
      default:
        print("Output tensor data type \(outputTensor.dataType) is unsupported for this example app.")
        return nil
      }

      // Process the results.
      let topNInferences = getTopN(results: results)

      // Return the inference time and inference results.
      return Result(inferenceTime: interval, inferences: topNInferences)
    }
    
    // MARK: - Private Methods

    /// Returns the top N inference results sorted in descending order.
    private func getTopN(results: [Float]) -> [Inference] {
      // Create a zipped array of tuples [(labelIndex: Int, confidence: Float)].
      let zippedResults = zip(labels.indices, results)

      // Sort the zipped results by confidence value in descending order.
      let sortedResults = zippedResults.sorted { $0.1 > $1.1 }.prefix(resultCount)

      // Return the `Inference` results.
      //return sortedResults.map { result in Inference(confidence: result.1, label: labels[result.0], ) }
      
        return sortedResults.map { result in Inference(confidence: result.1, label: labels[result.0], className: "", rect: CGRect(x: 0, y: 0, width: 0, height: 0), displayColor: .white) }
    }

}


typealias ObjectClasification = ModelDataHandler

extension ObjectClasification {
    
    /// This class handles all data preprocessing and makes calls to run inference on a given frame
    /// through the `Interpreter`. It then formats the inferences obtained and returns the top N
    /// results for a successful inference.
    func runObjectModel(onFrame pixelBuffer: CVPixelBuffer) -> Result? {
      let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
      let imageHeight = CVPixelBufferGetHeight(pixelBuffer)
      let sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
      assert(sourcePixelFormat == kCVPixelFormatType_32ARGB ||
               sourcePixelFormat == kCVPixelFormatType_32BGRA ||
                 sourcePixelFormat == kCVPixelFormatType_32RGBA)


      let imageChannels = 4
      assert(imageChannels >= inputChannels)

      // Crops the image to the biggest square in the center and scales it down to model dimensions.
      let scaledSize = CGSize(width: inputWidth, height: inputHeight)
      guard let scaledPixelBuffer = pixelBuffer.resized(to: scaledSize) else {
        return nil
      }

      let interval: TimeInterval
      let outputBoundingBox: Tensor
      let outputClasses: Tensor
      let outputScores: Tensor
      let outputCount: Tensor
      do {
        let inputTensor = try interpreter.input(at: 0)
        
        let start = CFAbsoluteTimeGetCurrent()
        // Remove the alpha component from the image buffer to get the RGB data.
        guard let rgbData = rgbDataFromBuffer(
          scaledPixelBuffer,
          byteCount: batchSize * inputWidth * inputHeight * inputChannels,
          isModelQuantized: inputTensor.dataType == .uInt8
        ) else {
          print("Failed to convert the image buffer to RGB data.")
          return nil
        }
        let diff = CFAbsoluteTimeGetCurrent() - start
        print("Object Detection Time Taken During interpreter invoking & getting output  \(diff) seconds")
        // Copy the RGB data to the input `Tensor`.
        try interpreter.copy(rgbData, toInputAt: 0)

        // Run inference by invoking the `Interpreter`.
        let startDate = Date()
        try interpreter.invoke()
        interval = Date().timeIntervalSince(startDate) * 1000

        outputBoundingBox = try interpreter.output(at: 0)
        outputClasses = try interpreter.output(at: 1)
        outputScores = try interpreter.output(at: 2)
        outputCount = try interpreter.output(at: 3)
      } catch let error {
        print("Failed to invoke the interpreter with error: \(error.localizedDescription)")
        return nil
      }

      // Formats the results
      let resultArray = formatResults(
        boundingBox: [Float](unsafeData: outputBoundingBox.data) ?? [],
        outputClasses: [Float](unsafeData: outputClasses.data) ?? [],
        outputScores: [Float](unsafeData: outputScores.data) ?? [],
        outputCount: Int(([Float](unsafeData: outputCount.data) ?? [0])[0]),
        width: CGFloat(imageWidth),
        height: CGFloat(imageHeight)
      )

      // Returns the inference time and inferences
      let result = Result(inferenceTime: interval, inferences: resultArray)
      return result
    }
    
    
    /// Filters out all the results with confidence score < threshold and returns the top N results
    /// sorted in descending order.
    func formatResults(boundingBox: [Float], outputClasses: [Float], outputScores: [Float], outputCount: Int, width: CGFloat, height: CGFloat) -> [Inference]{
      var resultsArray: [Inference] = []
      if (outputCount == 0) {
        return resultsArray
      }
      for i in 0...outputCount - 1 {

        let score = outputScores[i]

        // Filters results with confidence < threshold.
        guard score >= threshold else {
          continue
        }

        // Gets the output class names for detected classes from labels list.
        let outputClassIndex = Int(outputClasses[i])
        let outputClass = labels[outputClassIndex + 1]

        var rect: CGRect = CGRect.zero

        // Translates the detected bounding box to CGRect.
        rect.origin.y = CGFloat(boundingBox[4*i])
        rect.origin.x = CGFloat(boundingBox[4*i+1])
        rect.size.height = CGFloat(boundingBox[4*i+2]) - rect.origin.y
        rect.size.width = CGFloat(boundingBox[4*i+3]) - rect.origin.x

        // The detected corners are for model dimensions. So we scale the rect with respect to the
        // actual image dimensions.
        let newRect = rect.applying(CGAffineTransform(scaleX: width, y: height))

        // Gets the color assigned for the class
        let colorToAssign = colorForClass(withIndex: outputClassIndex + 1)
        let inference = Inference(confidence: score, label: outputClass,
                                  className: outputClass,
                                  rect: newRect,
                                  displayColor: colorToAssign)
        resultsArray.append(inference)
      }

      // Sort results in descending order of confidence.
      resultsArray.sort { (first, second) -> Bool in
        return first.confidence  > second.confidence
      }

      return resultsArray
    }
    
    /// This assigns color for a particular class.
    private func colorForClass(withIndex index: Int) -> UIColor {

      // We have a set of colors and the depending upon a stride, it assigns variations to of the base
      // colors to each object based on its index.
      let baseColor = colors[index % colors.count]

      var colorToAssign = baseColor

      let percentage = CGFloat((colorStrideValue / 2 - index / colors.count) * colorStrideValue)

      if let modifiedColor = baseColor.getModified(byPercentage: percentage) {
        colorToAssign = modifiedColor
      }

      return colorToAssign
    }
}
