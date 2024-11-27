//
//  ViewController.swift
//  posedetection
//
//  Created by Ayoola Olaosebikan on 11/20/24.
//

import UIKit
import Vision
import AVFoundation
import Foundation

class ViewController: UIViewController {
    
    let poseRequest = VNDetectHumanBodyPoseRequest()
    @IBOutlet weak var cameraPreviewView: UIView!
    @IBOutlet weak var predictionLabel: UILabel!
    @IBOutlet weak var posePicker: UIPickerView!
    @IBAction func confirmPoseLabel(_ sender: UIButton) {
        print("Countdown")
        countdownTime = 3
        startCountdown()
       // savePoseData(label: selectedPose)
    }
    @IBAction func trainButtonPressed(_ sender: Any) {
        let actionSheet = UIAlertController(title: "Select Model", message: "Choose a machine learning model to use", preferredStyle: .actionSheet)
        
        // Add actions for each model type
        let randomForestAction = UIAlertAction(title: "Random Forest", style: .default) { _ in
            self.trainModel(modelType: "random_forest")
        }
        let xgboostAction = UIAlertAction(title: "XGBoost", style: .default) { _ in
            self.trainModel(modelType: "xgboost")
        }
        let knnAction = UIAlertAction(title: "K-Nearest Neighbors", style: .default) { _ in
            self.trainModel(modelType: "knn")
        }
        
        // Add a cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        // Add actions to the action sheet
        actionSheet.addAction(randomForestAction)
        actionSheet.addAction(xgboostAction)
        actionSheet.addAction(knnAction)
        actionSheet.addAction(cancelAction)
        
        // Present the action sheet
        self.present(actionSheet, animated: true, completion: nil)
    }
    @IBOutlet weak var countdown: UILabel!
    @IBAction func compareButtonTapped(_ sender: UIButton) {
            fetchModelComparisonData { result in
                switch result {
                case .success(let response):
                    // Call method to display data in a popup
                    DispatchQueue.main.async {
                        self.showPopup(with: response)
                    }
                case .failure(let error):
                    // Handle the error
                    print("Error fetching data: \(error.localizedDescription)")
                }
            }
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
    
    var countdownTimer: Timer?
    var countdownTime = 3

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
        countdown.isHidden = true
        countdown.layer.cornerRadius = 20
        countdown.layer.masksToBounds = true

        posePicker.delegate = self
        posePicker.dataSource = self
        // Do any additional setup after loading the view.
    }

    
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
    func startCountdown() {
        // Update UI with initial time remaining
        countdown.isHidden = false
        // Invalidate any existing timer if it exists
        countdownTimer?.invalidate()
        countdown.text = String(countdownTime)

        // Set up a new timer to fire every second
        countdownTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateCountdown), userInfo: nil, repeats: true)
    }
    @objc func updateCountdown() {
            if countdownTime > 0 {
                countdownTime -= 1
                countdown.text = String(countdownTime)
            } else {
                countdownTimer?.invalidate() // Stop the timer
                savePoseData(label: selectedPose) // Save pose data after countdown finishes
                countdown.isHidden = true
                print("Pose saved")
            }
        }
    func savePoseData(label: String) {
   // print("erm")
        guard let poseObservation = currentPoseObservation else {
            //print("why why why why wy")
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
    
    func convertToDecimal(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            var newDict = [String: Any]()
            for (key, val) in dict {
                newDict[key] = convertToDecimal(val)  // Recurse through the dictionary
            }
            return newDict
        } else if let array = value as? [Any] {
            return array.map { convertToDecimal($0) }  // Recurse through the array
        } else if let number = value as? Double {
            return Decimal(number)  // Convert Double to Decimal
        }
        return value  // Return the value as-is if it's not a Double
    }
    
    func prepareJSON(from data: [String: Any]) -> Data? {
        var sanitizedData = data
        // Sanitize nested data (like "features")
        if var features = data["features"] as? [String: Any] {
            for (key, value) in features {
                if let number = value as? Double {
                    if number.isNaN {
                        print("cleaning \(features[key] ?? 0)")
                        features[key] = Decimal(0.0) // Replace NaN with 0.0 or a default value
                        print("nan value is now \(features[key] ?? 0)")
                    } else {
                        features[key] = Decimal(number)
                    }
                }
            }
            sanitizedData["features"] = features
        }
        
        sanitizedData = convertToDecimal(sanitizedData) as! [String: Any]
        
        do {
            return try JSONSerialization.data(withJSONObject: sanitizedData, options: [])
        } catch {
            print("Failed to encode JSON: \(error)")
            return nil
        }
    }
    
    func trainModel(modelType: String) {
        guard let url = URL(string: "http://10.9.159.255:8000/train_model?model_type=\(modelType)") else {
            print("Invalid server URL")
            return
        }
        
        // Create URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
//        let modelType = "random_forest"
//        let body: [String: Any] = ["model_type": modelType]
//        do {
//            let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
//            request.httpBody = jsonData
//        } catch {
//            print("Error encoding JSON: \(error)")
//            return
//        }
        
        // Set content type
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Send the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error training model: \(error)")
                return
            }
            
            if let data = data {
                do {
                    if let responseDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        print("Training response: \(responseDict)")
                    }
                } catch {
                    print("Error decoding response JSON: \(error)")
                }
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
        if !validateFeatures(features) {
            //print("Invalid features detected: \(features)")
            return
        }
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
                //print("Prediction response: \(responseDict["prediction"] ?? "nun")")
                
                DispatchQueue.main.async {
                    if let prediction = responseDict["prediction"] as? [String],
                    let firstPrediction = prediction.first {
                    let cleanedPrediction = firstPrediction.trimmingCharacters(in: CharacterSet(charactersIn: "() \n"))
                        if (cleanedPrediction != "") {
                            self.predictionLabel.text = cleanedPrediction
                        } else {
                            self.predictionLabel.text = "No pose identified"
                        }
                    }
                }
            }
        }
        task.resume()
    }
    
    func validateFeatures(_ features: [String: Double]) -> Bool {
        for (_, value) in features {
            if value.isNaN || value.isInfinite {
                return false
            }
        }
        return true
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
        //print("hiiiooo")
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        let request = VNDetectHumanBodyPoseRequest()
        
        do {
            try requestHandler.perform([request])
            if let results = request.results {
               // print("Detected \(results.count) pose(s)")
                if let firstPose = results.first {
                    currentPoseObservation = firstPose
                    guard let poseObservation = currentPoseObservation else {
                        //print("why why why why wy")
                        return
                    }
                    let features = extractFeatures(from: poseObservation)
                    predictPose(features: features)
                    
               //     print("Pose detected: \(firstPose)")
                } else {
                //    print("No pose in results")
                }
            } else {
               // print("No results from request")
            }
        } catch {
            print("Error detecting pose: \(error)")
        }
    }
    func showPopup(with response: String) {
        // Create an alert to display the raw JSON response
        let alertController = UIAlertController(title: "Model Comparison", message: response, preferredStyle: .alert)
        
        // Add "OK" button to close the popup
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        
        // Present the alert
        self.present(alertController, animated: true, completion: nil)
    }

    func fetchModelComparisonData(completion: @escaping (Result<String, Error>) -> Void) {
        let urlString = "http://10.9.159.255:8000/compare_models"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Perform the GET request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle errors
            if let error = error {
                print("Error fetching data: \(error.localizedDescription)")
                completion(.failure(error))  // Call completion handler with error
                return
            }
            
            // Ensure we have data
            guard let data = data else {
                print("No data received")
                return
            }
            
            // Convert the data to a string and pass it back
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Received response: \(jsonString)")
                completion(.success(jsonString))  // Return the raw JSON string
            } else {
                print("Failed to convert data to string")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert data to string"])))
            }
        }
        
        task.resume()  // Start the task
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            
            return
        }
        
        processImage(pixelBuffer)
        //print("process image")
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



    

