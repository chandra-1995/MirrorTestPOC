//
//  MirrorTest_IC_Frames_Stack.swift
//  ImageClassification
//
//  Created by Chandra Bhushan on 08/11/21.
//  Copyright © 2021 Y Media Labs. All rights reserved.
//

import Foundation
class Stack<T>{
    fileprivate var stackData:[T] = []
    var isEmpty:Bool{
        return stackData.isEmpty
    }
    var count:Int{
        return stackData.count
    }
    func push(_ text:T){
        stackData.append(text)
    }
    func pop()-> T? {
        return stackData.popLast()
    }
    func peek()->T?{
        return (stackData.last)
    }
    func removeAll(){
        stackData.removeAll()
    }
}

class MirrorTestStack<T: MirrorTestProcessModel>: Stack<MirrorTestProcessModel> {
    var bufferSize: Int? = 12
    
    func pushUpdatedFrame(_ data:T) {
        if self.count == bufferSize, bufferSize != 0 {
            stackData.removeFirst()
        }
        stackData.append(data)
    }
}
