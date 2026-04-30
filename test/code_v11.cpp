/*
#include <Wire.h>
#include <DS3231.h>
#include <DFRobot_MAX30102.h>

// Tạo "điều khiển từ xa" cho đồng hồ và đặt tên là myRTC
DS3231 myRTC;

// Tạo "điều khiển từ xa" cho cảm biến nhịp tim và đặt tên là particleSensor
DFRobot_MAX30102 particleSensor;

// Khai báo các "hộp" chứa dữ liệu
int32_t SPO2;           // Hộp chứa nồng độ oxy
int8_t SPO2Valid;       // Hộp chứa cờ kiểm tra (1 là đo chuẩn, 0 là đo lỗi)
int32_t heartRate;      // Hộp chứa nhịp tim
int8_t heartRateValid;  // Hộp chứa cờ kiểm tra nhịp tim

void setup() {
  Serial.begin(115200);
  Wire.begin(); // Mở kết nối I2C

  // Bấm nút khởi động cảm biến nhịp tim
  particleSensor.begin();

  // Cài đặt độ sáng LED (50), lấy trung bình 4 mẫu, đo cả Đỏ và Hồng ngoại
  particleSensor.sensorConfiguration(50, SAMPLEAVG_4, MODE_MULTILED, SAMPLERATE_100, PULSEWIDTH_411, ADCRANGE_16384);
}

void loop() {
  // 1. Đọc thời gian
  DateTime now = RTClib::now();

  // 2. Đọc nhịp tim và SPO2 (Thư viện tự động gom mẫu trong khoảng 4 giây)
  particleSensor.heartrateAndOxygenSaturation(&SPO2, &SPO2Valid, &heartRate, &heartRateValid);

  // 3. Kiểm tra xem thư viện báo dữ liệu có hợp lệ không (Valid == 1)
  if (heartRateValid == 1 && SPO2Valid == 1) {
    // In giờ:phút:giây
    Serial.print(now.hour());
    Serial.print(":");
    Serial.print(now.minute());
    Serial.print(":");
    Serial.print(now.second());

    // In nhịp tim và SPO2
    Serial.print(" - Nhip tim: ");
    Serial.print(heartRate);
    Serial.print(" | SPO2: ");
    Serial.println(SPO2);
  }
}
*/

#include <DFRobot_MAX30102.h>

DFRobot_MAX30102 particleSensor;

/*
Macro definition options in sensor configuration
sampleAverage: SAMPLEAVG_1 SAMPLEAVG_2 SAMPLEAVG_4
               SAMPLEAVG_8 SAMPLEAVG_16 SAMPLEAVG_32
ledMode:       MODE_REDONLY  MODE_RED_IR  MODE_MULTILED
sampleRate:    PULSEWIDTH_69 PULSEWIDTH_118 PULSEWIDTH_215 PULSEWIDTH_411
pulseWidth:    SAMPLERATE_50 SAMPLERATE_100 SAMPLERATE_200 SAMPLERATE_400
               SAMPLERATE_800 SAMPLERATE_1000 SAMPLERATE_1600 SAMPLERATE_3200
adcRange:      ADCRANGE_2048 ADCRANGE_4096 ADCRANGE_8192 ADCRANGE_16384
*/
void setup()
{
  // Init serial
  Serial.begin(115200);

  // //Ép ESP32 chạy ở xung nhịp tối đa 240MHz
  // setCpuFrequencyMhz(60);

  // // Kiểm tra xem nó đã thực sự chạy ở 240MHz chưa
  // int cpuSpeed = getCpuFrequencyMhz();
  // Serial.print("Toc do CPU hien tai: ");
  // Serial.print(cpuSpeed);
  // Serial.println(" MHz");

  while (!particleSensor.begin())
  {
    Serial.println("MAX30102 was not found");
    delay(1000);
  }

  // Set reasonably to make sure there is clear sawtooth figure on the serial plotter
  particleSensor.sensorConfiguration(/*ledBrightness=*/60, /*sampleAverage=*/SAMPLEAVG_16,
                                     /*ledMode=*/MODE_MULTILED, /*sampleRate=*/SAMPLERATE_1600,
                                     /*pulseWidth=*/PULSEWIDTH_411, /*adcRange=*/ADCRANGE_16384);
}

int32_t SPO2;          // SPO2
int8_t SPO2Valid;      // Flag to display if SPO2 calculation is valid
int32_t heartRate;     // Heart-rate
int8_t heartRateValid; // Flag to display if heart-rate calculation is valid

void loop()
{
  delay(10);

  // Serial.print(">IR_Signal:");
  Serial.print(particleSensor.getIR());
  Serial.print(",");
  // Serial.print(">RED_Signal:");
  Serial.println(particleSensor.getRed());

  // Serial.println(F("Wait about four seconds"));
  // particleSensor.heartrateAndOxygenSaturation(/**SPO2=*/&SPO2, /**SPO2Valid=*/&SPO2Valid, /**heartRate=*/&heartRate, /**heartRateValid=*/&heartRateValid);
  // //Print result
  // Serial.print(F("heartRate="));
  // Serial.print(heartRate, DEC);
  // Serial.print(F(", heartRateValid="));
  // Serial.print(heartRateValid, DEC);
  // Serial.print(F("; SPO2="));
  // Serial.print(SPO2, DEC);
  // Serial.print(F(", SPO2Valid="));
  // Serial.println(SPO2Valid, DEC);
}
