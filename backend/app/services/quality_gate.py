"""
Quality Gate Service: Fail-safe mechanisms and quality checks
Ensures "gold standard" level of biomechanical realism
"""
import numpy as np
from typing import Dict, List, Optional, Tuple
from loguru import logger
from enum import Enum

from app.core.config import settings


class QualityLevel(Enum):
    """Quality assessment levels"""
    PASS = "pass"
    WARNING = "warning"
    FAIL = "fail"


class QualityGateService:
    """
    Quality gate service for gait analysis
    Implements fail-safe mechanisms and anatomical constraints
    """
    
    def __init__(self):
        self.min_joint_confidence = settings.MIN_JOINT_CONFIDENCE
        self.min_frame_count = settings.MIN_FRAME_COUNT
        self.max_missing_joints = settings.MAX_MISSING_JOINTS
        logger.info("Quality gate service initialized")
    
    def assess_quality(
        self,
        keypoints_3d: np.ndarray,
        confidence: Optional[np.ndarray] = None,
        num_frames: Optional[int] = None
    ) -> Dict[str, any]:
        """
        Comprehensive quality assessment
        
        Args:
            keypoints_3d: (num_frames, num_joints, 3) - 3D keypoints
            confidence: (num_frames, num_joints) - Confidence scores
            num_frames: Optional explicit frame count
        
        Returns:
            Dictionary with quality assessment results
        """
        num_frames = num_frames or keypoints_3d.shape[0]
        num_joints = keypoints_3d.shape[1]
        
        checks = {
            'frame_count': self._check_frame_count(num_frames),
            'joint_confidence': self._check_joint_confidence(confidence, num_frames, num_joints),
            'missing_joints': self._check_missing_joints(keypoints_3d),
            'anatomical_constraints': self._check_anatomical_constraints(keypoints_3d),
            'temporal_consistency': self._check_temporal_consistency(keypoints_3d)
        }
        
        # Determine overall quality
        overall_quality = self._determine_overall_quality(checks)
        
        return {
            'overall_quality': overall_quality.value,
            'checks': {k: v['status'].value for k, v in checks.items()},
            'details': checks,
            'can_proceed': overall_quality != QualityLevel.FAIL,
            'warnings': [k for k, v in checks.items() if v['status'] == QualityLevel.WARNING]
        }
    
    def _check_frame_count(self, num_frames: int) -> Dict:
        """Check if sufficient frames for analysis"""
        if num_frames < self.min_frame_count:
            return {
                'status': QualityLevel.FAIL,
                'message': f"Insufficient frames: {num_frames} < {self.min_frame_count}",
                'value': num_frames
            }
        elif num_frames < self.min_frame_count * 2:
            return {
                'status': QualityLevel.WARNING,
                'message': f"Low frame count: {num_frames}",
                'value': num_frames
            }
        return {
            'status': QualityLevel.PASS,
            'message': f"Sufficient frames: {num_frames}",
            'value': num_frames
        }
    
    def _check_joint_confidence(
        self,
        confidence: Optional[np.ndarray],
        num_frames: int,
        num_joints: int
    ) -> Dict:
        """Check joint tracking confidence"""
        if confidence is None:
            return {
                'status': QualityLevel.WARNING,
                'message': "No confidence scores provided",
                'value': None
            }
        
        # Check average confidence
        avg_confidence = np.mean(confidence)
        min_confidence = np.min(confidence)
        
        if avg_confidence < self.min_joint_confidence:
            return {
                'status': QualityLevel.FAIL,
                'message': f"Low average confidence: {avg_confidence:.2f} < {self.min_joint_confidence}",
                'value': avg_confidence
            }
        
        # Check for frames with too many low-confidence joints
        low_conf_frames = np.sum(np.mean(confidence, axis=1) < self.min_joint_confidence)
        low_conf_ratio = low_conf_frames / num_frames
        
        if low_conf_ratio > 0.2:  # More than 20% of frames
            return {
                'status': QualityLevel.WARNING,
                'message': f"High proportion of low-confidence frames: {low_conf_ratio:.1%}",
                'value': avg_confidence
            }
        
        return {
            'status': QualityLevel.PASS,
            'message': f"Confidence acceptable: {avg_confidence:.2f}",
            'value': avg_confidence
        }
    
    def _check_missing_joints(self, keypoints_3d: np.ndarray) -> Dict:
        """Check for missing or invalid joints"""
        # Count NaN or zero keypoints
        missing_mask = np.isnan(keypoints_3d).any(axis=2) | (np.abs(keypoints_3d).sum(axis=2) < 1e-6)
        missing_per_frame = np.sum(missing_mask, axis=1)
        
        max_missing = np.max(missing_per_frame)
        avg_missing = np.mean(missing_per_frame)
        
        if max_missing > self.max_missing_joints:
            return {
                'status': QualityLevel.FAIL,
                'message': f"Too many missing joints: {max_missing} > {self.max_missing_joints}",
                'value': max_missing
            }
        
        if avg_missing > self.max_missing_joints / 2:
            return {
                'status': QualityLevel.WARNING,
                'message': f"Elevated missing joints: {avg_missing:.1f} per frame",
                'value': avg_missing
            }
        
        return {
            'status': QualityLevel.PASS,
            'message': f"Missing joints acceptable: {avg_missing:.1f} per frame",
            'value': avg_missing
        }
    
    def _check_anatomical_constraints(self, keypoints_3d: np.ndarray) -> Dict:
        """Check for physically impossible joint movements"""
        violations = []
        
        # Check joint angle limits
        angle_violations = self._check_joint_angles(keypoints_3d)
        if angle_violations:
            violations.extend(angle_violations)
        
        # Check bone length consistency
        length_violations = self._check_bone_lengths(keypoints_3d)
        if length_violations:
            violations.extend(length_violations)
        
        # Check for impossible positions (e.g., foot through floor)
        position_violations = self._check_positions(keypoints_3d)
        if position_violations:
            violations.extend(position_violations)
        
        if len(violations) > 5:  # Threshold for failures
            return {
                'status': QualityLevel.FAIL,
                'message': f"Multiple anatomical violations: {len(violations)}",
                'value': len(violations),
                'violations': violations[:5]  # Show first 5
            }
        
        if len(violations) > 0:
            return {
                'status': QualityLevel.WARNING,
                'message': f"Some anatomical violations: {len(violations)}",
                'value': len(violations),
                'violations': violations
            }
        
        return {
            'status': QualityLevel.PASS,
            'message': "Anatomical constraints satisfied",
            'value': 0
        }
    
    def _check_joint_angles(self, keypoints_3d: np.ndarray) -> List[str]:
        """Check joint angles against biomechanical limits"""
        violations = []
        
        # Knee flexion limits (0-160 degrees typical)
        # Ankle dorsiflexion limits (-20 to 50 degrees)
        # Hip flexion limits (0-120 degrees)
        
        # Simplified check - would need proper angle calculation
        # This is a placeholder for the actual implementation
        
        return violations
    
    def _check_bone_lengths(self, keypoints_3d: np.ndarray) -> List[str]:
        """Check bone length consistency across frames"""
        violations = []
        
        # Key bones: femur, tibia, etc.
        # Length should be relatively constant across frames
        
        # Calculate bone lengths
        left_hip = keypoints_3d[:, 11, :]
        left_knee = keypoints_3d[:, 13, :]
        left_ankle = keypoints_3d[:, 15, :]
        
        # Femur length (hip to knee)
        femur_lengths = np.linalg.norm(left_knee - left_hip, axis=1)
        femur_cv = np.std(femur_lengths) / (np.mean(femur_lengths) + 1e-6)
        
        if femur_cv > 0.1:  # More than 10% variation
            violations.append(f"Femur length inconsistent (CV: {femur_cv:.2f})")
        
        # Tibia length (knee to ankle)
        tibia_lengths = np.linalg.norm(left_ankle - left_knee, axis=1)
        tibia_cv = np.std(tibia_lengths) / (np.mean(tibia_lengths) + 1e-6)
        
        if tibia_cv > 0.1:
            violations.append(f"Tibia length inconsistent (CV: {tibia_cv:.2f})")
        
        return violations
    
    def _check_positions(self, keypoints_3d: np.ndarray) -> List[str]:
        """Check for impossible positions"""
        violations = []
        
        # Check if feet are below ground (assuming Z is vertical, pointing up)
        left_ankle = keypoints_3d[:, 15, 2]
        right_ankle = keypoints_3d[:, 16, 2]
        
        # Estimate ground plane
        ground_z = min(np.min(left_ankle), np.min(right_ankle))
        
        # Check for feet significantly below ground
        below_ground = np.sum((left_ankle < ground_z - 50) | (right_ankle < ground_z - 50))
        if below_ground > 0:
            violations.append(f"Feet below ground in {below_ground} frames")
        
        return violations
    
    def _check_temporal_consistency(self, keypoints_3d: np.ndarray) -> Dict:
        """Check temporal consistency of keypoint trajectories"""
        # Check for large jumps between frames
        keypoint_velocities = np.diff(keypoints_3d, axis=0)
        keypoint_speeds = np.linalg.norm(keypoint_velocities, axis=2)
        
        # Maximum reasonable speed (mm per frame)
        max_speed = 100.0  # Adjust based on fps and expected movement
        
        excessive_speeds = np.sum(keypoint_speeds > max_speed)
        total_movements = keypoint_speeds.size
        
        if excessive_speeds / total_movements > 0.05:  # More than 5%
            return {
                'status': QualityLevel.WARNING,
                'message': f"Temporal inconsistencies detected: {excessive_speeds} excessive movements",
                'value': excessive_speeds / total_movements
            }
        
        return {
            'status': QualityLevel.PASS,
            'message': "Temporal consistency acceptable",
            'value': excessive_speeds / total_movements
        }
    
    def _determine_overall_quality(self, checks: Dict) -> QualityLevel:
        """Determine overall quality level from individual checks"""
        # Fail if any check fails
        for check in checks.values():
            if check['status'] == QualityLevel.FAIL:
                return QualityLevel.FAIL
        
        # Warning if any check warns
        for check in checks.values():
            if check['status'] == QualityLevel.WARNING:
                return QualityLevel.WARNING
        
        return QualityLevel.PASS
    
    def gate_analysis(
        self,
        keypoints_3d: np.ndarray,
        confidence: Optional[np.ndarray] = None
    ) -> Tuple[bool, Optional[str]]:
        """
        Quick gate check - returns (can_proceed, error_message)
        
        Args:
            keypoints_3d: 3D keypoints
            confidence: Optional confidence scores
        
        Returns:
            (can_proceed, error_message)
        """
        assessment = self.assess_quality(keypoints_3d, confidence)
        
        if not assessment['can_proceed']:
            error_msg = "; ".join([
                f"{k}: {v['message']}"
                for k, v in assessment['details'].items()
                if v['status'] == QualityLevel.FAIL
            ])
            return False, error_msg
        
        return True, None

