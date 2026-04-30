#include <Wire.h>
#include "DFRobot_MAX30102.h"

DFRobot_MAX30102 particleSensor;

unsigned long lastReadTime = 0;
const unsigned long INTERVAL_US = 20000; // 50Hz (20ms)

// Biến toàn cục để "tích tiểu thành đại" các ký tự nhận được
String inputString = ""; 

void setup() {
  Serial.begin(115200);
  while(!Serial);
  
  if (!particleSensor.begin()) { while (1); }

  // Cấu hình ban đầu
  particleSensor.sensorConfiguration(
    60, SAMPLEAVG_4, MODE_MULTILED, SAMPLERATE_50, PULSEWIDTH_411, ADCRANGE_16384
  );

  // Đặt trước dung lượng cho chuỗi để tránh làm phân mảnh RAM của ESP32
  inputString.reserve(10); 
}

void loop() {
  // =======================================================
  // NHIỆM VỤ 1: ĐỌC CẢM BIẾN ĐÚNG NHỊP 50Hz (Tuyệt đối ưu tiên)
  // =======================================================
  unsigned long currentTime = micros();
  if (currentTime - lastReadTime >= INTERVAL_US) {
    lastReadTime = currentTime;

    uint32_t irValue = particleSensor.getIR();
    uint32_t redValue = particleSensor.getRed();

    Serial.print(irValue);
    Serial.print(",");
    Serial.println(redValue);
  }

  // =======================================================
  // NHIỆM VỤ 2: LẮNG NGHE LỆNH TỪ MÁY TÍNH (Không chờ đợi)
  // =======================================================
  // Lệnh while này đọc cực nhanh, lấy hết các chữ CÓ SẴN rồi thoát ngay
  while (Serial.available() > 0) {
    char inChar = (char)Serial.read(); // Bốc 1 ký tự ra khỏi thùng thư

    if (inChar == '\n') { 
      // NẾU GẶP DẤU ENTER: Bắt đầu xử lý lệnh
      int newBrightness = inputString.toInt();

      if (newBrightness >= 0 && newBrightness <= 255) {
        // (Nhớ là bạn đã chuyển 2 hàm này sang public trong file .h rồi nhé)
        particleSensor.setPulseAmplitudeRed(newBrightness);
        particleSensor.setPulseAmplitudeIR(newBrightness);
      }
      
      // Xóa túi đồ đi để gom lệnh cho lần sau
      inputString = ""; 
      
    } else if (inChar != '\r') {
      // NẾU LÀ CHỮ SỐ BÌNH THƯỜNG: Cất vào túi
      inputString += inChar;
    }
  }
}

git remote add origin https://github.com/Agatha-Belle-atb/project_nhip_tim_vdk.git