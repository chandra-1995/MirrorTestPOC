//
//  SmallTagsRegularYellowLabel.swift
//  OneAssist-Swift
//
//  Created by Chandra Bhushan on 01/06/20.
//  Copyright © 2020 OneAssist. All rights reserved.
//

import UIKit

class SmallTagsRegularYellowLabel: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialiseView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialiseView()
    }
    
    private func initialiseView() {
        font = DLSFont.smallTag.regular
        textColor = UIColor.white
    }
}
