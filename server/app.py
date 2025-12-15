"""
Sign Language Prediction Server
================================
A FastAPI server that loads sklearn SVM model and provides predictions.

How to run:
-----------
1. Install dependencies:
   cd server
   pip install -r requirements.txt

2. Place your model files in the server directory:
   - linear_svm_model.pkl
   - label_encoder.pkl

3. Run the server:
   uvicorn app:app --host 0.0.0.0 --port 8000 --reload

4. For Android emulator, use host 10.0.2.2:8000
   For physical device on same network, use your PC's local IP (e.g., 192.168.x.x:8000)

API Endpoints:
--------------
POST /predict
  Request:  { "features": [0.1, 0.2, ...] }  # 63 values (21 landmarks * 3 coords)
  Response: { "prediction": "A", "confidence": 0.95 }

GET /health
  Response: { "status": "ok", "model_loaded": true }
"""

import os
import pickle
from typing import List, Optional

import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(
    title="Sign Language Prediction API",
    description="Real-time ASL letter prediction from hand landmarks",
    version="1.0.0"
)

# Enable CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global model variables
model = None
label_encoder = None
scaler = None  # Optional: if your pipeline includes StandardScaler


class PredictRequest(BaseModel):
    """Request body for prediction endpoint."""
    features: List[float]


class PredictResponse(BaseModel):
    """Response body for prediction endpoint."""
    prediction: str
    confidence: Optional[float] = None


class HealthResponse(BaseModel):
    """Response body for health check endpoint."""
    status: str
    model_loaded: bool
    label_encoder_loaded: bool


def load_models():
    """Load the SVM model and label encoder from pickle files."""
    global model, label_encoder, scaler
    
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    model_path = os.path.join(script_dir, "linear_svm_model.pkl")
    encoder_path = os.path.join(script_dir, "label_encoder.pkl")
    scaler_path = os.path.join(script_dir, "scaler.pkl")  # Optional
    
    # Load main model
    if os.path.exists(model_path):
        with open(model_path, "rb") as f:
            model = pickle.load(f)
        print(f"✓ Loaded model from {model_path}")
        print(f"  Model type: {type(model).__name__}")
    else:
        print(f"✗ Model file not found: {model_path}")
        print("  Please place your linear_svm_model.pkl in the server directory")
    
    # Load label encoder
    if os.path.exists(encoder_path):
        with open(encoder_path, "rb") as f:
            label_encoder = pickle.load(f)
        print(f"✓ Loaded label encoder from {encoder_path}")
        if hasattr(label_encoder, 'classes_'):
            print(f"  Classes: {list(label_encoder.classes_)}")
    else:
        print(f"✗ Label encoder not found: {encoder_path}")
        print("  Please place your label_encoder.pkl in the server directory")
    
    # Load scaler (optional)
    if os.path.exists(scaler_path):
        with open(scaler_path, "rb") as f:
            scaler = pickle.load(f)
        print(f"✓ Loaded scaler from {scaler_path}")
    else:
        print(f"  (Optional) Scaler not found: {scaler_path}")


@app.on_event("startup")
async def startup_event():
    """Load models when the server starts."""
    print("\n" + "="*50)
    print("Starting Sign Language Prediction Server")
    print("="*50 + "\n")
    load_models()
    print("\n" + "="*50)
    print("Server ready!")
    print("="*50 + "\n")


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Check if the server and models are ready."""
    return HealthResponse(
        status="ok",
        model_loaded=model is not None,
        label_encoder_loaded=label_encoder is not None
    )


@app.post("/predict", response_model=PredictResponse)
async def predict(request: PredictRequest):
    """
    Predict the sign language letter from hand landmark features.
    
    Expects 63 features: [x1, y1, z1, x2, y2, z2, ..., x21, y21, z21]
    where each landmark has normalized (x, y, z) coordinates.
    """
    if model is None:
        raise HTTPException(
            status_code=503,
            detail="Model not loaded. Please check server logs."
        )
    
    if label_encoder is None:
        raise HTTPException(
            status_code=503,
            detail="Label encoder not loaded. Please check server logs."
        )
    
    # Validate input
    features = request.features
    expected_features = 63  # 21 landmarks * 3 coordinates
    
    if len(features) != expected_features:
        raise HTTPException(
            status_code=400,
            detail=f"Expected {expected_features} features, got {len(features)}"
        )
    
    try:
        # Convert to numpy array and reshape for sklearn
        X = np.array(features).reshape(1, -1)
        
        # Apply scaler if available
        if scaler is not None:
            X = scaler.transform(X)
        
        # Get prediction
        prediction_idx = model.predict(X)[0]
        
        # Decode label
        if hasattr(label_encoder, 'inverse_transform'):
            prediction_label = label_encoder.inverse_transform([prediction_idx])[0]
        else:
            prediction_label = str(prediction_idx)
        
        # Get confidence if model supports it
        confidence = None
        if hasattr(model, 'predict_proba'):
            proba = model.predict_proba(X)[0]
            confidence = float(np.max(proba))
        elif hasattr(model, 'decision_function'):
            # For LinearSVC, use decision function scores
            scores = model.decision_function(X)[0]
            # Normalize to 0-1 range using softmax-like approach
            if isinstance(scores, np.ndarray):
                exp_scores = np.exp(scores - np.max(scores))
                confidence = float(np.max(exp_scores / exp_scores.sum()))
            else:
                confidence = None
        
        return PredictResponse(
            prediction=str(prediction_label),
            confidence=confidence
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Prediction error: {str(e)}"
        )


@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "name": "Sign Language Prediction API",
        "version": "1.0.0",
        "endpoints": {
            "POST /predict": "Predict letter from hand landmarks",
            "GET /health": "Check server and model status"
        },
        "usage": {
            "features": "Send 63 values [x1,y1,z1,...,x21,y21,z21]",
            "example": "POST /predict with {'features': [0.1, 0.2, ...]}"
        }
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
