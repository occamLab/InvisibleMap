//
//  Utils.swift
//  InvisibleMap
//
//  Created by tad on 10/29/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import Foundation
import ARKit

extension simd_float4x4 {
    init(_ from: RawMap.Vertex) {
        self.init(translation: simd_float3(from.translation.x, from.translation.y, from.translation.z), rotation: simd_quatf(ix: from.rotation.x, iy: from.rotation.y, iz: from.rotation.z, r: from.rotation.w))
    }
    
    init(_ from: (Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double)) {
        self.init(rows: [simd_float4(Float(from.0), Float(from.1), Float(from.2),Float(from.3)), simd_float4(Float(from.4), Float(from.5), Float(from.6), Float(from.7)), simd_float4(Float(from.8), Float(from.9), Float(from.10), Float(from.11)), simd_float4(Float(from.12), Float(from.13), Float(from.14), Float(from.15))])
    }
}
