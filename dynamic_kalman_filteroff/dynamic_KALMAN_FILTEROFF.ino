#include <Wire.h>
#include <Adafruit_BMP280.h>

Adafruit_BMP280 bmp;

//Kalman 1D
float Q = 0.01;
float R = 0.5;
float P = 5.0;
float K = 0.0;
float X_kalman = 0.0;

//20Hz
unsigned long lastTime  = 0;
unsigned long startTime = 0;
const unsigned long sampleInterval = 50;

float baselineAltitude = 0;
bool  sensorReady = false;
bool  lastState   = false;

float kalman_update(float z) {
  P = P + Q;
  K = P / (P + R);
  X_kalman = X_kalman + K * (z - X_kalman);
  P = (1 - K) * P;
  return X_kalman;
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
bmp.setSampling(Adafruit_BMP280::MODE_NORMAL,
                 Adafruit_BMP280::SAMPLING_X2, 
                 Adafruit_BMP280::SAMPLING_X16, 
                 Adafruit_BMP280::FILTER_OFF,   
                 Adafruit_BMP280::STANDBY_MS_1);

  float sumAlt = 0;
  Serial.println("Dang hieu chuan baseline...");
  for (int i = 0; i < 20; i++) {
    sumAlt += bmp.readAltitude(1013.25);
    delay(50);
  }
  baselineAltitude = sumAlt / 20.0;

  float firstRaw = bmp.readAltitude(1013.25) - baselineAltitude;
  X_kalman = firstRaw;
  P = 5.0;

  Serial.println("=== SAN SANG — DO TRONG 30 GIAY ===");
  Serial.println("Pressure(Pa),Raw(m),Kalman(m),State");
  delay(2000);
  startTime = millis();
}

void loop() {
  if (!sensorReady) return;

  if (millis() - startTime > 30000) return;

  unsigned long currentTime = millis();
  if (currentTime - lastTime >= sampleInterval) {
    lastTime = currentTime;

    float elapsedSeconds = (currentTime - startTime) / 1000.0;
    int   intervalType   = ((int)elapsedSeconds) / 5;
    bool  currentState   = (intervalType % 2 != 0);

    if (currentState != lastState) {
      lastState = currentState;
      Serial.println("");
      Serial.println(currentState
        ? ">>> [NHAC LEN CAO] <<<"
        : ">>> [DAT XUONG BAN] <<<");
    }

    float pressure    = bmp.readPressure();
    float rawAltitude = bmp.readAltitude(1013.25) - baselineAltitude;
    float filteredAlt = kalman_update(rawAltitude);
    float stateSignal = currentState ? 1.0 : 0.0;

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