from fastapi import FastAPI, Request
from pydantic import BaseModel
import json
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.neighbors import KNeighborsClassifier
import xgboost as xgb
from sklearn.metrics import accuracy_score

app = FastAPI()

# In-memory storage
pose_data = []
model = None
model_type = None

class PoseData(BaseModel):
    features: dict
    label: str

@app.post("/upload_pose")
async def upload_pose(request: Request):
    data = await request.json()
    pose_data.append(data)
    return {"message": "Pose data received", "data": data}

@app.post("/train_model")
def train_model(model_type: str):
    global model, model_type
    if not pose_data:
        return {"error": "No data available for training"}

    # Extract features and labels
    X = [list(item["features"].values()) for item in pose_data]
    y = [item["label"] for item in pose_data]

    # Split data into training and testing sets
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    # Train a classifier
    if model_type == "random_forest":
        model = RandomForestClassifier()
    elif model_type == "xgboost":
        model = xgb.XGBClassifier(use_label_encoder=False, eval_metric='logloss')
    elif model_type == "knn":
        model = KNeighborsClassifier()
    else:
        raise HTTPException(status_code=400, detail="Unsupported model type")

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

@app.post("/compare_models")
def compare_models():
    global model
    if not pose_data:
        raise HTTPException(status_code=400, detail="No data available for training")

    # Extract features and labels
    X = [list(item["features"].values()) for item in pose_data]
    y = [item["label"] for item in pose_data]

    # Split data into training and testing sets
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    # Initialize models for comparison
    models = {
        "random_forest": RandomForestClassifier(),
        "xgboost": xgb.XGBClassifier(use_label_encoder=False, eval_metric='logloss'),
        "knn": KNeighborsClassifier()
    }

    results = {}

    # Train and evaluate each model
    for model_name, model_instance in models.items():
        model_instance.fit(X_train, y_train)
        y_pred = model_instance.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        results[model_name] = accuracy

    # Return model comparison results
    return {"comparison": results}
