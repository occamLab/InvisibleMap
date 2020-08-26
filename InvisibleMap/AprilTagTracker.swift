//
//  AprilTagTrackerr.swift
//  InvisibleMap
//
//  Created by Paul Ruvolo on 8/11/20.
//  Copyright © 2020 Occam Lab. All rights reserved.
//

import Foundation

import UIKit
import ARKit
import GLKit

class AprilTagTracker {
    let id: Int
    var scenePositions: Array<simd_float3> = []
    var sceneQuats: Array<simd_quatf> = []
    var scenePositionCovariances: Array<simd_float3x3> = []
    var sceneQuatCovariances: Array<simd_float4x4> = []
    weak var sceneView: ARSCNView?
    private(set) var tagPosition = simd_float3()
    private(set) var tagOrientation = simd_quatf()
    // staging variable for the new anchor that should be created.  This is needed to allow adjustment via setWorldOrigin
    var pendingPoseAnchorTransform: simd_float4x4?

    func willUpdateWorldOrigin(relativeTransform: simd_float4x4) {
        guard let pendingPoseAnchorTransform = pendingPoseAnchorTransform else {
            return
        }
        sceneView?.session.add(anchor: ARAnchor(name: String(format: "tag_%d", id), transform:  relativeTransform.inverse*pendingPoseAnchorTransform))
        self.pendingPoseAnchorTransform = nil
        for i in 0 ..< scenePositionCovariances.count {
            let q = simd_quatf(relativeTransform.inverse)
            // this representation is useful for updating the covariances
            let quatMultiplyAsLinearTransform = simd_float4x4(columns:
                (simd_float4(q.vector.w, q.vector.z, -q.vector.y, -q.vector.x),
                 simd_float4(-q.vector.z, q.vector.w, q.vector.x, -q.vector.y),
                 simd_float4(q.vector.y, -q.vector.x, q.vector.w, -q.vector.z),
                 simd_float4(q.vector.x, q.vector.y, q.vector.z, q.vector.w)))
            sceneQuatCovariances[i] = quatMultiplyAsLinearTransform*sceneQuatCovariances[i]*quatMultiplyAsLinearTransform.transpose
            scenePositionCovariances[i] = relativeTransform.inverse.getUpper3x3()*scenePositionCovariances[i]*relativeTransform.inverse.getUpper3x3().transpose
        }
    }

    func updateTagPoseMeans(id: Int, detectedPosition: simd_float3, detectedPositionVar: simd_float3x3, detectedQuat: simd_quatf, detectedQuatVar: simd_float4x4, doKalman: Bool) {
        // TODO: it's probably overkill, but we correct the covariances usign the anchor poses as well
        scenePositionCovariances.append(detectedPositionVar)
        sceneQuatCovariances.append(detectedQuatVar)
        var newPose = simd_float4x4(detectedQuat)
        newPose.columns.3 = detectedPosition.toHomogeneous()
        pendingPoseAnchorTransform = newPose
        // TODO: check if we have to manually add these
        var (scenePositions, sceneQuats) = getTrackedTagTransforms()
        scenePositions.append(detectedPosition)
        sceneQuats.append(detectedQuat)

        if doKalman {
            tagPosition = uncertaintyWeightedAverage(zs: scenePositions, sigmas: scenePositionCovariances)
            tagOrientation = averageQuaternions(quats: sceneQuats, quatCovariances: sceneQuatCovariances)
        } else {
            tagPosition = detectedPosition
            tagOrientation = detectedQuat
        }
    }
    
    func getTrackedTagTransforms()->([simd_float3],[simd_quatf]) {
        var positions: [simd_float3] = []
        var orientations: [simd_quatf] = []
        guard let transforms = sceneView?.session.currentFrame?.anchors.compactMap({$0.name != nil && $0.name! == String(format: "tag_%d", id) ? $0.transform : nil }) else {
            return (positions, orientations)
        }
        for transform in transforms {
            positions.append(simd_float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z))
            orientations.append(simd_quatf(transform))
        }
        
        return (positions, orientations)
    }
    
    func uncertaintyWeightedAverage(zs: Array<simd_float3>, sigmas: Array<simd_float3x3>)->simd_float3 {
        // Strategy is to use the Kalman equations (https://en.wikipedia.org/wiki/Kalman_filter#Predict) with F_k set to identity, H_k set to identity, Q_k set to zero matix, R_k set to sigmas[k]
        // TODO: allow incremental updating to save time
        // TODO: this might be numerically unstable when we have a lot of measurements
        // DEBUG: this seems to drift all over the place when tag is far from origin
        // DEBUG: I think it's fixed now.   Need to test more.
        
        guard var xhat_kk = zs.first, var Pkk = sigmas.first else {
            return float3(Float.nan, Float.nan, Float.nan)
        }
        for i in 1..<zs.count {
            // Qk is the process noise.  Let's assume that there is a small drift of the tag position in the map frame over time
            let Qk = matrix_identity_float3x3*1e-16
            Pkk = Pkk + Qk;
            let Kk = Pkk*(Pkk + sigmas[i]).inverse
            Pkk = (matrix_identity_float3x3 - Kk)*Pkk
            xhat_kk = xhat_kk + Kk*(zs[i] - xhat_kk)
        }
        return xhat_kk
    }
    
    private func averageQuaternions(quats: Array<simd_quatf>, quatCovariances: Array<simd_float4x4>)->simd_quatf {
        var quatAverage = simd_quatf(vector: simd_float4(0, 0, 0, 1))  // initialize with no rotation
        var converged = false
        var epsilons = Array<Float>.init(repeating: 1.0, count: quats.count)
        while !converged {
            var xhat_kk = simd_quatf(angle: 0, axis: simd_float3(0, 0, 1)).vector
            var Pkk = matrix_identity_float4x4
            
            let epsilonTimesQuats = zip(quats, epsilons).map { $0.0*$0.1 }
            for (epsilonTimesQuat, quatCovariance) in zip(epsilonTimesQuats, quatCovariances) {
                // Qk is the process noise.  Let's assume that there is a small drift of the tag orientation in the map frame over time
                // TODO: this is not well calibrated right now (it is artifically low due to over confidence in tag detections.  Also it should depend on time elapsed rather than be constant for each tag detection event
                let Qk = matrix_identity_float4x4*1e-16
                Pkk = Pkk + Qk;
                let Kk = Pkk*(Pkk + quatCovariance).inverse
                Pkk = (matrix_identity_float4x4 - Kk)*Pkk
                xhat_kk = xhat_kk + Kk*(epsilonTimesQuat.vector - xhat_kk)
            }

            quatAverage = simd_quatf(vector: xhat_kk).normalized
            let newEpsilons = zip(epsilonTimesQuats, epsilons).map { simd_length($0.0 - quatAverage) < simd_length(-$0.0 - quatAverage) ? $0.1 : -$0.1 }
            converged = zip(epsilons, newEpsilons).reduce(true, {x,y in x && y.0 == y.1})
            epsilons = newEpsilons
        }
        return quatAverage
    }

    init(_ sceneView: ARSCNView, tagId: Int) {
        id = tagId
        self.sceneView = sceneView
    }
    
    
    /// Removes all of the follow crumbs that have been built-up in the system
    func clearAllMeasurements() {
        guard let sceneView = sceneView else {
            return
        }
        guard let anchors = sceneView.session.currentFrame?.anchors else {
            return
        }
        for anchor in anchors {
            if let name = anchor.name, name == String(format: "tag_%d", id) {
                sceneView.session.remove(anchor: anchor)
            }
        }
    }
}
