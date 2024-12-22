"




import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yemek Tanıma',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  final picker = ImagePicker();
  String? _prediction;

  // Fotoğraf çekme
  Future getImageFromCamera() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    });
  }

  // Fotoğraf seçme
  Future getImageFromGallery() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    });
  }

  // Flask API'ye fotoğraf gönder ve tahmin al
  Future<void> predictImage() async {
    if (_image == null) return;

    final uri = Uri.parse('http://127.0.0.1:5099/predict');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('image', _image!.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      final res = await http.Response.fromStream(response);
      final data = json.decode(res.body);
      setState(() {
        _prediction = data.toString();
      });
    } else {
      setState(() {
        _prediction = 'Tahmin yapılamadı. Hata: ${response.statusCode}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yemek Tanıma')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _image == null
                  ? const Text(
                      'Bir fotoğraf seçin veya çekin.',
                      style: TextStyle(fontSize: 18),
                    )
                  : Image.file(_image!, height: 250, fit: BoxFit.cover),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: getImageFromCamera,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Fotoğraf Çek'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: getImageFromGallery,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Galeriden Seç'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: predictImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Tahmin Yap'),
              ),
              const SizedBox(height: 20),
              _prediction == null
                  ? const Text(
                      'Tahmin bekleniyor...',
                      style:
                          TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                    )
                  : Text(
                      'Tahmin: $_prediction',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                      textAlign: TextAlign.center,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}



" 
