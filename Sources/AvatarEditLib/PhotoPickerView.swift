//
//  PhotoPickerView.swift
//  ClassM
//
//  Created by Vk on 2019/12/21.
//  Copyright © 2019 hileel. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

struct PhotoPickerView : UIViewControllerRepresentable {
    
    let callback : (UIImage?) -> Void
    
    class Coordinator : NSObject,  UIImagePickerControllerDelegate , UINavigationControllerDelegate {
        
        let callback : (UIImage?) -> Void
        
        init(_ callback: @escaping (UIImage?) -> Void) {
            self.callback = callback
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("===imagePickerControllerDidCancel=")
            picker.dismiss(animated: true, completion: nil)
        }
        
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            guard let selectedImage = info[.originalImage] as? UIImage else {
                print("Expected a dictionary containing an image, but was provided the following: \(info)")
                return
            }
            self.callback(selectedImage)
//            picker.dismiss(animated: true, completion: nil)
        }
        
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(callback)
    }
    
    /// Creates a `UIViewController` instance to be presented.
    func makeUIViewController(context: Self.Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.delegate = context.coordinator
        vc.sourceType = .photoLibrary
        vc.modalPresentationStyle = .fullScreen
        return vc
    }
    
    /// Updates the presented `UIViewController` (and coordinator) to the latest
    /// configuration.
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Self.Context){
        
    }
    
}
