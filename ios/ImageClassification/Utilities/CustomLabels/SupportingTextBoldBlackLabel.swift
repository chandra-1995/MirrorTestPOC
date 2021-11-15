//
//  SupportingTextBoldBlackLabel.swift
//  OneAssist-Swift
//
//  Created by Himanshu Dagar on 02/04/19.
//  Copyright © 2019 OneAssist. All rights reserved.
//

import UIKit

class SupportingTextBoldBlackLabel: UILabel {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialiseView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialiseView()
    }
    
    private func initialiseView() {
        font = DLSFont.supportingText.bold
        textColor = UIColor.charcoalGrey
    }
}

