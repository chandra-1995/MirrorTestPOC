//
//  H3RegularGreyLabel.swift
//  OneAssist-Swift
//
//  Created by Himanshu Dagar on 20/03/19.
//  Copyright © 2019 OneAssist. All rights reserved.
//

import UIKit

class H3RegularGreyLabel: UILabel {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialiseView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialiseView()
    }
    
    private func initialiseView() {
        font = DLSFont.h3.regular
        textColor = UIColor.bodyTextGray
    }
}

