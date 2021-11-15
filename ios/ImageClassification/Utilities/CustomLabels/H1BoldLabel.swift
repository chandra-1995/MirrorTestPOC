//
//  H1BoldLabel.swift
//  OneAssist-Swift
//
//  Created by Himanshu Dagar on 20/03/19.
//  Copyright © 2019 OneAssist. All rights reserved.
//

import UIKit

class H1BoldLabel: UILabel {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialiseView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialiseView()
    }
    
    private func initialiseView() {
        font = DLSFont.h1.bold
        textColor = UIColor.charcoalGrey
    }
    
}
