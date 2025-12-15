# Sign Language Detector 🤟

Aplikasi Flutter untuk mendeteksi bahasa isyarat (ASL) secara real-time menggunakan kamera dan machine learning.

## 📋 Fitur

- ✅ Deteksi bahasa isyarat dari foto
- ✅ **Real-time detection** dengan kamera
- ✅ Overlay skeleton tangan (MediaPipe-style)
- ✅ Prediksi huruf ASL (A-Z)
- ✅ Auto-save prediksi setiap 3 detik
- ✅ Riwayat prediksi tersimpan

## 🛠️ Prerequisites

Pastikan sudah terinstall:

- **Flutter SDK** >= 3.9.2
- **Python** >= 3.10
- **Git**
- **Android Studio** (untuk emulator) atau HP Android fisik

## 🚀 Cara Menjalankan

### 1️⃣ Clone Repository

```bash
git clone <repository-url>
cd flutter_pbl
```

### 2️⃣ Install Flutter Dependencies

```bash
flutter pub get
```

### 3️⃣ Setup Python Server

#### a. Masuk ke folder server
```bash
cd server
```

#### b. Install Python dependencies
```bash
pip install -r requirements.txt
```

#### c. Pastikan file model ada di folder `server/`:
- `linear_svm_model.pkl` - Model SVM untuk prediksi
- `label_encoder.pkl` - Label encoder untuk konversi hasil


#### d. Jalankan server
```bash
uvicorn app:app --host 0.0.0.0 --port 8000
```

Server akan berjalan di `http://0.0.0.0:8000`

✅ Jika berhasil, akan muncul:
```
✓ Loaded model from .../linear_svm_model.pkl
✓ Loaded label encoder from .../label_encoder.pkl
Server ready!
INFO:     Uvicorn running on http://0.0.0.0:8000
```

### 4️⃣ Konfigurasi IP Address

#### Cek IP laptop Anda:

**Windows:**
```bash
ipconfig
```

**Mac/Linux:**
```bash
ifconfig
```

Cari `IPv4 Address` di adapter WiFi Anda (contoh: `192.168.1.100`)

#### Update IP di Flutter app:

Edit file `lib/services/predict_service.dart`:

```dart
static const String _baseUrl = 'http://<IP_LAPTOP_ANDA>:8000';
```

**Contoh:**
- Jika IP laptop `192.168.1.100`:
  ```dart
  static const String _baseUrl = 'http://192.168.1.100:8000';
  ```

- Jika menggunakan **Android Emulator**:
  ```dart
  static const String _baseUrl = 'http://10.0.2.2:8000';
  ```

### 5️⃣ Jalankan Flutter App

```bash
cd ..  # Kembali ke root folder
flutter run
```

Pilih device (emulator atau HP fisik).

## 📱 Cara Menggunakan Real-time Detection

1. **Login** ke aplikasi
2. Di halaman utama, tap tombol **"Real-time Detection"** (hijau)
3. Pastikan indikator server **berwarna hijau** (connected)
4. Tap **"Start"** untuk memulai deteksi
5. Arahkan tangan ke kamera
6. Prediksi huruf akan muncul di layar
7. Prediksi otomatis tersimpan setiap 3 detik

## 🔧 Troubleshooting

### ❌ "Server not connected"

1. **Pastikan server Python berjalan**
   ```bash
   cd server
   uvicorn app:app --host 0.0.0.0 --port 8000
   ```

2. **Pastikan HP dan laptop di jaringan WiFi yang sama**

3. **Cek IP sudah benar** di `predict_service.dart`

4. **Cek firewall Windows:**
   - Buka Windows Defender Firewall
   - Allow Python/port 8000

5. **Test koneksi dari HP:**
   - Buka browser di HP
   - Akses `http://<IP_LAPTOP>:8000/health`
   - Jika muncul `{"status":"ok"...}` = berhasil

### ❌ Menggunakan Hotspot HP

Jika laptop terhubung ke hotspot HP:

1. Aktifkan hotspot di HP
2. Hubungkan laptop ke hotspot
3. Cek IP baru di laptop (`ipconfig`)
4. Update IP di `predict_service.dart`
5. Rebuild app (`flutter run`)

IP hotspot biasanya:
- Android: `192.168.43.x`
- iPhone: `172.20.10.x`

### ❌ Camera permission denied

Pastikan permission kamera sudah diizinkan:
- Android: Settings > Apps > flutter_pbl > Permissions > Camera

### ❌ Model tidak ditemukan

Pastikan file berikut ada di folder `server/`:
- `linear_svm_model.pkl`
- `label_encoder.pkl`

## 📁 Struktur Project

```
flutter_pbl/
├── lib/
│   ├── main.dart                 # Entry point
│   ├── screens/
│   │   ├── splash_screen.dart
│   │   ├── login_screen.dart
│   │   ├── sign_language_detector_screen.dart
│   │   └── realtime_detection_screen.dart  # Real-time detection
│   ├── services/
│   │   ├── auth_service.dart
│   │   └── predict_service.dart  # HTTP client ke Python server
│   ├── widgets/
│   │   └── hand_overlay.dart     # Skeleton overlay
│   └── models/
│       └── prediction_item.dart
├── server/
│   ├── app.py                    # FastAPI server
│   ├── requirements.txt          # Python dependencies
│   ├── linear_svm_model.pkl      # Model ML (tidak di-commit)
│   └── label_encoder.pkl         # Label encoder (tidak di-commit)
├── android/
├── ios/
└── pubspec.yaml
```

## 🔗 API Endpoints

| Endpoint | Method | Deskripsi |
|----------|--------|-----------|
| `/health` | GET | Cek status server |
| `/predict` | POST | Prediksi dari landmarks |

**Contoh request `/predict`:**
```json
{
  "features": [0.1, 0.2, 0.3, ..., 0.63]  // 63 values (21 landmarks × 3 coords)
}
```

**Response:**
```json
{
  "prediction": "A",
  "confidence": 0.95
}
```

## 👥 Tim

- [Nama anggota tim]

## 📄 License

MIT License