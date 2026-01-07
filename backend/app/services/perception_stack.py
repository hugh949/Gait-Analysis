"""
Perception Stack: High-fidelity pose estimation
Supports HRNet and ViTPose backbones fine-tuned for older adults
"""
import torch
import torch.nn as nn
import cv2
import numpy as np
from typing import List, Dict, Tuple, Optional
from loguru import logger
from pathlib import Path

from app.core.config_simple import settings


class PoseEstimationBackbone(nn.Module):
    """Base class for pose estimation backbones"""
    
    def __init__(self, num_joints: int = 17, pretrained: bool = True):
        super().__init__()
        self.num_joints = num_joints
        self.pretrained = pretrained
    
    def forward(self, x):
        raise NotImplementedError


class HRNetBackbone(PoseEstimationBackbone):
    """
    HRNet (High-Resolution Network) for pose estimation
    Optimized for older adults and assistive devices
    """
    
    def __init__(self, num_joints: int = 17, pretrained: bool = True):
        super().__init__(num_joints, pretrained)
        # Simplified HRNet architecture
        # In production, use mmpose or torchvision models
        self.backbone = self._build_hrnet()
        self.head = nn.Conv2d(256, num_joints, kernel_size=1)
    
    def _build_hrnet(self):
        """Build HRNet backbone"""
        # Placeholder - integrate with mmpose in production
        # Output must match head input channels (256)
        return nn.Sequential(
            nn.Conv2d(3, 64, 7, 2, 3),
            nn.BatchNorm2d(64),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(3, 2, 1),
            # Add more layers to reach 256 channels
            nn.Conv2d(64, 128, 3, 2, 1),
            nn.BatchNorm2d(128),
            nn.ReLU(inplace=True),
            nn.Conv2d(128, 256, 3, 2, 1),
            nn.BatchNorm2d(256),
            nn.ReLU(inplace=True),
            # Add HRNet stages here in production
        )
    
    def forward(self, x):
        features = self.backbone(x)
        heatmaps = self.head(features)
        return heatmaps


class ViTPoseBackbone(PoseEstimationBackbone):
    """
    ViTPose (Vision Transformer for Pose Estimation)
    Alternative backbone with strong generalization
    """
    
    def __init__(self, num_joints: int = 17, pretrained: bool = True):
        super().__init__(num_joints, pretrained)
        # Placeholder - integrate with transformers library
        self.backbone = self._build_vitpose()
        self.head = nn.Linear(768, num_joints * 2)  # x, y coordinates
    
    def _build_vitpose(self):
        """Build ViTPose backbone"""
        # Placeholder - integrate with transformers in production
        return nn.Sequential(
            # Add ViT layers here
        )
    
    def forward(self, x):
        features = self.backbone(x)
        keypoints = self.head(features)
        return keypoints


