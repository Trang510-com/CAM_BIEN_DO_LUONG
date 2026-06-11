#include <Wire.h>
#include <Adafruit_BMP280.h>

Adafruit_BMP280 bmp;

// --- Cấu hình bộ lọc EMA ---
// Hệ số alpha (0 < alpha <= 1). 
// Càng nhỏ -> Mượt hơn nhưng phản hồi chậm (trễ).
// Càng lớn -> Phản hồi nhanh nhưng ít lọc nhiễu hơn.
const float alpha = 0.1; 
float X_ema = 0.0; // Biến lưu giá trị sau lọc EMA

// 20Hz (Cứ 50ms lấy mẫu 1 lần)
unsigned long lastTime  = 0;
unsigned long startTime = 0;
const unsigned long sampleInterval = 50;

float baselineAltitude = 0;
bool  sensorReady = false;
bool  lastState   = false;

// Hàm cập nhật bộ lọc EMA
float ema_update(float z) {
  X_ema = (alpha * z) + ((1.0 - alpha) * X_ema);
  return X_ema;
}

void setup() {
  Serial.begin(115200);

  if (bmp.begin(0x76) || bmp.begin(0x77)) {
    sensorReady = true;
  }

  if (!sensorReady) {
    Serial.println("Khong tim thay BMP280!");
    return;
  }

  delay(100);
  
  // Cấu hình tối ưu cho BMP280 để đo cao độ phản hồi nhanh
  bmp.setSampling(Adafruit_BMP280::MODE_NORMAL,
                  Adafruit_BMP280::SAMPLING_X2, 
                  Adafruit_BMP280::SAMPLING_X16, 
                  Adafruit_BMP280::FILTER_X4,   
                  Adafruit_BMP280::STANDBY_MS_1);

  // Hiệu chuẩn Baseline (Độ cao gốc ban đầu)
  float sumAlt = 0;
  Serial.println("Dang hieu chuan baseline...");
  for (int i = 0; i < 20; i++) {
    sumAlt += bmp.readAltitude(1013.25);
    delay(50);
  }
  baselineAltitude = sumAlt / 20.0;

  // Khởi tạo giá trị ban đầu cho bộ lọc EMA bằng giá trị thực tế đầu tiên
  float firstRaw = bmp.readAltitude(1013.25) - baselineAltitude;
  X_ema = firstRaw;

  Serial.println("=== SAN SANG — DO TRONG 30 GIAY ===");
  Serial.println("Time(s),Pressure(Pa),Raw(m),EMA(m),State");
  delay(2000);
  startTime = millis();
}

void loop() {
  if (!sensorReady) return;

  // Dừng sau 30 giây chạy thử nghiệm
  if (millis() - startTime > 30000) return;

  unsigned long currentTime = millis();
  if (currentTime - lastTime >= sampleInterval) {
    lastTime = currentTime;

    float elapsedSeconds = (currentTime - startTime) / 1000.0;
    int   intervalType   = ((int)elapsedSeconds) / 5;
    bool  currentState   = (intervalType % 2 != 0);

    // Thông báo trạng thái đổi hành động (mỗi 5 giây)
    if (currentState != lastState) {
      lastState = currentState;
      Serial.println("");
      Serial.println(currentState
        ? ">>> [NHAC LEN CAO] <<<"
        : ">>> [DAT XUONG BAN] <<<");
    }

    // Đọc dữ liệu từ cảm biến
    float pressure    = bmp.readPressure();
    float rawAltitude = bmp.readAltitude(1013.25) - baselineAltitude;
    
    // Lọc dữ liệu bằng EMA thay vì Kalman
    float filteredAlt = ema_update(rawAltitude);
    float stateSignal = currentState ? 1.0 : 0.0;

    // Xuất dữ liệu ra Serial Plotter / Serial Monitor
    Serial.print(elapsedSeconds, 2);
    Serial.print("s,");
    Serial.print(pressure, 2);
    Serial.print(",");
    Serial.print(rawAltitude, 3);
    Serial.print(",");
    Serial.print(filteredAlt, 3);
    Serial.print(",");
    Serial.println(stateSignal);
  }
}