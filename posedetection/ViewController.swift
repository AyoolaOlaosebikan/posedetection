//
//  ViewController.swift
//  posedetection
//
//  Created by Ayoola Olaosebikan on 11/20/24.
//

import UIKit
import Vision
import AVFoundation

class ViewController: UIViewController {
    
    let poseRequest = VNDetectHumanBodyPoseRequest()
    @IBOutlet weak var cameraPreviewView: UIView!
    @IBOutlet weak var posePicker: UIPickerView!
    @IBAction func confirmPoseLabel(_ sender: UIButton) {
        print("balls")
        savePoseData(label: selectedPose)
    }
    @IBAction func trainButtonPressed(_ sender: Any) {
        trainModel()
    }
    
    var currentPoseObservation: VNHumanBodyPoseObservation?

    let poses = ["Front Double Biceps", "Side Chest", "Back Double Biceps"]
    var selectedPose = ""
    
    //pose landmarks for saving type shit
    let poseLabels = ["Front Double Biceps", "Side Chest", "Back Double Biceps"]
    
    let features = ["Left Arm Angle": 120, "Right Arm Angle": 110]
    let label = "Front Double Biceps"
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    var session: AVCaptureSession?
    var videoDataOutput: AVCaptureVideoDataOutput?
    var videoDataOutputQueue: DispatchQueue?
    var captureDevice: AVCaptureDevice?
    lazy var sequenceRequestHandler = VNSequenceRequestHandler()


    var rootLayer: CALayer?
    var detectionOverlayLayer: CALayer?
    var detectedFaceRectangleShapeLayer: CAShapeLayer?
    var detectedEyebrowRectangleShapeLayer: CAShapeLayer?
    var captureDeviceResolution: CGSize = CGSize()

    private var detectionRequests: [VNDetectHumanBodyPoseRequest]?
    private var trackingRequests: [VNTrackObjectRequest]?
   // let featureData = ["features": features, "label": label] as [String : Any]

//    let jsonData = try? JSONSerialization.data(withJSONObject: featureData)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        //self.session = self.setupAVCaptureSession()
        //self.prepareVisionRequest()
        //self.session?.startRunning()

        posePicker.delegate = self
        posePicker.dataSource = self
        // Do any additional setup after loading the view.
    }
