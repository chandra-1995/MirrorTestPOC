//
//  AppFont.swift
//  OneAssist-Swift
//
//  Created by Varun on 19/07/17.
//  Copyright © 2017 Mukesh. All rights reserved.
//

import UIKit

enum DLSFont:CGFloat{
    case h0 = 32
    case h1 = 24
    case h2 = 20
    case h3 = 16
    case h4 = 18
    case bodyText = 14
    case supportingText = 12
    case tags = 10
    case smallTag = 8
    case h1Large = 28
    
    var regular:UIFont {
        return UIFont(name: "Lato-Regular", size: self.rawValue)!
    }
    
    var bold:UIFont {
        return UIFont(name: "Lato-Bold", size: self.rawValue)!
    }
    
    var medium:UIFont {
        return UIFont(name: "Lato-Medium", size: self.rawValue)!
    }
    
    var lineSpacing:CGFloat {
        switch self {
        case .h0: return 1.5
        case .h1: return 1.5
        case .h2: return 1.4
        case .h3: return 1.5
        case .h4: return 1.5
        case .h1Large: return 1.5
        case .bodyText: return 1.57
        case .supportingText: return 1.67
        case .tags: return 1.5
        case .smallTag: return 1.5
        }
    }
}
