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

    //views
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var secondImageView: UIImageView!
    @IBOutlet weak var mergeButton: UIButton!
    @IBOutlet weak var maxXField: UITextField!
    @IBOutlet weak var maxYField: UITextField!
    
    //var
    
    let imagePickerController = UIImagePickerController()
    
    var fgURL: URL?
    var bgURL: URL?
    
    var selectingFirst = false
    var selectingSecond = false
    
    var indicator: UIActivityIndicatorView?
    
    //lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        FilesHelper.instance.clearImages()
        
        if PHPhotoLibrary.authorizationStatus() != .authorized {
            PHPhotoLibrary.requestAuthorization { status in
            }
        }
        
        self.mergeButton.isHidden = true
     
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
    }
    
    //actions
    
    @IBAction func handlePickVideo(_ sender: Any) {
        self.loadVideoFromGallery()
    }
    
    @IBAction func handleSecondPickVideo(_ sender: Any) {
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        imagePickerController.mediaTypes = ["public.movie"]
        
        self.present(imagePickerController, animated: true, completion: nil)
        self.selectingSecond = true
    }
    
    @IBAction func handleMerge(_ sender: Any) {
        if let fg = self.fgURL, let bg = self.bgURL {
            
            var maxX = 1000
            var maxY = 550
            
            if let maxXStr = self.maxXField.text, let maxXInt = Int(maxXStr) {
                maxX = maxXInt
            }
            
            if let maxYStr = self.maxYField.text, let maxYInt = Int(maxYStr) {
                maxY = maxYInt
            }
            
            let activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
            activityIndicator.frame = self.view.bounds
            activityIndicator.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            self.view.addSubview(activityIndicator)
            activityIndicator.startAnimating()
            
            self.indicator = activityIndicator
            
            self.extractFrames(url: fg, bgURL: bg, size: CGSize(width: maxX, height: maxY))
        }
    }
    
    //working with videos code
    
    func extractThumbnailFromVideo(url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        if let imageRef = try? imageGenerator.copyCGImage(at: CMTime(value: CMTimeValue(12), timescale: asset.duration.timescale), actualTime: nil) {
            return UIImage(cgImage: imageRef)
        }
        return nil
    }
    
    func loadVideoFromGallery() {
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        imagePickerController.mediaTypes = ["public.movie"]
        
        self.present(imagePickerController, animated: true, completion: nil)
        self.selectingFirst = true
    }
    
    func extractFrames(url: URL, bgURL: URL, fps: Int = 24, size: CGSize) {
        DispatchQueue.global().async {
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.requestedTimeToleranceAfter = .zero
            imageGenerator.requestedTimeToleranceBefore = .zero
            imageGenerator.maximumSize = size
            
            let bgAsset = AVAsset(url: bgURL)
            let bgImageGenerator = AVAssetImageGenerator(asset: bgAsset)
            bgImageGenerator.appliesPreferredTrackTransform = true
            bgImageGenerator.requestedTimeToleranceAfter = .zero
            bgImageGenerator.requestedTimeToleranceBefore = .zero
            bgImageGenerator.maximumSize = size
            
            let audioTrackUrl = FileManager.default.urls(for: .documentDirectory, in: .allDomainsMask).first!.appendingPathComponent("auido.m4a")
            var audioTrackSaved = false
            asset.writeAudioTrackToURL(audioTrackUrl, completion: { (success, error) in
                audioTrackSaved = true
            })
            
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
            
            var imageNames = [String]()
            
            var prevBackground = UIImage(named: "default_bg")!
            
            var counter = 1
            for cmTime in cmTimes {
                if let imageRef = try? imageGenerator.copyCGImage(at: cmTime, actualTime: nil) {
                    var name = "merged_\(counter)"
                    if let bgImage = try? bgImageGenerator.copyCGImage(at: cmTime, actualTime: nil) {
                        if let mergedImage = self.merge(cgImage: imageRef, with: UIImage(cgImage: bgImage)) {
                            _ = FilesHelper.instance.saveImage(image: mergedImage, name: name)
                            prevBackground = UIImage(cgImage: bgImage)
                        }
                    } else {
                        if let image = self.merge(cgImage: imageRef, with: prevBackground) {
                            _ = FilesHelper.instance.saveImage(image: image, name: name)
                        }
                    }
                    imageNames.append(name)
                    counter += 1
                }
            }
            

            while !audioTrackSaved {
                Thread.sleep(forTimeInterval: 0.01)
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH_mm_ss_dd_MM_YYYY"
            var settings = RenderSettings()
            settings.height = size.height
            settings.width = size.width
            settings.videoFilename = "render_\(dateFormatter.string(from: Date()))"
            let imageAnimator = ImageAnimator(renderSettings: settings, imageFileNames: imageNames, audioFileURL: audioTrackUrl)
            imageAnimator.render() {
                DispatchQueue.main.async {
                    self.indicator?.removeFromSuperview()
                    self.indicator = nil
                    let alerController = UIAlertController(title: "Successfuly rendered new video", message: "Check Photos app", preferredStyle: .alert)
                    alerController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alerController, animated: true, completion: nil)
                    print("successfully rendered images")
                }
                
            }
            
        }
    }

    //Merging pics implementation(Chroma Key)
    
    func merge(cgImage: CGImage, with background: UIImage) -> UIImage? {
        let foregroundCIImage = CIImage(cgImage: cgImage)
        
        guard let backgroundCGImage = background.cgImage else {
            return nil
        }
        
        let backgroundCIImage = CIImage(cgImage: backgroundCGImage)
        
        let chromaCIFilter = self.chromaKeyFilter(fromHue: 0.20, toHue: 0.55)
        chromaCIFilter?.setValue(foregroundCIImage, forKey: kCIInputImageKey)
        let sourceCIImageWithoutBackground = chromaCIFilter?.outputImage
        
        let compositor = CIFilter(name:"CISourceOverCompositing")
        compositor?.setValue(sourceCIImageWithoutBackground, forKey: kCIInputImageKey)
        compositor?.setValue(backgroundCIImage, forKey: kCIInputBackgroundImageKey)
    
        let ciContext = CIContext()
        
        if let compositedCIImage = compositor?.outputImage {
            if let cgRef = ciContext.createCGImage(compositedCIImage, from: compositedCIImage.extent) {
                return UIImage(cgImage: cgRef)
            }
            return UIImage(ciImage: compositedCIImage)
        }
        return nil
    }
    
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
        let ciContext = CIContext()
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
        
        let size = 64
        var cubeRGB = [Float]()
        
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
            if selectingFirst {
                self.fgURL = videoURL
                if let preview = self.extractThumbnailFromVideo(url: videoURL) {
                    DispatchQueue.main.async {
                        self.imageView.image = preview
                    }
                }
                self.selectingFirst = false
            } else if selectingSecond {
                self.bgURL = videoURL
                if let preview = self.extractThumbnailFromVideo(url: videoURL) {
                    DispatchQueue.main.async {
                        self.secondImageView.image = preview
                    }
                }
                self.selectingSecond = false
            }
            if self.fgURL != nil && self.bgURL != nil {
                self.mergeButton.isHidden = false
            }
        }
        
    }
    
}
