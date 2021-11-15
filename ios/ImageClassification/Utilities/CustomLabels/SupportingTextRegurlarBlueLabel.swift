//
//  SupportingTextRegurlarBlue.swift
//  OneAssist-Swift
//
//  Created by Raj on 26/04/19.
//  Copyright © 2019 OneAssist. All rights reserved.
//

import Foundation
import UIKit
class SupportingTextRegurlarBlueLabel: UILabel {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialiseView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialiseView()
    }
    
    private func initialiseView() {
        font = DLSFont.supportingText.regular  //UIFont.setLatoRegular(with: .supportingText)
        textColor = UIColor.buttonTitleBlue
    }
    
}
