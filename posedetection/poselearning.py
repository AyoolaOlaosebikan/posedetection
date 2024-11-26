from fastapi import FastAPI, Request
from pydantic import BaseModel
import json
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier

app = FastAPI()

# In-memory storage
pose_data = []
model = None

class PoseData(BaseModel):
    features: dict
    label: str

@app.post("/upload_pose")
async def upload_pose(request: Request):
    data = await request.json()
    pose_data.append(data)
    return {"message": "Pose data received", "data": data}

@app.post("/train_model")
def train_model():
    global model
    if not pose_data:
        return {"error": "No data available for training"}

    # Extract features and labels
    X = [list(item["features"].values()) for item in pose_data]
    y = [item["label"] for item in pose_data]

    # Split data into training and testing sets
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    # Train a classifier
    model = RandomForestClassifier()
    model.fit(X_train, y_train)

    # Evaluate the model
    accuracy = model.score(X_test, y_test)
    return {"message": "Model trained successfully", "accuracy": accuracy}

@app.post("/predict_pose")
def predict_pose(features: dict):
    global model
    if not model:
        return {"error": "No model trained yet"}
    
    # Convert features to a NumPy array
    feature_vector = np.array(list(features.values())).reshape(1, -1)
    prediction = model.predict(feature_vector)
    return {"prediction": prediction[0]}
