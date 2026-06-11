#include <Wire.h>
#include <Adafruit_BMP280.h>

Adafruit_BMP280 bmp;

// CẤU HÌNH BỘ LỌC EMA
const float EMA_ALPHA = 0.08f;
                               
                               
float ema_value = 0.0f;         
float P0        = 101325.0f;    

// CẤU HÌNH THỜI GIAN VÀ MẪU ĐO
const unsigned long SAMPLE_INTERVAL_MS = 50;
const int MAX_SAMPLES  = 200;
const int TOTAL_STEPS  = 6;
const int WARMUP_SEC   = 15;
const int P0_SAMPLES   = 200;

// CÁC BIẾN TRẠNG THÁI HỆ THỐNG
int           currentStep    = 0;
int           sampleCount    = 0;
bool          measuring      = false;
bool          waitingForCmd  = false;
unsigned long lastSampleTime = 0;

const char* stepNames[] = {
  "Moc (Bac 0)",
  "Bac 1", "Bac 2", "Bac 3", "Bac 4", "Bac 5"
};

float pressureToAltitude(float P, float P_ref) {
  return 44330.0f * (1.0f - pow((P / P_ref), 0.1903f));
}

// -----------------------------------------------
// Thuật toán EMA 1 chiều
// y[n] = α * x[n] + (1 - α) * y[n-1]
// -----------------------------------------------
float emaUpdate(float measurement) {
  ema_value = EMA_ALPHA * measurement + (1.0f - EMA_ALPHA) * ema_value;
  return ema_value;
}

void flushSerial() {
  while (Serial.available()) Serial.read();
}

float takeP0() {
  Serial.println("# Xa mau nhieu (2.5 giay)...");
  for (int i = 0; i < 50; i++) {
    bmp.readPressure();
    delay(50);
  }

  Serial.println("# Lay trung binh P0 (10 giay)...");
  double sum = 0;
  float  pMin = 999999.0f, pMax = 0.0f;
  for (int i = 0; i < P0_SAMPLES; i++) {
    float p = bmp.readPressure();
    sum += p;
    if (p < pMin) pMin = p;
    if (p > pMax) pMax = p;
    delay(50);
  }

  float p0     = (float)(sum / P0_SAMPLES);
  float spread = pMax - pMin;

  Serial.print("P0       = "); Serial.print(p0, 2);     Serial.println(" Pa");
  Serial.print("P0 min   = "); Serial.print(pMin, 2);   Serial.println(" Pa");
  Serial.print("P0 max   = "); Serial.print(pMax, 2);   Serial.println(" Pa");
  Serial.print("P0 spread= "); Serial.print(spread, 2); Serial.println(" Pa");

  if (spread > 3.0f) {
    Serial.println("P0 chua dat do on dinh cao nhat (spread > 3 Pa)!");
    Serial.println("# Kiem tra lai tiep xuc chan hoac moi truong co gio lua.");
  } else {
    Serial.println("# P0 on dinh cuc tot (spread <= 3 Pa) [OK]");
  }

  return p0;
}

void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10);

  if (!bmp.begin(0x76)) {
    Serial.println("ERROR: Khong tim thay cam bien BMP280!");
    while (1) delay(100);
  }

  bmp.setSampling(
    Adafruit_BMP280::MODE_NORMAL,
    Adafruit_BMP280::SAMPLING_X4,
    Adafruit_BMP280::SAMPLING_X16,
    Adafruit_BMP280::FILTER_X16,
    Adafruit_BMP280::STANDBY_MS_1
  );

  Serial.println("Cho cam bien on dinh nhiet...");
  Serial.println("Go 'S' + Enter de bo qua giai doan nay");

  for (int i = WARMUP_SEC; i > 0; i--) {
    if (Serial.available()) {
      char c = Serial.read();
      flushSerial();
      if (c == 'S' || c == 's') {
        Serial.println("# >> Bo qua thoi gian warmup.");
        break;
      }
    }
    if (i % 5 == 0 || i <= 5) {
      Serial.print("Con lai: ");
      Serial.print(i);
      Serial.println(" giay...");
    }
    delay(1000);
  }

  P0        = takeP0();
  ema_value = 0.0f;  // Reset EMA về 0 (tương đương độ cao mốc)

  // Header CSV — đổi cột Kalman → EMA
  Serial.println("Time_ms,StepID,StepName,Pressure_Pa,Temp_C,Alt_Raw_m,Alt_EMA_m");

  Serial.print("[BAC 0] "); Serial.println(stepNames[0]);
  Serial.println("Dat cam bien tai MOC -> Gui bat ky ky tu nao + Enter de bat dau...");
  waitingForCmd = true;
  flushSerial();
}

void loop() {
  if (waitingForCmd) {
    if (Serial.available() > 0) {
      flushSerial();
      waitingForCmd = false;
      measuring     = true;
      sampleCount   = 0;

      // Khởi tạo EMA bằng giá trị đo đầu tiên (tránh giật khi bắt đầu)
      ema_value      = pressureToAltitude(bmp.readPressure(), P0);
      lastSampleTime = millis();
      Serial.print(">> Bat dau do: "); Serial.println(stepNames[currentStep]);
    }
    return;
  }

  if (measuring) {
    unsigned long now = millis();
    if (now - lastSampleTime >= SAMPLE_INTERVAL_MS) {
      lastSampleTime = now;

      float pressure    = bmp.readPressure();
      float temperature = bmp.readTemperature();

      float alt_raw = pressureToAltitude(pressure, P0);
      float alt_ema = emaUpdate(alt_raw);   // << EMA thay Kalman

      Serial.print(now);                    Serial.print(",");
      Serial.print(currentStep);            Serial.print(",");
      Serial.print(stepNames[currentStep]); Serial.print(",");
      Serial.print(pressure, 2);            Serial.print(",");
      Serial.print(temperature, 2);         Serial.print(",");
      Serial.print(alt_raw, 3);             Serial.print(",");
      Serial.println(alt_ema, 3);

      sampleCount++;

      if (sampleCount >= MAX_SAMPLES) {
        measuring = false;
        Serial.print(">> Xong: "); Serial.print(stepNames[currentStep]);
        Serial.print(" | P0="); Serial.print(P0, 2); Serial.println(" Pa");

        currentStep++;

        if (currentStep >= TOTAL_STEPS) {
          Serial.println("He thong da thu thap du 6 bac x 200 mau.");
          while (1) delay(1000);
        } else {
          Serial.print("HAY DI CHUYEN DEN: ");
          Serial.println(stepNames[currentStep]);
          Serial.println("Dat co dinh, cho 3 giay cho on dinh, roi gui ky tu bat ky + Enter...");
          waitingForCmd = true;
          flushSerial();
        }
      }
    }
  }
}