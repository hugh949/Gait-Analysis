"""
Environmental Robustness: Scale calibration and denoising
Handles home environment challenges (clutter, lighting, etc.)
"""
import cv2
import numpy as np
from typing import Tuple, Optional, List, Dict
from filterpy.kalman import KalmanFilter
from loguru import logger
import scipy.signal

from app.core.config_simple import settings


class ScaleCalibrator:
    """
    Scale calibration using reference objects or anthropometric scaling
    Converts pixel distances to metric units (mm)
    """
    
    def __init__(self):
        self.reference_length_pixels: Optional[float] = None
        self.reference_length_mm: float = settings.DEFAULT_REFERENCE_LENGTH_MM
        self.scale_factor: Optional[float] = None
    
    def detect_reference_object(
        self,
        frame: np.ndarray,
        reference_type: str = "A4"
    ) -> Optional[Tuple[float, float]]:
        """
        Detect reference object in frame (e.g., A4 paper, floor tile)
        
        Args:
            frame: Input video frame
            reference_type: Type of reference object
        
        Returns:
            (width_pixels, height_pixels) if detected, None otherwise
        """
        if reference_type == "A4":
            # Detect A4 paper (210mm x 297mm)
            # Use contour detection or template matching
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            edges = cv2.Canny(gray, 50, 150)
            contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            
            # Find rectangular contours matching A4 aspect ratio
            target_ratio = 210.0 / 297.0  # A4 aspect ratio
            
            for contour in contours:
                area = cv2.contourArea(contour)
                if area < 1000:  # Too small
                    continue
                
                # Approximate contour
                peri = cv2.arcLength(contour, True)
                approx = cv2.approxPolyDP(contour, 0.02 * peri, True)
                
                if len(approx) == 4:  # Rectangle
                    # Get bounding box
                    x, y, w, h = cv2.boundingRect(approx)
                    ratio = w / h if h > 0 else 0
                    
                    # Check if ratio matches A4
                    if abs(ratio - target_ratio) < 0.1:
                        return (w, h)
        
        return None
    
    def calibrate_from_reference(
        self,
        reference_length_pixels: float,
        reference_length_mm: float
    ):
        """Calibrate scale from known reference"""
        self.reference_length_pixels = reference_length_pixels
        self.reference_length_mm = reference_length_mm
        self.scale_factor = reference_length_mm / reference_length_pixels
        logger.info(f"Scale calibrated: {self.scale_factor:.4f} mm/pixel")
    
    def calibrate_from_anthropometry(
        self,
        keypoints_3d: np.ndarray,
        person_height_mm: Optional[float] = None
    ):
        """
        Calibrate scale using anthropometric measurements
        Uses average body proportions if height not provided
        """
        # Estimate height from keypoints (head to ankle distance)
        # Simplified: use average head-to-ankle distance
        head_idx = 0  # Nose
        ankle_idx = 16  # Right ankle
        
        if keypoints_3d.shape[1] > max(head_idx, ankle_idx):
            head_pos = keypoints_3d[:, head_idx, :]
            ankle_pos = keypoints_3d[:, ankle_idx, :]
            height_pixels = np.mean(np.linalg.norm(head_pos - ankle_pos, axis=1))
            
            # Average adult head-to-ankle is ~85% of total height
            if person_height_mm:
                estimated_height_pixels = person_height_mm * 0.85
            else:
                # Use average: ~1500mm for head-to-ankle
                estimated_height_pixels = 1500.0
            
            self.scale_factor = estimated_height_pixels / height_pixels
            logger.info(f"Anthropometric calibration: {self.scale_factor:.4f} mm/pixel")
    
    def pixel_to_mm(self, pixel_distance: float) -> float:
        """Convert pixel distance to millimeters"""
        if self.scale_factor is None:
            logger.warning("Scale not calibrated, returning pixel distance")
            return pixel_distance
        return pixel_distance * self.scale_factor
    
    def mm_to_pixel(self, mm_distance: float) -> float:
        """Convert millimeter distance to pixels"""
        if self.scale_factor is None:
            logger.warning("Scale not calibrated, returning mm distance")
            return mm_distance
        return mm_distance / self.scale_factor