class PoseEstimator:
    """
    Main pose estimation service
    Handles video processing and keypoint extraction
    """
    
    def __init__(self, model_type: str = "hrnet", device: str = "cuda"):
        self.model_type = model_type
        self.device = device if torch.cuda.is_available() else "cpu"
        self.model = self._load_model()
        self.model.eval()
        logger.info(f"Pose estimator initialized with {model_type} on {self.device}")
    
    def _load_model(self) -> PoseEstimationBackbone:
        """Load pose estimation model"""
        if self.model_type == "hrnet":
            model = HRNetBackbone(num_joints=17)
        elif self.model_type == "vitpose":
            model = ViTPoseBackbone(num_joints=17)
        else:
            raise ValueError(f"Unknown model type: {self.model_type}")
        
        # Load pretrained weights if available
        # NOTE: If loading old weights, they may not match new architecture
        if Path(settings.POSE_MODEL_PATH).exists():
            try:
                state_dict = torch.load(settings.POSE_MODEL_PATH, map_location=self.device)
                # Try to load with strict=False to allow architecture mismatches
                try:
                    model.load_state_dict(state_dict, strict=True)
                    logger.info(f"Loaded pretrained weights from {settings.POSE_MODEL_PATH}")
                except RuntimeError as e:
                    logger.warning(f"Could not load pretrained weights (architecture mismatch): {e}")
                    logger.info("Using randomly initialized weights (architecture changed)")
            except Exception as e:
                logger.warning(f"Could not load pretrained weights: {e}")
                logger.info("Using randomly initialized weights")
        
        return model.to(self.device)
    
    def preprocess_frame(self, frame: np.ndarray) -> torch.Tensor:
        """Preprocess video frame for model input"""
        # Resize to model input size (typically 256x256 or 384x384)
        frame_resized = cv2.resize(frame, (256, 256))
        # Normalize
        frame_normalized = frame_resized.astype(np.float32) / 255.0
        # Convert to tensor and add batch dimension
        frame_tensor = torch.from_numpy(frame_normalized).permute(2, 0, 1).unsqueeze(0)
        return frame_tensor.to(self.device)
    
    def extract_keypoints(self, frame: np.ndarray) -> Dict[str, np.ndarray]:
        """
        Extract 2D keypoints from a single frame
        
        Returns:
            Dictionary with 'keypoints' (N, 2) and 'confidence' (N,)
        """
        with torch.no_grad():
            frame_tensor = self.preprocess_frame(frame)
            output = self.model(frame_tensor)
            
            # Convert model output to keypoints
            if isinstance(output, torch.Tensor):
                # Assuming output is heatmaps
                keypoints, confidence = self._heatmaps_to_keypoints(output)
            else:
                # Direct keypoint prediction
                keypoints = output['keypoints'].cpu().numpy()
                confidence = output['confidence'].cpu().numpy()
        
        return {
            'keypoints': keypoints,
            'confidence': confidence
        }
    
    def _heatmaps_to_keypoints(self, heatmaps: torch.Tensor) -> Tuple[np.ndarray, np.ndarray]:
        """Convert heatmaps to keypoint coordinates"""
        batch_size, num_joints, h, w = heatmaps.shape
        heatmaps_np = heatmaps.cpu().numpy()
        
        keypoints = []
        confidences = []
        
        for j in range(num_joints):
            heatmap = heatmaps_np[0, j]
            # Find maximum location
            max_idx = np.unravel_index(np.argmax(heatmap), heatmap.shape)
            y, x = max_idx
            
            # Convert to original image coordinates (scale back)
            x_coord = (x / w) * 256  # Assuming 256x256 input
            y_coord = (y / h) * 256
            
            keypoints.append([x_coord, y_coord])
            confidences.append(float(heatmap[max_idx]))
        
        return np.array(keypoints), np.array(confidences)
    
    def process_video(self, video_path: str, progress_callback=None) -> List[Dict[str, np.ndarray]]:
        """
        Process entire video and extract keypoints for all frames
        
        Args:
            video_path: Path to video file
            progress_callback: Optional callback function(progress_pct, message) for progress updates
        
        Returns:
            List of keypoint dictionaries, one per frame
        """
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            raise ValueError(f"Could not open video: {video_path}")
        
        # Get total frame count
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
        duration_sec = total_frames / fps if fps > 0 else 0
        
        if progress_callback:
            progress_callback(5, f'Video loaded: {total_frames} frames, {duration_sec:.1f}s duration')
        
        results = []
        frame_count = 0
        last_progress_update = 0
        last_time_update = 0
        import time
        start_time = time.time()
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            keypoints = self.extract_keypoints(frame)
            keypoints['frame_id'] = frame_count
            results.append(keypoints)
            frame_count += 1
            
            # Update progress every 10 seconds OR every 5% OR every 10 frames
            current_time = time.time()
            time_since_update = current_time - last_time_update
            should_update = False
            
            if progress_callback and total_frames > 0:
                progress_pct = min(30 + int((frame_count / total_frames) * 70), 99)  # 30-99% range
                
                # Update if 10 seconds passed, or 5% progress, or every 10 frames
                if time_since_update >= 10.0 or progress_pct >= last_progress_update + 5 or frame_count % 10 == 0:
                    should_update = True
                
                if should_update:
                    frames_remaining = total_frames - frame_count
                    frames_processed = frame_count
                    elapsed_time = current_time - start_time
                    
                    # Calculate processing rate and time estimate
                    if frames_processed > 0 and elapsed_time > 0:
                        frames_per_second = frames_processed / elapsed_time
                        est_time_remaining = (frames_remaining / frames_per_second) if frames_per_second > 0 else 0
                        
                        # Format time estimate
                        if est_time_remaining > 60:
                            time_str = f'~{int(est_time_remaining / 60)}m {int(est_time_remaining % 60)}s remaining'
                        else:
                            time_str = f'~{int(est_time_remaining)}s remaining'
                        
                        message = f'Processing frame {frame_count}/{total_frames} ({frames_per_second:.1f} fps) - {time_str}'
                    else:
                        message = f'Processing frame {frame_count}/{total_frames}...'
                    
                    progress_callback(progress_pct, message)
                    last_progress_update = progress_pct
                    last_time_update = current_time
        
        cap.release()
        logger.info(f"Processed {frame_count} frames from {video_path}")
        
        if progress_callback:
            progress_callback(99, f'Completed processing {frame_count} frames')
        
        return results
    
    def get_joint_names(self) -> List[str]:
        """Return standard COCO keypoint names"""
        return [
            'nose', 'left_eye', 'right_eye', 'left_ear', 'right_ear',
            'left_shoulder', 'right_shoulder', 'left_elbow', 'right_elbow',
            'left_wrist', 'right_wrist', 'left_hip', 'right_hip',
            'left_knee', 'right_knee', 'left_ankle', 'right_ankle'
        ]


