import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart'; // JSON dosyasını almak için

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
  List<dynamic> detectedFood = [];

  // JSON verisini yükleme
  Future<List<Map<String, dynamic>>> loadYemekler() async {
    String jsonString = await rootBundle.loadString('assets/yemekler2.json');
    List<dynamic> jsonData = json.decode(jsonString);
    return jsonData.map((e) => e as Map<String, dynamic>).toList();
  }

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

    final uri = Uri.parse('http://127.0.0.1:5061/predict');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('image', _image!.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      final res = await http.Response.fromStream(response);
      final data = json.decode(res.body);

      List<dynamic> classList = [];
      for (var prediction in data) {
        classList.add(prediction['class']);
      }

      List<Map<String, dynamic>> yemekler = await loadYemekler();
      List<dynamic> matchedFoods = [];

      for (var classId in classList) {
        var matchedFood = yemekler.firstWhere((food) => food['id'] == classId,
            orElse: () => {});
        if (matchedFood.isNotEmpty) {
          matchedFoods.add(matchedFood);
        }
      }

      setState(() {
        detectedFood = matchedFoods;
      });
    } else {
      setState(() {
        _prediction = 'Tahmin yapılamadı. Hata: ${response.statusCode}';
      });
    }
  }

  // Menü türünü belirleme
  String getMenuType() {
    int anaYemekCount =
        detectedFood.where((food) => food['type'] == 'Ana yemek').length;
    int yardimciYemekCount =
        detectedFood.where((food) => food['type'] == 'Yardımcı yemek').length;
    int ekmekCount = detectedFood.where((food) => food['type'] == '-').length;
    int suCount = detectedFood.where((food) => food['type'] == 'Su').length;
    int etsizYemekCount =
        detectedFood.where((food) => food['type'] == 'Etsiz ana yemek').length;
    int etliYemekCount =
        detectedFood.where((food) => food['type'] == 'Etli ana yemek').length;

    // Menü 2 için koşul
    if (etsizYemekCount == 1 &&
        yardimciYemekCount == 1 &&
        ekmekCount == 1 &&
        suCount == 1) {
      return 'Menü 2';
    }
    // Menü 3 için koşul
    else if (etsizYemekCount == 1 &&
        yardimciYemekCount == 0 &&
        ekmekCount == 1 &&
        suCount == 1) {
      return 'Menü 3';
    }
    // Fix Menü için koşul
    else if (anaYemekCount == 1 && yardimciYemekCount == 3) {
      return 'Fix Menü';
    }
    // Menü 1 için koşul
    else if (anaYemekCount == 1 && yardimciYemekCount == 1 && ekmekCount == 1) {
      return 'Menü 1';
    }
    return 'Menü Değil';
  }

// Menü fiyatlarını belirleme
  double getMenuPrice(String menuType) {
    if (menuType == 'Menü 2') {
      // Menü 2 fiyatları
      int etsizYemekCount = detectedFood
          .where((food) => food['type'] == 'Etsiz ana yemek')
          .length;
      int suCount = detectedFood.where((food) => food['type'] == 'Su').length;
      int ekmekCount = detectedFood.where((food) => food['type'] == '-').length;
      int yardimciYemekCount =
          detectedFood.where((food) => food['type'] == 'Yardımcı yemek').length;

      // Menü 2 fiyat kontrolü
      if (etsizYemekCount == 1 &&
          yardimciYemekCount == 1 &&
          ekmekCount == 1 &&
          suCount == 1) {
        return 73.0; // Menü 2 fiyatı
      }
      // Menü 3 fiyat kontrolü
      if (etsizYemekCount == 1 && ekmekCount == 1 && suCount == 1) {
        return 53.0; // Menü 3 fiyatı
      }
    }
    // Fix Menü için fiyat
    if (menuType == 'Fix Menü') {
      return 132.0;
    }
    // Menü 1 için fiyat
    else if (menuType == 'Menü 1') {
      return 106.0;
    }
    return getTotalPrice(); // Menü değilse toplam fiyatı döndür
  }

// Toplam kalori hesaplama
  double getTotalCalorie() {
    return detectedFood.fold(0, (sum, food) => sum + food['calories']);
  }

// Toplam fiyat hesaplama
  double getTotalPrice() {
    return detectedFood.fold(0, (sum, food) => sum + food['price']);
  }

// Tasarruf hesaplama
  double getSaving(double totalPrice, double menuPrice) {
    return totalPrice - menuPrice;
  }

