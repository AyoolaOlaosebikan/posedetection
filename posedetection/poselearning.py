from fastapi import FastAPI, Request, HTTPException
from pydantic import BaseModel, ValidationError
import json
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.neighbors import KNeighborsClassifier
from sklearn.preprocessing import LabelEncoder
import xgboost as xgb
from sklearn.metrics import accuracy_score
import boto3
import uuid
from datetime import datetime
from decimal import Decimal

app = FastAPI()

dynamodb = boto3.resource("dynamodb", region_name="us-east-1") 
table = dynamodb.Table("PoseData")

# In-memory storage
pose_data = []
model = None


class PoseData(BaseModel):
    features: dict
    label: str

class Features(BaseModel):
    features: dict

def convert_floats_to_decimal(data):
    if isinstance(data, list):
        return [convert_floats_to_decimal(item) for item in data]
    elif isinstance(data, dict):
        return {key: convert_floats_to_decimal(value) for key, value in data.items()}
    elif isinstance(data, float):
        return Decimal(str(data))  # Convert float to Decimal
    else:
        return data
    

@app.post("/upload_pose")
async def upload_pose(request: Request):

    body = await request.json()

    processed_body = convert_floats_to_decimal(body)

    pose = processed_body.get("label")
    features = processed_body.get("features")

    item_id = str(uuid.uuid4())
    timestamp = datetime.utcnow().isoformat()


    # Store data in DynamoDB
    item = {
        "pose_id": item_id,
        "timestamp": timestamp,
        "pose": pose,
        "features": features,
    }


    print(f"Label: {pose}")
    print(f"Features: {features}")
    print(f"message: Data stored successfully, id: {item_id}")

    table.put_item(Item=item)

    return {"message": "Data received"}


@app.post("/train_model")
def train_model(model_type: str):
    global model

    # Retrieve pose data from DynamoDB
    try:
        response = table.scan()  # You may want to paginate if you have a large dataset
        pose_data = response.get('Items', [])
        
        if not pose_data:
            raise HTTPException(status_code=400, detail="No data available for training")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving data from DynamoDB: {str(e)}")

    # Validate that pose_data has the required structure
    try:
        X = [list(item["features"].values()) for item in pose_data]
        y = [item["pose"] for item in pose_data]
    except KeyError as e:
        raise HTTPException(status_code=400, detail=f"Missing key in pose_data: {str(e)}")

    # Split data into training and testing sets
    # X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    # n_neighbors = min(len(X_test), 5)
    # Select model based on input
    if model_type == "random_forest":
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
        model = RandomForestClassifier()

    elif model_type == "xgboost":
        label_encoder = LabelEncoder()
        y_encoded = label_encoder.fit_transform(y)
        X_train, X_test, y_train, y_test = train_test_split(X, y_encoded, test_size=0.2, random_state=42)
        model = xgb.XGBClassifier(use_label_encoder=False, eval_metric='logloss')

    elif model_type == "knn":
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
        n_neighbors = min(len(X_test), 5)
        model = KNeighborsClassifier(n_neighbors=n_neighbors)  

    else:
        raise HTTPException(status_code=400, detail="Unsupported model type")

    # Train the model
    try:
        model.fit(X_train, y_train)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error during model training: {str(e)}")

    # Evaluate the model
    accuracy = model.score(X_test, y_test)
    
    # Return success message with accuracy
    return {"message": "Model trained successfully", "accuracy": accuracy}

def flatten_dict(d, parent_key='', sep='_'):
    items = []
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k
        if isinstance(v, dict):
            items.extend(flatten_dict(v, new_key, sep=sep).items())
        else:
            items.append((new_key, v))
    return dict(items)

# flat_features = flatten_dict(features)
# feature_vector = np.array([float(value) for value in flat_features.values()]).reshape(1, -1)

@app.post("/predict_pose")
def predict_pose(request: Features):
    global model
    if not model:
        raise HTTPException(status_code=400, detail="No model trained yet")

    # Ensure features contain only numerical values
    # try:
    #     feature_vector = np.array([float(value) for value in features.values()]).reshape(1, -1)
    # except ValueError:
    #     raise HTTPException(status_code=400, detail="Invalid feature values. Ensure all values are numbers.")
    try:
        flat_features = flatten_dict(request.features)
        feature_vector = np.array([float(value) for value in flat_features.values()]).reshape(1, -1)
        prediction = model.predict(feature_vector)
        return {"prediction": prediction.tolist()}
    except ValidationError as e:
        return {"error": str(e)}

@app.get("/compare_models")
def compare_models():
    global model

    # Retrieve pose data from DynamoDB
    try:
        response = table.scan()  # Scan the DynamoDB table
        pose_data = response.get("Items", [])
        
        if not pose_data:
            raise HTTPException(status_code=400, detail="No data available for training")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving data from DynamoDB: {str(e)}")

    # Validate that pose_data has the required structure
    try:
        X = [list(item["features"].values()) for item in pose_data]
        y = [item["pose"] for item in pose_data]
    except KeyError as e:
        raise HTTPException(status_code=400, detail=f"Missing key in pose_data: {str(e)}")

    # Split data into training and testing sets
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    # Initialize models for comparison
    models = {
        "random_forest": RandomForestClassifier(),
        "xgboost": xgb.XGBClassifier(use_label_encoder=False, eval_metric="logloss"),
        "knn": KNeighborsClassifier(n_neighbors=min(len(X_test), 5))
    }

    # Dictionary to store results
    results = {}

    # Train and evaluate each model
    for model_name, model_instance in models.items():
        try:
            if model_name == "xgboost":
                # Encode labels for XGBoost
                label_encoder = LabelEncoder()
                y_train_encoded = label_encoder.fit_transform(y_train)
                y_test_encoded = label_encoder.transform(y_test)
                model_instance.fit(X_train, y_train_encoded)
                y_pred = model_instance.predict(X_test)
                accuracy = accuracy_score(y_test_encoded, y_pred)
            else:
                model_instance.fit(X_train, y_train)
                y_pred = model_instance.predict(X_test)
                accuracy = accuracy_score(y_test, y_pred)

            results[model_name] = {"accuracy": accuracy}
        except Exception as e:
            results[model_name] = {"error": f"Error training {model_name}: {str(e)}"}

    # Return comparison results
    best_model = max(results, key=lambda k: results[k].get("accuracy", 0))
    return {"comparison": results, "best_model": best_model}
