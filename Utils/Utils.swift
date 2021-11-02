//
//  Utils.swift
//  InvisibleMap
//
//  Created by tad on 10/29/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import Foundation
import ARKit

func convertToSimd4x4(from: RawMap.Vertex) -> simd_float4x4 {
    return simd_float4x4(translation: simd_float3(from.translation.x, from.translation.y, from.translation.z), rotation: simd_quatf(ix: from.rotation.x, iy: from.rotation.y, iz: from.rotation.z, r: from.rotation.w))
}
