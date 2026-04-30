#include <Wire.h>
#include "DFRobot_MAX30102.h"
// Bắt buộc phải include file thuật toán tính toán của DFRobot
#include <SPO2/algorithm.h>

DFRobot_MAX30102 particleSensor;

// Tạo 2 "cái rổ" để tự gom dữ liệu
uint32_t irBuffer[100];
uint32_t redBuffer[100];
int32_t bufferIndex = 0; // Biến đếm xem đã gom được bao nhiêu mẫu

// Các biến lưu kết quả
int32_t SPO2, heartRate;
int8_t SPO2Valid, heartRateValid;

// Biến quản lý thời gian
unsigned long lastReadTime = 0;
// Nếu SampleRate = 400Hz -> Cứ 2500 micro-giây sẽ có 1 mẫu mới
const unsigned long READ_INTERVAL_US = 2500;

void setup()
{
  Serial.begin(115200);
  while (!Serial)
    ;

  if (!particleSensor.begin())
  {
    Serial.println("Loi ket noi!");
    while (1)
      ;
  }

  // Cấu hình Sample Rate là 400
  particleSensor.sensorConfiguration(
      60, SAMPLEAVG_1, MODE_MULTILED, SAMPLERATE_400, PULSEWIDTH_411, ADCRANGE_16384);
}

void loop()
{
  unsigned long currentTime = micros();

  // BƯỚC 1: CHỈ ĐỌC KHI ĐÃ ĐẾN HẸN (Không gọi getIR liên tục để tránh bị block)
  if (currentTime - lastReadTime >= READ_INTERVAL_US)
  {
    lastReadTime = currentTime;

    // Đọc 1 mẫu và cất ngay vào mảng
    // Vì ta canh đúng thời gian, hàm này sẽ lấy được số ngay mà không bị dính delay(1)
    irBuffer[bufferIndex] = particleSensor.getIR();
    redBuffer[bufferIndex] = particleSensor.getRed();

    // Vẫn có thể in đồ thị mượt mà mỗi khi có 1 mẫu
    Serial.print(">IR_Signal:");
    Serial.println(irBuffer[bufferIndex]);

    bufferIndex++; // Tăng biến đếm lên 1

    // BƯỚC 2: KHI ĐÃ GOM ĐỦ 100 MẪU -> TÍNH TOÁN
    if (bufferIndex == 100)
    {
      // Đưa 2 mảng vào trực tiếp hàm thuật toán lõi của hãng Maxim
      // Hàm này xử lý 100 mẫu cực nhanh trên ESP32 (vài mili-giây)
      maxim_heart_rate_and_oxygen_saturation(
          irBuffer, 100, redBuffer,
          &SPO2, &SPO2Valid, &heartRate, &heartRateValid);

      // In kết quả ra (hoặc xử lý theo ý bạn)
      if (heartRateValid == 1 && SPO2Valid == 1)
      {
        Serial.print(">BPM:");
        Serial.println(heartRate);
        Serial.print(">SpO2:");
        Serial.println(SPO2);
      }

      // Reset biến đếm về 0 để gom đợt dữ liệu 100 mẫu tiếp theo
      bufferIndex = 0;
    }
  }

  // BƯỚC 3: MẠCH HOÀN TOÀN TỰ DO LÀM VIỆC KHÁC Ở ĐÂY
  // Bạn có thể đọc cảm biến khác, chạy WiFi, nháy LED... mà không lo bị khựng.
}
