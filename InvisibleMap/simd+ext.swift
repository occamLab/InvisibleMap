//
//  simd+ext.swift
//
//  Created by Kaz Yoshikawa on 11/6/15.
//
//

import Foundation
import simd
import GLKit

extension float4x4 {

    static func makeScale(_ x: Float, _ y: Float, _ z: Float) -> float4x4 {
        return unsafeBitCast(GLKMatrix4MakeScale(x, y, z), to: float4x4.self)
    }

    static func makeRotate(radians: Float, _ x: Float, _ y: Float, _ z: Float) -> float4x4 {
        return unsafeBitCast(GLKMatrix4MakeRotation(radians, x, y, z), to: float4x4.self)
    }

    static func makeTranslation(_ x: Float, _ y: Float, _ z: Float) -> float4x4 {
        return unsafeBitCast(GLKMatrix4MakeTranslation(x, y, z), to: float4x4.self)
    }

    static func makePerspective(fovyRadians: Float, _ aspect: Float, _ nearZ: Float, _ farZ: Float) -> float4x4 {
        return unsafeBitCast(GLKMatrix4MakePerspective(fovyRadians, aspect, nearZ, farZ), to: float4x4.self)
    }

    static func makeFrustum(left: Float, _ right: Float, _ bottom: Float, _ top: Float, _ nearZ: Float, _ farZ: Float) -> float4x4 {
        return unsafeBitCast(GLKMatrix4MakeFrustum(left, right, bottom, top, nearZ, farZ), to: float4x4.self)
    }

    static func makeOrtho(left: Float, _ right: Float, _ bottom: Float, _ top: Float, _ nearZ: Float, _ farZ: Float) -> float4x4 {
        return unsafeBitCast(GLKMatrix4MakeOrtho(left, right, bottom, top, nearZ, farZ), to: float4x4.self)
    }

    static func makeLookAt(eyeX: Float, _ eyeY: Float, _ eyeZ: Float, _ centerX: Float, _ centerY: Float, _ centerZ: Float, _ upX: Float, _ upY: Float, _ upZ: Float) -> float4x4 {
        return unsafeBitCast(GLKMatrix4MakeLookAt(eyeX, eyeY, eyeZ, centerX, centerY, centerZ, upX, upY, upZ), to: float4x4.self)
    }


    func scale(x: Float, y: Float, z: Float) -> float4x4 {
        return float4x4.makeScale(x, y, z) * self
    }

    func rotate(radians: Float, _ x: Float, _ y: Float, _ z: Float) -> float4x4 {
        return float4x4.makeRotate(radians: radians, x, y, z) * self
    }

    func translate(x: Float, _ y: Float, _ z: Float) -> float4x4 {
        return float4x4.makeTranslation(x, y, z) * self
    }
    
    func getRot()->float3x3 {
        return getUpper3x3()
    }

    func getUpper3x3()->float3x3 {
        return float3x3(columns: (simd_float3(self.columns.0.x, self.columns.0.y, self.columns.0.z),
                                  simd_float3(self.columns.1.x, self.columns.1.y, self.columns.1.z),
                                  simd_float3(self.columns.2.x, self.columns.2.y, self.columns.2.z)))
    }

    func getTrans()->float3 {
        return float3(self.columns.3.x, self.columns.3.y, self.columns.3.z)
    }
}

extension float3 {
    func rotate(radians: Float, _ x: Float, _ y: Float, _ z: Float) -> float3 {
        let homogeneous = float4x4.makeRotate(radians: radians, x, y, z) * self.toHomogeneous()
        return float3(x: homogeneous.x/homogeneous.w, y: homogeneous.y/homogeneous.w, z: homogeneous.z/homogeneous.w)
    }
    func intrinsicRotate(radians: Float, _ x: Float, _ y: Float, _ z: Float) -> float3 {
        let homogeneous = self.toHomogeneous()*float4x4.makeRotate(radians: radians, x, y, z)
        return float3(x: homogeneous.x/homogeneous.w, y: homogeneous.y/homogeneous.w, z: homogeneous.z/homogeneous.w)
    }
    func toHomogeneous()->float4 {
        return float4(x: self.x, y: self.y, z: self.z, w: 1)
    }
}

extension simd_float3x3 {
    func trace()->Float {
        return self.columns.0.x + self.columns.1.y + self.columns.2.z
    }
}

extension simd_quatf {
    func toRotVec()->float3 {
        if self.angle == 0 {
            return simd_float3(0.0)
        } else {
            return self.axis*self.angle
        }
    }
}
