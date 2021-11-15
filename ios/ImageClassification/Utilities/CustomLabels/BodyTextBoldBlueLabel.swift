//
//  BodyTextBoldBlueLabel.swift
//  OneAssist-Swift
//
//  Created by Chandra Bhushan on 19/05/21.
//  Copyright © 2021 OneAssist. All rights reserved.
//

import UIKit

class BodyTextBoldBlueLabel: UILabel {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialiseView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialiseView()
    }
    
    private func initialiseView() {
        font = DLSFont.bodyText.bold
        textColor = UIColor.buttonBlue
    }
}


