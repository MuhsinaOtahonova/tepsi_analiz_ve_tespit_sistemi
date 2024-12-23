
from flask import Flask, request, jsonify
import torch
from PIL import Image
import io

app = Flask(__name__)

# YOLO modelini yükle
model = torch.hub.load('ultralytics/yolov5', 'custom', path='model/best.pt') 

@app.route('/predict', methods=['POST'])
def predict():
    if 'image' not in request.files:
        return jsonify({'error': 'No image uploaded'}), 400
    
    file = request.files['image']
    img_bytes = file.read()
    img = Image.open(io.BytesIO(img_bytes))

    # Modelden tahmin alın
    results = model(img)
    predictions = results.pandas().xyxy[0].to_dict(orient='records')  

    return jsonify(predictions)

if __name__ == '__main__':
    app.run(port=5061, debug=True)