class KalmanDenoiser:
    """
    Kalman filter for denoising keypoint trajectories
    Eliminates jitter and "foot skating"
    """
    
    def __init__(self, num_joints: int = 17, process_noise: float = 0.01):
        self.num_joints = num_joints
        self.process_noise = process_noise
        self.filters = [self._create_filter() for _ in range(num_joints)]
    
    def _create_filter(self) -> KalmanFilter:
        """Create Kalman filter for single joint"""
        kf = KalmanFilter(dim_x=4, dim_z=2)  # 4D state (x, y, vx, vy), 2D measurement
        
        # State transition matrix (constant velocity model)
        kf.F = np.array([
            [1, 0, 1, 0],
            [0, 1, 0, 1],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        ], dtype=float)
        
        # Measurement matrix
        kf.H = np.array([
            [1, 0, 0, 0],
            [0, 1, 0, 0]
        ], dtype=float)
        
        # Process noise
        kf.Q = np.eye(4) * self.process_noise
        
        # Measurement noise
        kf.R = np.eye(2) * 0.1
        
        # Initial state
        kf.x = np.array([0, 0, 0, 0], dtype=float)
        kf.P = np.eye(4) * 100
        
        return kf
    
    def denoise_sequence(
        self,
        keypoints: np.ndarray,
        confidence: Optional[np.ndarray] = None
    ) -> np.ndarray:
        """
        Denoise keypoint sequence using Kalman filtering
        
        Args:
            keypoints: (num_frames, num_joints, 2 or 3) - Keypoint coordinates
            confidence: (num_frames, num_joints) - Optional confidence scores
        
        Returns:
            Denoised keypoints with same shape
        """
        num_frames, num_joints, dims = keypoints.shape
        
        # Reset filters
        for kf in self.filters:
            kf.x = np.array([0, 0, 0, 0], dtype=float)
            kf.P = np.eye(4) * 100
        
        denoised = np.zeros_like(keypoints)
        
        for frame_idx in range(num_frames):
            for joint_idx in range(num_joints):
                kf = self.filters[joint_idx]
                
                # Get measurement
                if dims == 2:
                    z = keypoints[frame_idx, joint_idx, :2]
                else:
                    z = keypoints[frame_idx, joint_idx, :2]  # Use x, y only
                
                # Update confidence-based measurement noise
                if confidence is not None:
                    conf = confidence[frame_idx, joint_idx]
                    kf.R = np.eye(2) * (0.1 / max(conf, 0.1))
                
                # Predict and update
                kf.predict()
                kf.update(z)
                
                # Store filtered position
                if dims == 2:
                    denoised[frame_idx, joint_idx] = kf.x[:2]
                else:
                    denoised[frame_idx, joint_idx, :2] = kf.x[:2]
                    denoised[frame_idx, joint_idx, 2] = keypoints[frame_idx, joint_idx, 2]
        
        return denoised


class FootContactConstraint:
    """
    Enforces foot-ground contact constraints
    Prevents "foot skating" artifacts
    """
    
    def __init__(self):
        self.ground_plane_z: Optional[float] = None
    
    def estimate_ground_plane(self, keypoints_3d: np.ndarray) -> float:
        """
        Estimate ground plane from foot keypoints
        
        Args:
            keypoints_3d: (num_frames, num_joints, 3) - 3D keypoints
        
        Returns:
            Z coordinate of ground plane
        """
        # Use ankle keypoints (indices 15, 16 for left/right ankle)
        ankle_indices = [15, 16]
        
        ankle_z = []
        for idx in ankle_indices:
            if idx < keypoints_3d.shape[1]:
                ankle_z.extend(keypoints_3d[:, idx, 2])
        
        if ankle_z:
            # Ground plane is at minimum Z (assuming Z is vertical, pointing up)
            self.ground_plane_z = np.percentile(ankle_z, 5)  # Use 5th percentile
            logger.info(f"Ground plane estimated at Z = {self.ground_plane_z:.2f}")
            return self.ground_plane_z
        
        return 0.0
    
    def apply_contact_constraints(
        self,
        keypoints_3d: np.ndarray,
        contact_flags: Optional[np.ndarray] = None
    ) -> np.ndarray:
        """
        Apply foot-ground contact constraints
        
        Args:
            keypoints_3d: (num_frames, num_joints, 3) - 3D keypoints
            contact_flags: (num_frames, 2) - Boolean flags for left/right foot contact
        
        Returns:
            Constrained keypoints
        """
        if self.ground_plane_z is None:
            self.estimate_ground_plane(keypoints_3d)
        
        constrained = keypoints_3d.copy()
        ankle_indices = [15, 16]  # Left and right ankle
        
        for frame_idx in range(keypoints_3d.shape[0]):
            for i, ankle_idx in enumerate(ankle_indices):
                if ankle_idx >= keypoints_3d.shape[1]:
                    continue
                
                # Check if foot should be in contact
                if contact_flags is not None and contact_flags[frame_idx, i]:
                    # Constrain ankle to ground plane
                    constrained[frame_idx, ankle_idx, 2] = self.ground_plane_z
                    
                    # Optionally constrain toe (if available)
                    toe_idx = ankle_idx - 2  # Approximate toe position
                    if 0 <= toe_idx < keypoints_3d.shape[1]:
                        constrained[frame_idx, toe_idx, 2] = self.ground_plane_z
        
        return constrained
    
    def detect_contact(
        self,
        keypoints_3d: np.ndarray,
        ankle_velocity_threshold: float = 50.0  # mm/s
    ) -> np.ndarray:
        """
        Detect foot-ground contact from keypoint motion
        
        Args:
            keypoints_3d: (num_frames, num_joints, 3) - 3D keypoints
            ankle_velocity_threshold: Velocity threshold for contact detection
        
        Returns:
            (num_frames, 2) - Boolean contact flags for left/right foot
        """
        num_frames = keypoints_3d.shape[0]
        contact_flags = np.zeros((num_frames, 2), dtype=bool)
        ankle_indices = [15, 16]
        
        for i, ankle_idx in enumerate(ankle_indices):
            if ankle_idx >= keypoints_3d.shape[1]:
                continue
            
            ankle_pos = keypoints_3d[:, ankle_idx, :]
            
            # Compute velocity
            velocity = np.diff(ankle_pos, axis=0)
            velocity_magnitude = np.linalg.norm(velocity, axis=1)
            
            # Contact when velocity is low and near ground
            if self.ground_plane_z is None:
                self.estimate_ground_plane(keypoints_3d)
            
            z_distance = np.abs(ankle_pos[:, 2] - self.ground_plane_z)
            
            # Contact: low velocity and near ground
            contact = (velocity_magnitude < ankle_velocity_threshold) & (z_distance < 20.0)  # 20mm threshold
            
            # Pad first frame
            contact_flags[1:, i] = contact
            contact_flags[0, i] = contact[0] if len(contact) > 0 else False
        
        return contact_flags


