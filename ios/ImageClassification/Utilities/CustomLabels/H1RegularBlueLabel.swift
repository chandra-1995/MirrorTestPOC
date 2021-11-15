//
//  H1RegularBlueLabel.swift
//  OneAssist-Swift
//
//  Created by Ankur Batham on 02/04/19.
//  Copyright © 2019 OneAssist. All rights reserved.
//

import UIKit

class H1RegularBlueLabel: UILabel {

    override init(frame: CGRect) {
        super.init(frame: frame)
        initialiseView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialiseView()
    }
    
    private func initialiseView() {
        font = DLSFont.h1.regular
        textColor = UIColor.buttonTitleBlue
    }

}
