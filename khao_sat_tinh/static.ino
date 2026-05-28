
#include <Wire.h>
#include <Adafruit_BMP280.h>

Adafruit_BMP280 bmp;

//  Kalman 1D
float Q     = 0.01f;
float R     = 0.25f;
float x_est = 0.0f;
float P_est = 1.0f;
float P0    = 101325.0f;

//  Cấu hình 
const unsigned long SAMPLE_INTERVAL_MS = 50;
const int MAX_SAMPLES  = 200;
const int TOTAL_STEPS  = 6;       
const int WARMUP_SEC   = 20;
const int P0_SAMPLES   = 200;

// Trạng thái 
int  currentStep   = 0;
int  sampleCount   = 0;
bool measuring     = false;
bool waitingForCmd = false;
unsigned long lastSampleTime = 0;

const char* stepNames[] = {
  "Moc (mat dat)",
  "Bac 1", "Bac 2", "Bac 3", "Bac 4", "Bac 5"  
};


float pressureToAltitude(float P, float P_ref) {
  return 44330.0f * (1.0f - pow((P / P_ref), 0.1903f));
}

float kalmanUpdate(float z) {
  float P_prior = P_est + Q;
  float K       = P_prior / (P_prior + R);
  x_est         = x_est + K * (z - x_est);
  P_est         = (1.0f - K) * P_prior;
  return x_est;
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
  float  pMin = 999999, pMax = 0;
  for (int i = 0; i < P0_SAMPLES; i++) {
    float p = bmp.readPressure();
    sum += p;
    if (p < pMin) pMin = p;
    if (p > pMax) pMax = p;
    delay(50);
  }

  float p0     = (float)(sum / P0_SAMPLES);
  float spread = pMax - pMin;

  Serial.print("# P0       = "); Serial.print(p0, 2);     Serial.println(" Pa");
  Serial.print("# P0 min   = "); Serial.print(pMin, 2);   Serial.println(" Pa");
  Serial.print("# P0 max   = "); Serial.print(pMax, 2);   Serial.println(" Pa");
  Serial.print("# P0 spread= "); Serial.print(spread, 2); Serial.println(" Pa");

  if (spread > 5.0f) {
    Serial.println("# CANH BAO: P0 chua on dinh (spread > 5 Pa)!");
    Serial.println("# Khuyen nghi cho them 1 phut roi thu lai.");
  } else {
    Serial.println("# P0 on dinh tot (spread <= 5 Pa) ✓");
  }

  return p0;
}

void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10);

  if (!bmp.begin(0x76)) {
    Serial.println("ERROR: Khong tim thay BMP280!");
    while (1) delay(100);
  }

  bmp.setSampling(
    Adafruit_BMP280::MODE_NORMAL,
    Adafruit_BMP280::SAMPLING_X4,
    Adafruit_BMP280::SAMPLING_X16,
    Adafruit_BMP280::FILTER_X16,
    Adafruit_BMP280::STANDBY_MS_1
  );

  Serial.println("# Cho cam bien on dinh nhiet...");
  Serial.println("# (Co the go 'S' + Enter de bo qua neu");
  Serial.println("#  cam bien da bat duoc >= 5 phut)");

  for (int i = WARMUP_SEC; i > 0; i--) {
    if (Serial.available()) {
      char c = Serial.read();
      flushSerial();
      if (c == 'S' || c == 's') {
        Serial.println("# >> Bo qua warmup theo yeu cau.");
        break;
      }
    }
    if (i % 10 == 0 || i <= 10) {
      Serial.print("# Con lai: ");
      Serial.print(i);
      Serial.println(" giay...");
    }
    delay(1000);
  }

  Serial.println("# ==========================================");
  P0    = takeP0();
  x_est = 0.0f;
  P_est = 1.0f;

  Serial.println("Time_ms,Step,StepName,Alt_Raw_m,Alt_Kalman_m");

  Serial.print("# [BAC 0] "); Serial.println(stepNames[0]);
  Serial.println("# Dat cam bien tai moc -> gui bat ky ky tu + Enter...");
  waitingForCmd = true;
  flushSerial();
}

void loop() {
  if (waitingForCmd) {
    if (Serial.available() > 0) {
      flushSerial();
      waitingForCmd  = false;
      measuring      = true;
      sampleCount    = 0;
      x_est          = pressureToAltitude(bmp.readPressure(), P0);
      P_est          = 1.0f;
      lastSampleTime = millis();
      Serial.print("# >> Bat dau do: "); Serial.println(stepNames[currentStep]);
    }
    return;
  }

  if (measuring) {
    unsigned long now = millis();
    if (now - lastSampleTime >= SAMPLE_INTERVAL_MS) {
      lastSampleTime = now;

      float pressure   = bmp.readPressure();
      float alt_raw    = pressureToAltitude(pressure, P0);
      float alt_kalman = kalmanUpdate(alt_raw);

      Serial.print(now);                        Serial.print(",");
      Serial.print(currentStep);                Serial.print(",");
      Serial.print(stepNames[currentStep]);     Serial.print(",");
      Serial.print(alt_raw, 3);                 Serial.print(",");
      Serial.println(alt_kalman, 3);

      sampleCount++;

      if (sampleCount >= MAX_SAMPLES) {
        measuring = false;
        Serial.print("# >> Xong: "); Serial.print(stepNames[currentStep]);
        Serial.print(" | P0="); Serial.print(P0, 2); Serial.println(" Pa");

        currentStep++;

        if (currentStep >= TOTAL_STEPS) {
          Serial.println("# HOAN THANH! 6 bac x 200 mau.");         
    
        } else {
          Serial.print("# >> HAY DI CHUYEN DEN: ");
          Serial.println(stepNames[currentStep]);
          Serial.println("# Dat xuong, cho 3 giay, gui ky tu + Enter...");
          waitingForCmd = true;
          flushSerial();
        }
      }
    }
  }
}