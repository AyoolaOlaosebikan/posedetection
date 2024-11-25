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
   // let featureData = ["features": features, "label": label] as [String : Any]

//    let jsonData = try? JSONSerialization.data(withJSONObject: featureData)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        posePicker.delegate = self
        posePicker.dataSource = self
        // Do any additional setup after loading the view.
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

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            captureSession.addOutput(videoOutput)

            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = cameraPreviewView.bounds
            previewLayer.videoGravity = .resizeAspectFill
            cameraPreviewView.layer.addSublayer(previewLayer)
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
    }


    private func processImage(_ image: CGImage) {
            let requestHandler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
            let request = VNDetectHumanBodyPoseRequest()

            do {
                // Perform the request
                try requestHandler.perform([request])
                
                // Process the results
                if let results = request.results, let pose = results.first {
                    currentPoseObservation = pose
                    print("Pose detected!")
                    // Optionally process features here
                }
            } catch {
                print("Error detecting pose: \(error)")
            }
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
    
    func savePoseData(label: String) {
        guard let poseObservation = currentPoseObservation else { return }
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
        guard let url = URL(string: "http://your-server-address/upload") else {
            print("invalid url")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Convert data to JSON
        guard let jsonData = prepareJSON(from: data) else { return }
        
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
        do {
            return try JSONSerialization.data(withJSONObject: data, options: [])
        } catch {
            print("Failed to encode JSON: \(error)")
            return nil
        }
    }
    
    func trainModel() {
        guard let url = URL(string: "http://<YOUR_SERVER_IP>:<PORT>/train_model") else {
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
        guard let url = URL(string: "http://<YOUR_SERVER_IP>:<PORT>/predict_pose") else {
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
    
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let ciImage = CIImage(cvPixelBuffer: pixelBuffer).cgImage else {
            return
        }
        processImage(ciImage)
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
