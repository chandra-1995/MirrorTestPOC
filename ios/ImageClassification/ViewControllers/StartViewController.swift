//
//  StartViewController.swift
//  ImageClassification
//
//  Created by Ankur Batham on 15/02/21.
//  Copyright © 2021 Y Media Labs. All rights reserved.
//

import UIKit

private let dir: String = #file.deletingLastPathComponent.deletingLastPathComponent

class StartViewController: UIViewController, UITextFieldDelegate {
    
    
    @IBOutlet weak var frameDelayTextField: UITextField!
    @IBOutlet weak var captureImagePreview: UIImageView!
    
    @IBOutlet weak var attemptTimeTakenLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    @IBAction func onClickSingleThreadAction(_ sender: UIButton?) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CameraViewController") as! ViewController
        vc.modalPresentationStyle = .fullScreen
        vc.isFrontCamera = true
        vc.isSupportMultiThreading = false
        vc.delegate = self
        vc.delayOfShowingMessages = Double(frameDelayTextField.text ?? "1.5") ?? 0
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func onClickMultiThreadAction(_ sender: UIButton?) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CameraViewController") as! ViewController
        vc.modalPresentationStyle = .fullScreen
        vc.isFrontCamera = true
        vc.isSupportMultiThreading = true
        vc.delegate = self
        vc.delayOfShowingMessages = Double(frameDelayTextField.text ?? "1.5") ?? 0
        self.present(vc, animated: true, completion: nil)
    }

    
    //Calls this function when the tap is recognized.
    @objc func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
        if frameDelayTextField?.text?.isEmpty ?? true {
            frameDelayTextField?.text = "1.5"
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        if frameDelayTextField?.text?.isEmpty ?? true {
            frameDelayTextField?.text = "1.5"
        }
        return false
    }
}

extension StartViewController: MirrorTestDelegate {
    func imageCaptureSuccesfully(image: UIImage?, attemptTakenTime: String?) {
        captureImagePreview.image = image
        attemptTimeTakenLabel.text = attemptTakenTime
    }
}