//    override func didReceiveMemoryWarning() {
//        super.didReceiveMemoryWarning()
//    }
//    
//    // Ensure that the interface stays locked in Portrait.
//    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
//        return .portrait
//    }
//    
//    // Ensure that the interface stays locked in Portrait.
//    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
//        return .portrait
//    }
//
//    fileprivate func prepareVisionRequest() {
//        
//        self.trackingRequests = []
//        
//        // create a detection request that processes an image and returns face features
//        // completion handler does not run immediately, it is run
//        // after a face is detected
//        let bodyDetectionRequest = VNDetectHumanBodyPoseRequest { [weak self] request, error in
//            self?.bodyDetectionCompletionHandler(request: request, error: error)
//        }
//        // Save this detection request for later processing
//        self.detectionRequests = [bodyDetectionRequest]
//        
//        // setup the tracking of a sequence of features from detection
//        self.sequenceRequestHandler = VNSequenceRequestHandler()
//        
//        // setup drawing layers for showing output of body detection
//        self.setupVisionDrawingLayers()
//    }
//    
//    func bodyDetectionCompletionHandler(request:VNRequest, error: Error?){
//        // any errors? If yes, show and try to keep going
//        if error != nil {
//            print("bodyDetection error: \(String(describing: error)).")
//        }
//        
//        // see if we can get any face features, this will fail if no faces detected
//        // try to save the face observations to a results vector
//        guard let bodyDetectionRequest = request as? VNDetectHumanBodyPoseRequest,
//            let results = bodyDetectionRequest.results as? [VNHumanBodyPoseObservation] else {
//                return
//        }
//        
//        if !results.isEmpty{
//            print("Initial body found... setting up tracking.")
//            
//            
//        }
//        
//        // if we got here, then a face was detected and we have its features saved
//        // The above face detection was the most computational part of what we did
//        // the remaining tracking only needs the results vector of face features
//        // so we can process it in the main queue (because we will us it to update UI)
//        DispatchQueue.main.async {
//            // Add the body limbs to the tracking list
//            for observation in results {
//                let bodyTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
//                // the array starts empty, but this will constantly add to it
//                // since on the main queue, there are no race conditions
//                // everything is from a single thread
//                // once we add this, it kicks off tracking in another function
//                self.trackingRequests?.append(bodyTrackingRequest)
//                
//                // NOTE: if the initial face detection is actually not a face,
//                // then the app will continually mess up trying to perform tracking
//            }
//        }
//        
//    }
    private func handlePoseObservation(_ observation: VNHumanBodyPoseObservation) {
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else { return }
        
        let leftWrist = recognizedPoints[.leftWrist]
        let leftElbow = recognizedPoints[.leftElbow]
        let leftShoulder = recognizedPoints[.leftShoulder]

        if let wrist = leftWrist?.location,
           let elbow = leftElbow?.location,
           let shoulder = leftShoulder?.location {
            let angle = calculateAngle(pointA: wrist, pointB: elbow, pointC: shoulder)
            print("Left Arm Angle: \(angle)°")
        }
    }
    
    private func calculateAngle(pointA: CGPoint?, pointB: CGPoint?, pointC: CGPoint?) -> CGFloat {
        guard let pointA = pointA, let pointB = pointB, let pointC = pointC else {
            print("One or more points are nil")
            return 0
        }
        
        let vector1 = CGVector(dx: pointB.x - pointA.x, dy: pointB.y - pointA.y)
        let vector2 = CGVector(dx: pointC.x - pointB.x, dy: pointC.y - pointB.y)
        let dotProduct = vector1.dx * vector2.dx + vector1.dy * vector2.dy
        let magnitude1 = sqrt(vector1.dx * vector1.dx + vector1.dy * vector1.dy)
        let magnitude2 = sqrt(vector2.dx * vector2.dx + vector2.dy * vector2.dy)
        return acos(dotProduct / (magnitude1 * magnitude2)) * 180 / .pi
    }
    
    private func drawKeyPoint(at point: CGPoint) {
        let dot = UIView(frame: CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5))
        dot.backgroundColor = .red
        dot.layer.cornerRadius = 2.5
        view.addSubview(dot)
    }
    
    func savePoseData(label: String) {
    print("erm")
        guard let poseObservation = currentPoseObservation else { 
            print("why why why why wy")
            return
        }
        let features = extractFeatures(from: poseObservation)
        let featureData = [
            "features": features,
            "label": label
        ] as [String: Any]
        uploadDataToServer(data: featureData)
    }

    func extractFeatures(from observation: VNHumanBodyPoseObservation) -> [String: Double] {
        guard let points = try? observation.recognizedPoints(.all) else { return [:] }

        // Example: Calculate arm angles
        let leftArmAngle = calculateAngle(
            pointA: points[.leftWrist]?.location,
            pointB: points[.leftElbow]?.location,
            pointC: points[.leftShoulder]?.location
        )
        let rightArmAngle = calculateAngle(
            pointA: points[.rightWrist]?.location,
            pointB: points[.rightElbow]?.location,
            pointC: points[.rightShoulder]?.location
        )

        return [
            "LeftArmAngle": leftArmAngle,
            "RightArmAngle": rightArmAngle
        ]
    }
    
    func uploadDataToServer(data: [String: Any]) {
        print("why why why why wy")

        guard let url = URL(string: "http://10.9.159.255:8000/upload_pose") else {
            print("invalid url")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Convert data to JSON
        print("Data to upload: \(data)")
        guard let jsonData = prepareJSON(from: data) else {
            print("JSON prep failed")
            return
        }
        
        request.httpBody = jsonData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error uploading data: \(error.localizedDescription)")
                return
            }
            
            if let response = response as? HTTPURLResponse {
                print("Server response: \(response.statusCode)")
            }
            print("Data uploaded successfully!")
        }
        task.resume()
    }
    
    func prepareJSON(from data: [String: Any]) -> Data? {
        var sanitizedData = data
        // Sanitize nested data (like "features")
        if var features = data["features"] as? [String: Any] {
            for (key, value) in features {
                if let number = value as? Double, number.isNaN {
                    features[key] = 0.0 // Replace NaN with 0.0 or a default value
                }
            }
            sanitizedData["features"] = features
        }
    
        do {
            return try JSONSerialization.data(withJSONObject: data, options: [])
        } catch {
            print("Failed to encode JSON: \(error)")
            return nil
        }
    }
    
    func trainModel() {
        guard let url = URL(string: "http://10.9.159.255:8000/train_model") else {
            print("Invalid server URL")
            return
        }

        // Create URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Send the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error training model: \(error)")
                return
            }

            if let data = data,
               let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("Training response: \(responseDict)")
            }
        }
        task.resume()
    }
    
    func predictPose(features: [String: Double]) {
        guard let url = URL(string: "http://10.9.159.255:8000/predict_pose") else {
            print("Invalid server URL")
            return
        }

        // Prepare JSON data
        let predictionData = ["features": features]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: predictionData) else {
            print("Failed to encode JSON")
            return
        }

        // Create URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        // Send the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error predicting pose: \(error)")
                return
            }

            if let data = data,
               let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("Prediction response: \(responseDict)")
            }
        }
        task.resume()
    }
    private func setupCamera() {
        let captureSession = AVCaptureSession()
            captureSession.sessionPreset = .medium

            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  captureSession.canAddInput(videoInput) else {
                print("Failed to access camera")
                return
            }
            captureSession.addInput(videoInput)
            print("Video input added to session")

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
                print("Video output added to session")
            } else {
                print("Failed to add video output")
            }
        
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = cameraPreviewView.bounds
            previewLayer.videoGravity = .resizeAspectFill
            cameraPreviewView.layer.addSublayer(previewLayer)
        
            DispatchQueue.global(qos: .background).async {
                captureSession.startRunning()
                print("Capture session started")
            }
    }


    private func processImage(_ pixelBuffer: CVPixelBuffer) {
        print("hiiiooo")
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        let request = VNDetectHumanBodyPoseRequest()
        
        do {
            try requestHandler.perform([request])
            if let results = request.results {
                print("Detected \(results.count) pose(s)")
                if let firstPose = results.first {
                    currentPoseObservation = firstPose
                    print("Pose detected: \(firstPose)")
                } else {
                    print("No pose in results")
                }
            } else {
                print("No results from request")
            }
        } catch {
            print("Error detecting pose: \(error)")
        }
    }
    
    private func drawKeypoints(_ points: [VNRecognizedPoint]) {
        for point in points {
            if point.confidence > 0.5 {
                let normalized = point.location
                let x = normalized.x * cameraPreviewView.bounds.width
                let y = (1 - normalized.y) * cameraPreviewView.bounds.height // Flip y-axis
                let circleView = UIView(frame: CGRect(x: x, y: y, width: 10, height: 10))
                circleView.backgroundColor = .red
                circleView.layer.cornerRadius = 5
                cameraPreviewView.addSubview(circleView)
            }
        }
    }

    private func drawCircle(at point: CGPoint) {
        let circleLayer = CAShapeLayer()
        circleLayer.frame = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
        circleLayer.cornerRadius = 5
        circleLayer.backgroundColor = UIColor.red.cgColor
        cameraPreviewView.layer.addSublayer(circleLayer)
    }

    private func clearLandmarkLayers() {
        for sublayer in cameraPreviewView.layer.sublayers ?? [] {
            if let shapeLayer = sublayer as? CAShapeLayer {
                shapeLayer.removeFromSuperlayer()
            }
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            
            return
        }
        processImage(pixelBuffer)
        print("process image")
    }
}
extension ViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return poses.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return poses[row]
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedPose = poses[row]
    }
}
////from eric larson
//extension UIViewController{
//    
//    // Helper Methods for Error Presentation
//    
//    fileprivate func presentErrorAlert(withTitle title: String = "Unexpected Failure", message: String) {
//        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
//        self.present(alertController, animated: true)
//    }
//    
//    fileprivate func presentError(_ error: NSError) {
//        self.presentErrorAlert(withTitle: "Failed with error \(error.code)", message: error.localizedDescription)
//    }
//    
//    // Helper Methods for Handling Device Orientation & EXIF
//    
//    fileprivate func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
//        return CGFloat(Double(degrees) * Double.pi / 180.0)
//    }
//    
//    func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
//        
//        switch deviceOrientation {
//        case .portraitUpsideDown:
//            return .rightMirrored
//            
//        case .landscapeLeft:
//            return .downMirrored
//            
//        case .landscapeRight:
//            return .upMirrored
//            
//        default:
//            return .leftMirrored
//        }
//    }
//    
//    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
//        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
//    }
//}
//
//extension ViewController {
//    
//    
//    fileprivate func setupVisionDrawingLayers() {
//        let captureDeviceResolution = self.captureDeviceResolution
//        
//        let captureDeviceBounds = CGRect(x: 0,
//                                         y: 0,
//                                         width: captureDeviceResolution.width,
//                                         height: captureDeviceResolution.height)
//        
//        let captureDeviceBoundsCenterPoint = CGPoint(x: captureDeviceBounds.midX,
//                                                     y: captureDeviceBounds.midY)
//        
//        let normalizedCenterPoint = CGPoint(x: 0.5, y: 0.5)
//        
//        guard let rootLayer = self.rootLayer else {
//            self.presentErrorAlert(message: "view was not property initialized")
//            return
//        }
//        
//        let overlayLayer = CALayer()
//        overlayLayer.name = "DetectionOverlay"
//        overlayLayer.masksToBounds = true
//        overlayLayer.anchorPoint = normalizedCenterPoint
//        overlayLayer.bounds = captureDeviceBounds
//        overlayLayer.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
//        
//        let faceRectangleShapeLayer = CAShapeLayer()
//        faceRectangleShapeLayer.name = "RectangleOutlineLayer"
//        faceRectangleShapeLayer.bounds = captureDeviceBounds
//        faceRectangleShapeLayer.anchorPoint = normalizedCenterPoint
//        faceRectangleShapeLayer.position = captureDeviceBoundsCenterPoint
//        faceRectangleShapeLayer.fillColor = nil
//        faceRectangleShapeLayer.strokeColor = UIColor.green.withAlphaComponent(0.7).cgColor
//        faceRectangleShapeLayer.lineWidth = 5
//        faceRectangleShapeLayer.shadowOpacity = 0.7
//        faceRectangleShapeLayer.shadowRadius = 5
//        
//        let faceLandmarksShapeLayer = CAShapeLayer()
//        faceLandmarksShapeLayer.name = "FaceLandmarksLayer"
//        faceLandmarksShapeLayer.bounds = captureDeviceBounds
//        faceLandmarksShapeLayer.anchorPoint = normalizedCenterPoint
//        faceLandmarksShapeLayer.position = captureDeviceBoundsCenterPoint
//        faceLandmarksShapeLayer.fillColor = nil
//        faceLandmarksShapeLayer.strokeColor = UIColor.yellow.withAlphaComponent(0.7).cgColor
//        faceLandmarksShapeLayer.lineWidth = 3
//        faceLandmarksShapeLayer.shadowOpacity = 0.7
//        faceLandmarksShapeLayer.shadowRadius = 5
//        
//        let eyebrowRectangleShapeLayer = CAShapeLayer()
//        eyebrowRectangleShapeLayer.name = "EyebrowBounds"
//        eyebrowRectangleShapeLayer.bounds = captureDeviceBounds
//        eyebrowRectangleShapeLayer.anchorPoint = normalizedCenterPoint
//        eyebrowRectangleShapeLayer.position = captureDeviceBoundsCenterPoint
//        eyebrowRectangleShapeLayer.fillColor = UIColor.red.withAlphaComponent(0.3).cgColor
//        eyebrowRectangleShapeLayer.strokeColor = UIColor.red.withAlphaComponent(0.7).cgColor
//        eyebrowRectangleShapeLayer.lineWidth = 5
//        eyebrowRectangleShapeLayer.shadowOpacity = 0.7
//        eyebrowRectangleShapeLayer.shadowRadius = 5
//        
//        overlayLayer.addSublayer(faceRectangleShapeLayer)
//        faceRectangleShapeLayer.addSublayer(faceLandmarksShapeLayer)
//        faceRectangleShapeLayer.addSublayer(eyebrowRectangleShapeLayer)
//        rootLayer.addSublayer(overlayLayer)
//        
//        self.detectionOverlayLayer = overlayLayer
//        self.detectedFaceRectangleShapeLayer = faceRectangleShapeLayer
//        // self.detectedFaceLandmarksShapeLayer = faceLandmarksShapeLayer
//        self.detectedEyebrowRectangleShapeLayer = eyebrowRectangleShapeLayer
//        self.updateLayerGeometry()
//    }
//    
//    fileprivate func updateLayerGeometry() {
//        guard let overlayLayer = self.detectionOverlayLayer,
//            let rootLayer = self.rootLayer,
//            let previewLayer = self.previewLayer
//            else {
//            return
//        }
//        
//        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)
//        
//        let videoPreviewRect = previewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
//        
//        var rotation: CGFloat
//        var scaleX: CGFloat
//        var scaleY: CGFloat
//        
//        // Rotate the layer into screen orientation.
//        switch UIDevice.current.orientation {
//        case .portraitUpsideDown:
//            rotation = 180
//            scaleX = videoPreviewRect.width / captureDeviceResolution.width
//            scaleY = videoPreviewRect.height / captureDeviceResolution.height
//            
//        case .landscapeLeft:
//            rotation = 90
//            scaleX = videoPreviewRect.height / captureDeviceResolution.width
//            scaleY = scaleX
//            
//        case .landscapeRight:
//            rotation = -90
//            scaleX = videoPreviewRect.height / captureDeviceResolution.width
//            scaleY = scaleX
//            
//        default:
//            rotation = 0
//            scaleX = videoPreviewRect.width / captureDeviceResolution.width
//            scaleY = videoPreviewRect.height / captureDeviceResolution.height
//        }
//        
//        // Scale and mirror the image to ensure upright presentation.
//        let affineTransform = CGAffineTransform(rotationAngle: radiansForDegrees(rotation))
//            .scaledBy(x: scaleX, y: -scaleY)
//        overlayLayer.setAffineTransform(affineTransform)
//        
//        // Cover entire screen UI.
//        let rootLayerBounds = rootLayer.bounds
//        overlayLayer.position = CGPoint(x: rootLayerBounds.midX, y: rootLayerBounds.midY)
//    }
//    
//    fileprivate func addPoints(in landmarkRegion: VNFaceLandmarkRegion2D, to path: CGMutablePath, applying affineTransform: CGAffineTransform, closingWhenComplete closePath: Bool) {
//        let pointCount = landmarkRegion.pointCount
//        if pointCount > 1 {
//            let points: [CGPoint] = landmarkRegion.normalizedPoints
//            path.move(to: points[0], transform: affineTransform)
//            path.addLines(between: points, transform: affineTransform)
//            if closePath {
//                path.addLine(to: points[0], transform: affineTransform)
//                path.closeSubpath()
//            }
//        }
//    }
//    
//    fileprivate func addIndicators(to faceRectanglePath: CGMutablePath, faceLandmarksPath: CGMutablePath, for faceObservation: VNFaceObservation) {
//        let displaySize = self.captureDeviceResolution
//        
//        let faceBounds = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(displaySize.width), Int(displaySize.height))
//        faceRectanglePath.addRect(faceBounds)
//        
//        if let landmarks = faceObservation.landmarks {
//            // Landmarks are relative to -- and normalized within --- face bounds
//            let affineTransform = CGAffineTransform(translationX: faceBounds.origin.x, y: faceBounds.origin.y)
//                .scaledBy(x: faceBounds.size.width, y: faceBounds.size.height)
//            
//            // Treat eyebrows and lines as open-ended regions when drawing paths.
//            let openLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
//                landmarks.leftEyebrow,
//                landmarks.rightEyebrow,
//                landmarks.faceContour,
//                landmarks.noseCrest,
//                landmarks.medianLine
//            ]
//            for openLandmarkRegion in openLandmarkRegions where openLandmarkRegion != nil {
//                self.addPoints(in: openLandmarkRegion!, to: faceLandmarksPath, applying: affineTransform, closingWhenComplete: false)
//            }
//            
//            // Draw eyes, lips, and nose as closed regions.
//            let closedLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
//                landmarks.leftEye,
//                landmarks.rightEye,
//                landmarks.outerLips,
//                landmarks.innerLips,
//                landmarks.nose
//            ]
//            for closedLandmarkRegion in closedLandmarkRegions where closedLandmarkRegion != nil {
//                self.addPoints(in: closedLandmarkRegion!, to: faceLandmarksPath, applying: affineTransform, closingWhenComplete: true)
//            }
//        }
//    }
//    //custom function similar to above that only highlights the eyebrows
//    fileprivate func addBrowIndicators(to faceRectanglePath: CGMutablePath, faceLandmarksPath: CGMutablePath, for faceObservation: VNFaceObservation) {
//        let displaySize = self.captureDeviceResolution
//        
//        let faceBounds = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(displaySize.width), Int(displaySize.height))
//        faceRectanglePath.addRect(faceBounds)
//        
//        if let landmarks = faceObservation.landmarks {
//            // Landmarks are relative to -- and normalized within --- face bounds
//            let affineTransform = CGAffineTransform(translationX: faceBounds.origin.x, y: faceBounds.origin.y)
//                .scaledBy(x: faceBounds.size.width, y: faceBounds.size.height)
//            
//            let eyebrowRegions: [VNFaceLandmarkRegion2D?] = [
//                landmarks.leftEyebrow,
//                landmarks.rightEyebrow
//                
//            ]
//            
//            for eyebrowRegion in eyebrowRegions where eyebrowRegion != nil {
//                        // Add points in eyebrow region to path without closing the path
//                        self.addPoints(in: eyebrowRegion!, to: faceLandmarksPath, applying: affineTransform, closingWhenComplete: false)
//                    }
//        }
//    }
//    
//    /// - Tag: DrawPaths
//    fileprivate func drawFaceObservations(_ faceObservations: [VNFaceObservation]) {
//        guard let faceRectangleShapeLayer = self.detectedFaceRectangleShapeLayer,
//            //let faceLandmarksShapeLayer = self.detectedFaceLandmarksShapeLayer,
//            let eyebrowRectangeShapeLayer = self.detectedEyebrowRectangleShapeLayer
//            else {
//            return
//        }
//        
//        CATransaction.begin()
//        
//        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)
//        
//        let faceRectanglePath = CGMutablePath()
//        let faceLandmarksPath = CGMutablePath()
//        let browLandmarksPath = CGMutablePath()
//        
//        for faceObservation in faceObservations {
//            self.addIndicators(to: faceRectanglePath,
//                               faceLandmarksPath: faceLandmarksPath,
//                               for: faceObservation)
//            self.addBrowIndicators(to: faceRectanglePath, faceLandmarksPath: browLandmarksPath, for: faceObservation)
//        }
//        //commented out the other highlights
//        //faceRectangleShapeLayer.path = faceRectanglePath
//       // faceLandmarksShapeLayer.path = faceLandmarksPath
//        eyebrowRectangeShapeLayer.path = browLandmarksPath
//        
//        self.updateLayerGeometry()
//        
//        CATransaction.commit()
//    }
//}
//
//



    

