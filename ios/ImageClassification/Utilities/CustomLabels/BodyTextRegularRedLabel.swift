//
//  BodyTextRegularRedLabel.swift
//  OneAssist-Swift
//
//  Created by Himanshu Dagar on 24/04/19.
//  Copyright © 2019 OneAssist. All rights reserved.
//

import UIKit

class BodyTextRegularRedLabel: UILabel {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialiseView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialiseView()
    }
    
    private func initialiseView() {
        font = DLSFont.bodyText.regular
        textColor = UIColor.errorMessage
    }
}


