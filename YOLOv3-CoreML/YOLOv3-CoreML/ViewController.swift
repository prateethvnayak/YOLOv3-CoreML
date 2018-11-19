import UIKit
import Vision
import AVFoundation
import CoreMedia
import VideoToolbox

class ViewController: UIViewController {
  @IBOutlet weak var videoPreview: UIView!
//  @IBOutlet weak var timeLabel: UILabel!
//  @IBOutlet weak var debugImageView: UIImageView!
  // PVN -- flag to mimick semaphore
    var onClickFlag = false
    
  let yolo = YOLO()

  var videoCapture: VideoCapture!

  var boundingBoxes = [BoundingBox]()
  var colors: [UIColor] = []

  let ciContext = CIContext()
  var resizedPixelBuffer: CVPixelBuffer?

  let semaphore = DispatchSemaphore(value: 2)

  override func viewDidLoad() {
    super.viewDidLoad()
//    timeLabel.text = ""

    setUpBoundingBoxes()
    setUpCoreImage()
    setUpCamera()

//    frameCapturingStartTime = CACurrentMediaTime()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    print(#function)
  }
    
  // SGH -- IAB FUNC
    @IBAction func takePhoto(_ sender:Any){
        self.onClickFlag = true
    }
// SGH -- IAB reset
    @IBAction func resetYOLO(_ sender:Any){
        self.videoCapture.start()
        for i in 0..<boundingBoxes.count {
            boundingBoxes[i].hide()
        }
        
    }
    
  // MARK: - Initialization

  func setUpBoundingBoxes() {
    for _ in 0..<YOLO.maxBoundingBoxes {
      boundingBoxes.append(BoundingBox())
    }

    // Make colors for the bounding boxes. There is one color for each class,
    // 80 classes in total.
    for r: CGFloat in [0.2, 0.4, 0.6, 0.8, 1.0] {
      for g: CGFloat in [0.3, 0.7, 0.6, 0.8] {
        for b: CGFloat in [0.4, 0.8, 0.6, 1.0] {
          let color = UIColor(red: r, green: g, blue: b, alpha: 1)
          colors.append(color)
        }
      }
    }
  }

  func setUpCoreImage() {
    let status = CVPixelBufferCreate(nil, YOLO.inputWidth, YOLO.inputHeight,
                                     kCVPixelFormatType_32BGRA, nil,
                                     &resizedPixelBuffer)
    if status != kCVReturnSuccess {
      print("Error: could not create resized pixel buffer", status)
    }
  }
  func setUpCamera() {
    videoCapture = VideoCapture()
    videoCapture.delegate = self
    videoCapture.setUp(sessionPreset: AVCaptureSession.Preset.vga640x480) { success in
      if success {
        // Add the video preview into the UI.
        if let previewLayer = self.videoCapture.previewLayer {
          self.videoPreview.layer.addSublayer(previewLayer)
          self.resizePreviewLayer()
        }

//        // Add the bounding box layers to the UI, on top of the video preview.
        for box in self.boundingBoxes {
          box.addToLayer(self.videoPreview.layer)
        }

        // Once everything is set up, we can start capturing live video.
        self.videoCapture.start()
      }
    }
  }

  //  UI stuff

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    resizePreviewLayer()
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }

  func resizePreviewLayer() {
    videoCapture.previewLayer?.frame = videoPreview.bounds
  }

  // MARK: - Doing inference
  func predict(image: UIImage) {
    if let pixelBuffer = image.pixelBuffer(width: YOLO.inputWidth, height: YOLO.inputHeight) {
      predict(pixelBuffer: pixelBuffer)
    }
  }

  func predict(pixelBuffer: CVPixelBuffer) {
    // Measure how long it takes to predict a single video frame.
//    let startTime = CACurrentMediaTime()

    // Resize the input with Core Image to 416x416.
    guard let resizedPixelBuffer = resizedPixelBuffer else { return }
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let sx = CGFloat(YOLO.inputWidth) / CGFloat(CVPixelBufferGetWidth(pixelBuffer))
    let sy = CGFloat(YOLO.inputHeight) / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
    let scaleTransform = CGAffineTransform(scaleX: sx, y: sy)
    let scaledImage = ciImage.transformed(by: scaleTransform)
    ciContext.render(scaledImage, to: resizedPixelBuffer)

    // This is an alternative way to resize the image (using vImage):
    //if let resizedPixelBuffer = resizePixelBuffer(pixelBuffer,
    //                                              width: YOLO.inputWidth,
    //                                              height: YOLO.inputHeight)

    // Resize the input to 416x416 and give it to our model.
    if let boundingBoxes = try? yolo.predict(image: resizedPixelBuffer) {

      showOnMainThread(boundingBoxes) //, elapsed)
        
    }
  }

    func showOnMainThread(_ boundingBoxes: [YOLO.Prediction]) {
    DispatchQueue.main.async {
      // For debugging, to make sure the resized CVPixelBuffer is correct.
      //var debugImage: CGImage?
      //VTCreateCGImageFromCVPixelBuffer(resizedPixelBuffer, nil, &debugImage)
      //self.debugImageView.image = UIImage(cgImage: debugImage!)

      self.show(predictions: boundingBoxes)

      self.semaphore.signal()
    }
  }

  func show(predictions: [YOLO.Prediction]) {
    // --SGH close if there is detection shut the frame buffer
    if predictions.count > 0 {
        self.onClickFlag = false
        self.videoCapture.stop()
    }
    for i in 0..<boundingBoxes.count {
      if i < predictions.count {
        let prediction = predictions[i]

        // The predicted bounding box is in the coordinate space of the input
        // image, which is a square image of 416x416 pixels. We want to show it
        // on the video preview, which is as wide as the screen and has a 4:3
        // aspect ratio. The video preview also may be letterboxed at the top
        // and bottom.
        let width = view.bounds.width
        let height = width * 4 / 3
        let scaleX = width / CGFloat(YOLO.inputWidth)
        let scaleY = height / CGFloat(YOLO.inputHeight)
        let top = (view.bounds.height - height) / 2

        // Translate and scale the rectangle to our own coordinate system.
        var rect = prediction.rect
        rect.origin.x *= scaleX
        rect.origin.y *= scaleY
        rect.origin.y += top
        rect.size.width *= scaleX
        rect.size.height *= scaleY

        // Show the bounding box.
        let label = String(format: "%@ %.1f", labels[prediction.classIndex], prediction.score * 100)
        let color = colors[prediction.classIndex]
        boundingBoxes[i].show(frame: rect, label: label, color: color)
        
      } else {
        boundingBoxes[i].hide()
      }
    }
  }
}

extension ViewController: VideoCaptureDelegate {
  func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?) { //, timestamp: CMTime
    // For debugging.
    //predict(image: UIImage(named: "dog416")!); return
    
    // PVN -- supplanting semaphaore with the camera capture button press.
    //semaphore.wait()
    
    while(!self.onClickFlag){
        delayWithSeconds(0.01){
            
        }
    }
    
    
    if let pixelBuffer = pixelBuffer {
      // self.onClickFlag = false
      // For better throyughput, perform the prediction on a background queue
      // instead of on the VideoCapture queue. We use the semaphore to block
      // the capture queue and drop frames when Core ML can't keep up.
      DispatchQueue.global().async {
        self.predict(pixelBuffer: pixelBuffer)
        //self.predictUsingVision(pixelBuffer: pixelBuffer)
      }
        
    }
    
    
  }
}
