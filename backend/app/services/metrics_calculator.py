"""
Gait Metrics Calculator
Computes clinical priority biomarkers for fall risk assessment
"""
import numpy as np
from typing import Dict, List, Optional, Tuple
from loguru import logger
from scipy import signal, stats
from dataclasses import dataclass

from app.core.config import settings


@dataclass
class GaitMetrics:
    """Container for gait analysis metrics"""
    # Spatiotemporal parameters
    gait_speed_mm_per_s: float
    stride_length_mm: float
    stride_variability_cv: float  # Coefficient of variation
    cadence_steps_per_min: float
    step_length_mm: float
    step_asymmetry_percent: float
    double_support_time_percent: float
    single_support_time_percent: float
    
    # Joint kinematics
    knee_flexion_peak_deg: float
    knee_clearance_mm: float
    toe_clearance_mm: float
    hip_flexion_peak_deg: float
    ankle_dorsiflexion_peak_deg: float
    
    # Temporal parameters
    stance_phase_percent: float
    swing_phase_percent: float
    
    # Confidence metrics
    overall_confidence: float
    data_quality_flags: List[str]


class GaitMetricsCalculator:
    """
    Calculate clinical gait metrics from 3D keypoints
    Prioritizes biomarkers with highest predictive value
    """
    
    def __init__(self, fps: float = 30.0):
        self.fps = fps
        self.dt = 1.0 / fps
        
        # Joint indices (COCO format)
        self.joint_indices = {
            'nose': 0,
            'left_hip': 11,
            'right_hip': 12,
            'left_knee': 13,
            'right_knee': 14,
            'left_ankle': 15,
            'right_ankle': 16,
            'left_toe': None,  # Approximate from ankle
            'right_toe': None
        }
    
    def calculate_all_metrics(
        self,
        keypoints_3d: np.ndarray,
        confidence: Optional[np.ndarray] = None
    ) -> GaitMetrics:
        """
        Calculate all gait metrics from 3D keypoint sequence
        
        Args:
            keypoints_3d: (num_frames, num_joints, 3) - 3D keypoints in mm
            confidence: (num_frames, num_joints) - Optional confidence scores
        
        Returns:
            GaitMetrics object with all computed metrics
        """
        num_frames = keypoints_3d.shape[0]
        
        # Detect gait events (heel strike, toe off)
        gait_events = self._detect_gait_events(keypoints_3d)
        
        # Calculate spatiotemporal parameters
        gait_speed = self._calculate_gait_speed(keypoints_3d, gait_events)
        stride_length = self._calculate_stride_length(keypoints_3d, gait_events)
        stride_variability = self._calculate_stride_variability(keypoints_3d, gait_events)
        cadence = self._calculate_cadence(gait_events, num_frames)
        step_length = self._calculate_step_length(keypoints_3d, gait_events)
        step_asymmetry = self._calculate_step_asymmetry(keypoints_3d, gait_events)
        double_support = self._calculate_double_support_time(gait_events)
        single_support = self._calculate_single_support_time(gait_events)
        
        # Calculate joint kinematics
        knee_flexion_peak = self._calculate_knee_flexion_peak(keypoints_3d)
        knee_clearance = self._calculate_knee_clearance(keypoints_3d)
        toe_clearance = self._calculate_toe_clearance(keypoints_3d)
        hip_flexion_peak = self._calculate_hip_flexion_peak(keypoints_3d)
        ankle_dorsiflexion_peak = self._calculate_ankle_dorsiflexion_peak(keypoints_3d)
        
        # Calculate temporal parameters
        stance_percent, swing_percent = self._calculate_phase_percentages(gait_events)
        
        # Calculate confidence and quality flags
        overall_conf = self._calculate_overall_confidence(confidence) if confidence is not None else 0.9
        quality_flags = self._assess_data_quality(keypoints_3d, confidence, gait_events)
        
        return GaitMetrics(
            gait_speed_mm_per_s=gait_speed,
            stride_length_mm=stride_length,
            stride_variability_cv=stride_variability,
            cadence_steps_per_min=cadence,
            step_length_mm=step_length,
            step_asymmetry_percent=step_asymmetry,
            double_support_time_percent=double_support,
            single_support_time_percent=single_support,
            knee_flexion_peak_deg=knee_flexion_peak,
            knee_clearance_mm=knee_clearance,
            toe_clearance_mm=toe_clearance,
            hip_flexion_peak_deg=hip_flexion_peak,
            ankle_dorsiflexion_peak_deg=ankle_dorsiflexion_peak,
            stance_phase_percent=stance_percent,
            swing_phase_percent=swing_percent,
            overall_confidence=overall_conf,
            data_quality_flags=quality_flags
        )
    
    def _detect_gait_events(
        self,
        keypoints_3d: np.ndarray
    ) -> Dict[str, List[int]]:
        """
        Detect gait events: heel strike and toe off
        
        Returns:
            Dictionary with 'left_heel_strike', 'right_heel_strike', etc.
        """
        left_ankle = keypoints_3d[:, self.joint_indices['left_ankle'], :]
        right_ankle = keypoints_3d[:, self.joint_indices['right_ankle'], :]
        
        # Heel strike: minimum vertical position (assuming Z is vertical)
        left_ankle_z = left_ankle[:, 2]
        right_ankle_z = right_ankle[:, 2]
        
        # Find local minima (heel strikes)
        left_heel_strikes = signal.find_peaks(-left_ankle_z, distance=int(self.fps * 0.5))[0]
        right_heel_strikes = signal.find_peaks(-right_ankle_z, distance=int(self.fps * 0.5))[0]
        
        # Toe off: maximum vertical velocity
        left_ankle_velocity = np.diff(left_ankle_z)
        right_ankle_velocity = np.diff(right_ankle_z)
        
        left_toe_offs = signal.find_peaks(left_ankle_velocity, distance=int(self.fps * 0.3))[0]
        right_toe_offs = signal.find_peaks(right_ankle_velocity, distance=int(self.fps * 0.3))[0]
        
        return {
            'left_heel_strike': left_heel_strikes.tolist(),
            'right_heel_strike': right_heel_strikes.tolist(),
            'left_toe_off': left_toe_offs.tolist(),
            'right_toe_off': right_toe_offs.tolist()
        }
    
    def _calculate_gait_speed(
        self,
        keypoints_3d: np.ndarray,
        gait_events: Dict[str, List[int]]
    ) -> float:
        """Calculate gait speed (mm/s) - 6th Vital Sign"""
        # Use hip center for forward progression
        left_hip = keypoints_3d[:, self.joint_indices['left_hip'], :]
        right_hip = keypoints_3d[:, self.joint_indices['right_hip'], :]
        hip_center = (left_hip + right_hip) / 2
        
        # Forward displacement (assuming X is forward)
        forward_displacement = hip_center[-1, 0] - hip_center[0, 0]
        total_time = (keypoints_3d.shape[0] - 1) * self.dt
        
        if total_time > 0:
            return abs(forward_displacement) / total_time
        return 0.0
    
    def _calculate_stride_length(
        self,
        keypoints_3d: np.ndarray,
        gait_events: Dict[str, List[int]]
    ) -> float:
        """Calculate average stride length (mm)"""
        if len(gait_events['left_heel_strike']) < 2:
            return 0.0
        
        # Distance between consecutive heel strikes of same foot
        left_hip = keypoints_3d[:, self.joint_indices['left_hip'], :]
        right_hip = keypoints_3d[:, self.joint_indices['right_hip'], :]
        hip_center = (left_hip + right_hip) / 2
        
        stride_lengths = []
        strikes = gait_events['left_heel_strike']
        for i in range(len(strikes) - 1):
            pos1 = hip_center[strikes[i], :2]  # X, Y
            pos2 = hip_center[strikes[i + 1], :2]
            stride_lengths.append(np.linalg.norm(pos2 - pos1))
        
        return np.mean(stride_lengths) if stride_lengths else 0.0
    
    def _calculate_stride_variability(
        self,
        keypoints_3d: np.ndarray,
        gait_events: Dict[str, List[int]]
    ) -> float:
        """Calculate stride variability (coefficient of variation) - High priority"""
        if len(gait_events['left_heel_strike']) < 3:
            return 0.0
        
        # Calculate stride times
        strikes = gait_events['left_heel_strike']
        stride_times = np.diff(strikes) * self.dt
        
        if len(stride_times) > 0 and np.mean(stride_times) > 0:
            cv = np.std(stride_times) / np.mean(stride_times)
            return cv * 100  # Return as percentage
        return 0.0
    
    def _calculate_cadence(
        self,
        gait_events: Dict[str, List[int]],
        num_frames: int
    ) -> float:
        """Calculate cadence (steps per minute)"""
        total_steps = len(gait_events['left_heel_strike']) + len(gait_events['right_heel_strike'])
        total_time = num_frames * self.dt
        
        if total_time > 0:
            return (total_steps / total_time) * 60.0
        return 0.0
    
    def _calculate_step_length(
        self,
        keypoints_3d: np.ndarray,
        gait_events: Dict[str, List[int]]
    ) -> float:
        """Calculate average step length (mm)"""
        # Distance between opposite foot heel strikes
        left_ankle = keypoints_3d[:, self.joint_indices['left_ankle'], :]
        right_ankle = keypoints_3d[:, self.joint_indices['right_ankle'], :]
        
        left_strikes = gait_events['left_heel_strike']
        right_strikes = gait_events['right_heel_strike']
        
        if len(left_strikes) == 0 or len(right_strikes) == 0:
            return 0.0
        
        step_lengths = []
        # Find steps between opposite feet
        for l_strike in left_strikes:
            # Find nearest right strike after left
            right_after = [r for r in right_strikes if r > l_strike]
            if right_after:
                r_strike = min(right_after)
                step_lengths.append(
                    np.linalg.norm(right_ankle[r_strike, :2] - left_ankle[l_strike, :2])
                )
        
        return np.mean(step_lengths) if step_lengths else 0.0
    
    def _calculate_step_asymmetry(
        self,
        keypoints_3d: np.ndarray,
        gait_events: Dict[str, List[int]]
    ) -> float:
        """Calculate step asymmetry percentage - Medium priority"""
        left_strikes = gait_events['left_heel_strike']
        right_strikes = gait_events['right_heel_strike']
        
        if len(left_strikes) < 2 or len(right_strikes) < 2:
            return 0.0
        
        # Calculate step times for each foot
        left_step_times = np.diff(left_strikes) * self.dt
        right_step_times = np.diff(right_strikes) * self.dt
        
        if len(left_step_times) == 0 or len(right_step_times) == 0:
            return 0.0
        
        left_avg = np.mean(left_step_times)
        right_avg = np.mean(right_step_times)
        total_avg = (left_avg + right_avg) / 2
        
        if total_avg > 0:
            asymmetry = abs(left_avg - right_avg) / total_avg * 100
            return asymmetry
        return 0.0
    
    def _calculate_double_support_time(
        self,
        gait_events: Dict[str, List[int]]
    ) -> float:
        """Calculate double support time percentage - Medium priority"""
        # Double support: both feet on ground
        left_strikes = set(gait_events['left_heel_strike'])
        right_strikes = set(gait_events['right_heel_strike'])
        left_offs = set(gait_events['left_toe_off'])
        right_offs = set(gait_events['right_toe_off'])
        
        # Simplified: count frames where both feet are in stance
        # This is a simplified calculation
        total_frames = max(max(left_strikes | left_offs, default=0),
                          max(right_strikes | right_offs, default=0)) + 1
        
        if total_frames == 0:
            return 0.0
        
        # Approximate double support as overlap in stance phases
        # More sophisticated implementation would track exact stance phases
        return 20.0  # Placeholder - implement proper calculation
    
    def _calculate_single_support_time(
        self,
        gait_events: Dict[str, List[int]]
    ) -> float:
        """Calculate single support time percentage"""
        double_support = self._calculate_double_support_time(gait_events)
        stance = 60.0  # Typical stance phase
        return stance - double_support  # Simplified
    
    def _calculate_knee_flexion_peak(self, keypoints_3d: np.ndarray) -> float:
        """Calculate peak knee flexion angle (degrees)"""
        left_hip = keypoints_3d[:, self.joint_indices['left_hip'], :]
        left_knee = keypoints_3d[:, self.joint_indices['left_knee'], :]
        left_ankle = keypoints_3d[:, self.joint_indices['left_ankle'], :]
        
        # Calculate knee angle
        vec1 = left_knee - left_hip
        vec2 = left_ankle - left_knee
        
        angles = []
        for i in range(len(vec1)):
            if np.linalg.norm(vec1[i]) > 0 and np.linalg.norm(vec2[i]) > 0:
                cos_angle = np.dot(vec1[i], vec2[i]) / (np.linalg.norm(vec1[i]) * np.linalg.norm(vec2[i]))
                cos_angle = np.clip(cos_angle, -1, 1)
                angle = np.arccos(cos_angle) * 180 / np.pi
                angles.append(angle)
        
        return np.max(angles) if angles else 0.0
    
    def _calculate_knee_clearance(self, keypoints_3d: np.ndarray) -> float:
        """Calculate minimum knee clearance (mm) - High priority for trip risk"""
        left_knee = keypoints_3d[:, self.joint_indices['left_knee'], :]
        right_knee = keypoints_3d[:, self.joint_indices['right_knee'], :]
        
        # Ground plane (minimum ankle height)
        left_ankle = keypoints_3d[:, self.joint_indices['left_ankle'], :]
        right_ankle = keypoints_3d[:, self.joint_indices['right_ankle'], :]
        ground_z = min(np.min(left_ankle[:, 2]), np.min(right_ankle[:, 2]))
        
        # Minimum knee clearance above ground
        left_clearance = np.min(left_knee[:, 2] - ground_z)
        right_clearance = np.min(right_knee[:, 2] - ground_z)
        
        return min(left_clearance, right_clearance)
    
    def _calculate_toe_clearance(self, keypoints_3d: np.ndarray) -> float:
        """Calculate minimum toe clearance (mm) - High priority for trip risk"""
        # Approximate toe position from ankle
        left_ankle = keypoints_3d[:, self.joint_indices['left_ankle'], :]
        right_ankle = keypoints_3d[:, self.joint_indices['right_ankle'], :]
        
        # Ground plane
        ground_z = min(np.min(left_ankle[:, 2]), np.min(right_ankle[:, 2]))
        
        # Toe clearance (approximate - would need actual toe keypoint)
        # Using ankle as proxy
        left_clearance = np.min(left_ankle[:, 2] - ground_z)
        right_clearance = np.min(right_ankle[:, 2] - ground_z)
        
        return min(left_clearance, right_clearance)
    
    def _calculate_hip_flexion_peak(self, keypoints_3d: np.ndarray) -> float:
        """Calculate peak hip flexion angle (degrees)"""
        # Similar to knee flexion calculation
        return 0.0  # Placeholder
    
    def _calculate_ankle_dorsiflexion_peak(self, keypoints_3d: np.ndarray) -> float:
        """Calculate peak ankle dorsiflexion angle (degrees)"""
        # Similar calculation
        return 0.0  # Placeholder
    
    def _calculate_phase_percentages(
        self,
        gait_events: Dict[str, List[int]]
    ) -> Tuple[float, float]:
        """Calculate stance and swing phase percentages"""
        # Simplified calculation
        stance_percent = 60.0  # Typical for normal gait
        swing_percent = 40.0
        return stance_percent, swing_percent
    
    def _calculate_overall_confidence(
        self,
        confidence: np.ndarray
    ) -> float:
        """Calculate overall confidence score"""
        if confidence is None:
            return 0.9
        return float(np.mean(confidence))
    
    def _assess_data_quality(
        self,
        keypoints_3d: np.ndarray,
        confidence: Optional[np.ndarray],
        gait_events: Dict[str, List[int]]
    ) -> List[str]:
        """Assess data quality and return flags"""
        flags = []
        
        if confidence is not None and np.mean(confidence) < 0.7:
            flags.append("low_confidence")
        
        if len(gait_events['left_heel_strike']) < 2:
            flags.append("insufficient_gait_cycles")
        
        # Check for missing joints
        if np.any(np.isnan(keypoints_3d)):
            flags.append("missing_joints")
        
        return flags