class EnvironmentalRobustnessService:
    """
    Main service for environmental robustness
    Combines scale calibration, denoising, and contact constraints
    """
    
    def __init__(self):
        self.scale_calibrator = ScaleCalibrator()
        self.kalman_denoiser = KalmanDenoiser()
        self.foot_contact = FootContactConstraint()
        logger.info("Environmental robustness service initialized")
    
    def process_keypoints(
        self,
        keypoints_3d: np.ndarray,
        confidence: Optional[np.ndarray] = None,
        reference_frame: Optional[np.ndarray] = None,
        reference_length_mm: Optional[float] = None
    ) -> Dict[str, np.ndarray]:
        """
        Apply full environmental robustness pipeline
        
        Args:
            keypoints_3d: (num_frames, num_joints, 3) - 3D keypoints
            confidence: (num_frames, num_joints) - Keypoint confidence
            reference_frame: Optional frame for reference object detection
            reference_length_mm: Optional known reference length
        
        Returns:
            Dictionary with processed keypoints and metadata
        """
        # Step 1: Scale calibration
        if reference_frame is not None:
            ref_size = self.scale_calibrator.detect_reference_object(reference_frame)
            if ref_size:
                self.scale_calibrator.calibrate_from_reference(
                    ref_size[0],
                    reference_length_mm or settings.DEFAULT_REFERENCE_LENGTH_MM
                )
        elif self.scale_calibrator.scale_factor is None:
            # Fallback to anthropometric calibration
            self.scale_calibrator.calibrate_from_anthropometry(keypoints_3d)
        
        # Convert to metric units
        if self.scale_calibrator.scale_factor:
            keypoints_3d_mm = keypoints_3d * self.scale_calibrator.scale_factor
        else:
            keypoints_3d_mm = keypoints_3d
        
        # Step 2: Denoising
        keypoints_2d = keypoints_3d_mm[:, :, :2]
        keypoints_denoised_2d = self.kalman_denoiser.denoise_sequence(
            keypoints_2d,
            confidence
        )
        keypoints_denoised = keypoints_3d_mm.copy()
        keypoints_denoised[:, :, :2] = keypoints_denoised_2d
        
        # Step 3: Foot contact constraints
        contact_flags = self.foot_contact.detect_contact(keypoints_denoised)
        keypoints_constrained = self.foot_contact.apply_contact_constraints(
            keypoints_denoised,
            contact_flags
        )
        
        return {
            'keypoints_3d_mm': keypoints_constrained,
            'scale_factor': self.scale_calibrator.scale_factor,
            'contact_flags': contact_flags,
            'ground_plane_z': self.foot_contact.ground_plane_z
        }

