//
//  SupportingTextRegularVioletLabel.swift
//  OneAssist-Swift
//
//  Created by Chandra Bhushan on 01/06/20.
//  Copyright © 2020 OneAssist. All rights reserved.
//

import UIKit

class SupportingTextRegularVioletLabel: UILabel {
   
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialiseView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialiseView()
    }
    
    private func initialiseView() {
        font = DLSFont.supportingText.regular//UIFont.setLatoRegular(with: .supportingText)
        textColor = UIColor.violet
    }
}