// Adet hesaplama ve tekrarlayan yemekleri tek bir yemek olarak göstermek için güncelleme

  @override
  Widget build(BuildContext context) {
    // Menü tipi, toplam kalori, toplam fiyat, menü fiyatı ve tasarruf hesaplamaları
    String menuType = getMenuType();
    double totalCalorie = getTotalCalorie();
    double totalPrice = getTotalPrice();
    double menuPrice = getMenuPrice(menuType);
    double saving = getSaving(totalPrice, menuPrice);
    double saving2 = 450;
    double totalPrice2 = 2900;
    double totalCalorie2 = 4300;

    // Benzersiz yemekler
    List<Map<String, dynamic>> uniqueFoods = [];
    for (var food in detectedFood) {
      if (!uniqueFoods.any((item) => item['id'] == food['id'])) {
        uniqueFoods.add(food);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Yemek Tanıma')),
      body: SingleChildScrollView(
        child: Align(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Fotoğraf çekme butonları ve tahmin yapma butonu
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: getImageFromCamera,
                      child: const Text('Fotoğraf Çek'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: getImageFromGallery,
                      child: const Text('Galeriden Seç'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: predictImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Tahmin Yap'),
                ),
                const SizedBox(height: 20),
                _image == null
                    ? const Text('')
                    : Image.file(_image!, height: 250, fit: BoxFit.cover),
                const SizedBox(height: 20),
                _prediction == null
                    ? const Text('')
                    : Text(_prediction!,
                        style: const TextStyle(fontSize: 18),
                        textAlign: TextAlign.center),
                const SizedBox(height: 20),
                if (detectedFood.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 10,
                      horizontalMargin: 10,
                      dataRowHeight: 60,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.black,
                          width: 1.0,
                        ),
                      ),
                      columns: [
                        DataColumn(
                          label: Text('Adet',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center),
                        ),
                        DataColumn(
                          label: Text('Yemek İsmi',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center),
                        ),
                        DataColumn(
                          label: Text('Türü',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center),
                        ),
                        DataColumn(
                          label: Text('Kalori',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center),
                        ),
                        DataColumn(
                          label: Text('Fiyat',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center),
                        ),
                      ],
                      rows: List.generate(
                        uniqueFoods.length,
                        (index) {
                          var food = uniqueFoods[index];

                          // Aynı yemeklerin adet sayısını hesaplama
                          int adet = detectedFood
                              .where((item) => item['id'] == food['id'])
                              .length;

                          // Toplam kalori ve fiyat hesaplamaları
                          double totalFoodPrice =
                              food['price'] * adet.toDouble();
                          double totalFoodCalorie =
                              food['calories'] * adet.toDouble();

                          String type = '';
                          if (food['price'] == 33 || food['price'] == 26) {
                            type = 'Yardımcı yemek';
                          } else if (food['price'] == 100) {
                            type = 'Etli ana yemek';
                          } else if (food['price'] == 75) {
                            type = 'Etsiz ana yemek';
                          } else if (food['price'] == 5) {
                            type = '-';
                          }

                          return DataRow(cells: [
                            DataCell(
                                Text('$adet', textAlign: TextAlign.center)),
                            DataCell(
                                Text(food['name'], textAlign: TextAlign.left)),
                            DataCell(Text(type, textAlign: TextAlign.left)),
                            DataCell(Text(
                                '${totalFoodCalorie.toStringAsFixed(0)} cal',
                                textAlign: TextAlign.left)),
                            DataCell(Text(
                                '${totalFoodPrice.toStringAsFixed(2)} TL',
                                textAlign: TextAlign.left)),
                          ]);
                        },
                      ),
                      border: TableBorder(
                        horizontalInside:
                            BorderSide(color: Colors.black, width: 1),
                        verticalInside:
                            BorderSide(color: Colors.black, width: 1),
                        bottom: BorderSide(color: Colors.black, width: 1),
                        top: BorderSide(color: Colors.black, width: 1),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                if (detectedFood.isNotEmpty)
                  Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.black, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Text('Toplam Kalori:  ',
                                style: TextStyle(fontSize: 14)),
                            Text('${totalCalorie.toStringAsFixed(0)} kcal',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.green)), // Yeşil yazı
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.black, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Text('Toplam Fiyat:  ',
                                style: TextStyle(fontSize: 14)),
                            Text('${totalPrice.toStringAsFixed(2)} TL',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.green)), // Yeşil yazı
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.black, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Text('Menü?:  ',
                                style: TextStyle(fontSize: 14)),
                            Text('$menuType',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.green)), // Yeşil yazı
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.black, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Text('Menü Fiyatı:  ',
                                style: TextStyle(fontSize: 14)),
                            Text('${menuPrice.toStringAsFixed(2)} TL',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.green)), // Yeşil yazı
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.black, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Text('Tasarruf:  ',
                                style: TextStyle(fontSize: 14)),
                            Text('${saving.toStringAsFixed(2)} TL',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.green)), // Yeşil yazı
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                if (detectedFood.isNotEmpty)
                  Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.black, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Text('Aylık Toplam Kalori:  ',
                                style: TextStyle(fontSize: 14)),
                            Text('${totalCalorie2.toStringAsFixed(0)} kcal',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Color.fromARGB(
                                        255, 175, 76, 76))), // Yeşil yazı
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.black, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Text('Aylık Toplam Maliyet:  ',
                                style: TextStyle(fontSize: 14)),
                            Text('${totalPrice2.toStringAsFixed(2)} TL',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Color.fromARGB(
                                        255, 175, 76, 76))), // Yeşil yazı
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.black, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Text('Aylık Toplam Tasarruf:  ',
                                style: TextStyle(fontSize: 14)),
                            Text('${saving2.toStringAsFixed(2)} TL',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Color.fromARGB(
                                        255, 175, 76, 76))), // Yeşil yazı
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
