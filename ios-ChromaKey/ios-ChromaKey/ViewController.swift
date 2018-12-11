//
//  ViewController.swift
//  ios-ChromaKey
//
//  Created by Alexandr Nadtoka on 12/6/18.
//  Copyright © 2018 kreatimont. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class ViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    
    let imagePickerController = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        if PHPhotoLibrary.authorizationStatus() != .authorized {
//            PHPhotoLibrary.requestAuthorization { status in
//                guard status == .authorized else { return }
//            }
//        }
        
    }
    
    @IBAction func handlePickVideo(_ sender: Any) {
        self.loadVideoFromGallery()
    }
    
    func loadVideoFromGallery() {
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        imagePickerController.mediaTypes = ["public.movie"]
        
        self.present(imagePickerController, animated: true, completion: nil)
    }
    
    func extractFrames(url: URL, fps: Int = 24) {
        DispatchQueue.global().async {
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.requestedTimeToleranceAfter = .zero
            imageGenerator.requestedTimeToleranceBefore = .zero
            
            print("Seconds: \(asset.duration.seconds)")
            
            var cmTimes = [CMTime]()
            var frameForTimes = [NSValue]()
            let sampleCounts = Int(asset.duration.seconds) * fps
            let totalTimeLength = Int(asset.duration.seconds * Double(asset.duration.timescale))
            let step = totalTimeLength / sampleCounts
            
            for i in 0 ..< sampleCounts {
                let cmTime = CMTime(value: CMTimeValue(i * step), timescale: asset.duration.timescale)
                cmTimes.append(cmTime)
                frameForTimes.append(NSValue(time: cmTime))
            }

//            Async way
//            var savedCount = 0
//            imageGenerator.generateCGImagesAsynchronously(forTimes: frameForTimes, completionHandler: { (reqTime, imageRef, actualTime, res, error) in
//                savedCount += 1
//                if let cgImage = imageRef {
//                    UIImageWriteToSavedPhotosAlbum(UIImage(cgImage: cgImage), nil, nil, nil)
//                }
//            })
            
            var images = [UIImage]()
            for cmTime in cmTimes {
                if let imageRef = try? imageGenerator.copyCGImage(at: cmTime, actualTime: nil) {
                    if let image = self.changeImageBG(cgImage: imageRef) {
                        DispatchQueue.main.async {
                            self.imageView.image = image
                        }
                        images.append(image)
                    }
                    
                }
            }
            

            let settings = RenderSettings()
            let imageAnimator = ImageAnimator(renderSettings: settings, images: images)
            imageAnimator.render() {
                DispatchQueue.main.async {
                    self.imageView.image = images.first
                }
                print("successfully rendered images")
            }
            
        }
    }

    let ciContext = CIContext()
    func changeImageBG(cgImage: CGImage) -> UIImage? {
        let foregroundCIImage = CIImage(cgImage: cgImage)
        
        guard let backgroundImage = UIImage(named: "bgKeyboard"), let backgroundCGImage = backgroundImage.cgImage else {
            return nil
        }
        
        let backgroundCIImage = CIImage(cgImage: backgroundCGImage)
        
        let chromaCIFilter = self.chromaKeyFilter(fromHue: 0.20, toHue: 0.55)
        chromaCIFilter?.setValue(foregroundCIImage, forKey: kCIInputImageKey)
        let sourceCIImageWithoutBackground = chromaCIFilter?.outputImage
        
        let compositor = CIFilter(name:"CISourceOverCompositing")
        compositor?.setValue(sourceCIImageWithoutBackground, forKey: kCIInputImageKey)
        compositor?.setValue(backgroundCIImage, forKey: kCIInputBackgroundImageKey)
        if let compositedCIImage = compositor?.outputImage {
            
            if let cgRef = ciContext.createCGImage(compositedCIImage, from: compositedCIImage.extent) {
                return UIImage(cgImage: cgRef)
            }
            return UIImage(ciImage: compositedCIImage)
        }
        return nil
    }
    
    func startProccedSingleImage() {
        guard let foregroundImage = UIImage(named: "me"), let foregroundCGImage = foregroundImage.cgImage else {
            return
        }
        
        let foregroundCIImage = CIImage(cgImage: foregroundCGImage)
        
        guard let backgroundImage = UIImage(named: "background"), let backgroundCGImage = backgroundImage.cgImage else {
            return
        }
        
        let backgroundCIImage = CIImage(cgImage: backgroundCGImage)
        
        
        let chromaCIFilter = self.chromaKeyFilter(fromHue: 0.3, toHue: 0.4)
        chromaCIFilter?.setValue(foregroundCIImage, forKey: kCIInputImageKey)
        let sourceCIImageWithoutBackground = chromaCIFilter?.outputImage
        
        let compositor = CIFilter(name:"CISourceOverCompositing")
        compositor?.setValue(sourceCIImageWithoutBackground, forKey: kCIInputImageKey)
        compositor?.setValue(backgroundCIImage, forKey: kCIInputBackgroundImageKey)
        if let compositedCIImage = compositor?.outputImage {
            self.imageView.image = UIImage(ciImage: compositedCIImage)
        }
    }

    //Chroma Key implementation
    
    func chromaKeyFilter(fromHue: CGFloat, toHue: CGFloat) -> CIFilter? {
        // 1
        let size = 64
        var cubeRGB = [Float]()
        
        // 2
        for z in 0 ..< size {
            let blue = CGFloat(z) / CGFloat(size-1)
            for y in 0 ..< size {
                let green = CGFloat(y) / CGFloat(size-1)
                for x in 0 ..< size {
                    let red = CGFloat(x) / CGFloat(size-1)
                    
                    // 3
                    let hue = getHue(red: red, green: green, blue: blue)
                    let alpha: CGFloat = (hue >= fromHue && hue <= toHue) ? 0: 1
                    
                    // 4
                    cubeRGB.append(Float(red * alpha))
                    cubeRGB.append(Float(green * alpha))
                    cubeRGB.append(Float(blue * alpha))
                    cubeRGB.append(Float(alpha))
                }
            }
        }
        
        let data = Data(buffer: UnsafeBufferPointer(start: &cubeRGB, count: cubeRGB.count))
        
        // 5
        let colorCubeFilter = CIFilter(name: "CIColorCube", parameters: ["inputCubeDimension": size, "inputCubeData": data])
        return colorCubeFilter
    }
    
    func getHue(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGFloat {
        let color = UIColor(red: red, green: green, blue: blue, alpha: 1)
        var hue: CGFloat = 0
        color.getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
        return hue
    }

}


extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        if let videoURL = info[UIImagePickerController.InfoKey.mediaURL] as? URL {
            self.extractFrames(url: videoURL, fps: 24)
        }
        
    }
    
}
