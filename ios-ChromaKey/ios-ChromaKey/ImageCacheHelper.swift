//
//  ImageCacheHelper.swift
//  ios-ChromaKey
//
//  Created by Alexandr Nadtoka on 12/11/18.
//  Copyright © 2018 kreatimont. All rights reserved.
//

import Foundation
import UIKit


class FilesHelper {
    
    static let instance = FilesHelper()
    
    init() {
    }

    func saveImage(image: UIImage, name: String) -> Bool {
        guard let data = image.jpegData(compressionQuality: 1) ?? image.pngData() else {
            return false
        }
        guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) as NSURL else {
            return false
        }
        do {
            try data.write(to: directory.appendingPathComponent("\(name).png")!)
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }
    
    func getSavedImage(named: String) -> UIImage? {
        if let dir = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            return UIImage(contentsOfFile: URL(fileURLWithPath: dir.absoluteString).appendingPathComponent("\(named).png").path)
        }
        return nil
    }
    
    func clearImages() {
        let fileManager = FileManager.default
        let myDocuments = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        guard let filePaths = try? fileManager.contentsOfDirectory(at: myDocuments, includingPropertiesForKeys: nil, options: []) else {
            return
        }
        for filePath in filePaths {
            try? fileManager.removeItem(at: filePath)
        }
    }
    
    
}
