clear all; close all; clc;

%% 1. KẾT NỐI CỔNG SERIAL COM
port = "COM3";        % <--- QUAN TRỌNG: SỬA THÀNH CỔNG COM CỦA ESP32 NHÀ BẠN
baudrate = 115200;

try
    s = serialport(port, baudrate);
    configureTerminator(s, "CR/LF");
    flush(s);
    disp('Da San Sang, Dat Tay len');
catch
    error('Không thể mở cổng COM! Hãy chắc chắn bạn đã tắt Serial Monitor bên Arduino.');
end

%% 2. THIẾT KẾ BỘ LỌC ĐỒNG BỘ TỐC ĐỘ CAO (Fs = 100 Hz)
Fs = 100; 
% Bộ lọc thông dải Butterworth bậc 2: Giữ lại tần số nhịp tim từ 0.5Hz đến 3.0Hz
[b_bp, a_bp] = butter(2, [0.5 3.0]/(Fs/2), 'bandpass');

% Khởi tạo mảng lưu trạng thái bộ lọc (Bắt buộc để lọc Real-time từng điểm)
z_red = zeros(max(length(b_bp), length(a_bp))-1, 1);

%% 3. THIẾT LẬP MÀN HÌNH GIÁM SÁT (MONITOR GUI)
window_sec = 5; % Màn hình hiển thị cửa sổ trượt dài 5 giây
window_length = window_sec * Fs; 
t_win = (0:window_length-1) / Fs;

% Tạo các bộ đệm chứa dữ liệu chạy trượt
red_raw_buf = zeros(1, window_length);
red_filt_buf = zeros(1, window_length);

fig = figure('Name', 'Hệ thống giám sát và phản hồi cảnh báo y khoa', 'Position', [100, 100, 900, 600]);

% Biểu đồ 1: Tín hiệu gốc tia Đỏ
ax1 = subplot(2,1,1);
h_raw = plot(t_win, red_raw_buf, 'k', 'LineWidth', 1);
title('1. Tín hiệu thô Tia Đỏ nhận từ ESP32 (Tần số cao 100Hz)');
ylabel('Giá trị số ADC'); grid on;

% Biểu đồ 2: Tín hiệu sau khi được lọc
ax2 = subplot(2,1,2);
h_filt = plot(t_win, red_filt_buf, 'r', 'LineWidth', 1.3);
title_filt = title('2. Tín hiệu đã lọc - Đang phân tích và đồng bộ nhịp tim...');
xlabel('Thời gian (giây)');
ylabel('Biên độ AC'); grid on;

%% 4. VÒNG LẶP XỬ LÝ VÀ PHẢN HỒI THỜI GIAN THỰC
count = 0;

while ishandle(fig)
    try
        % --- A. ĐỌC DỮ LIỆU THÔ ---
        dataStr = readline(s);
        red_val = str2double(dataStr);
        
        % Lọc nhiễu kỹ thuật: Bỏ qua nếu gói tin bị rác hoặc chưa đặt tay lên mắt đọc
        if isnan(red_val) || red_val < 5000
            continue; 
        end
        
        % --- B. LỌC REAL-TIME TỪNG ĐIỂM (Không gây trễ pha) ---
        [red_clean, z_red] = filter(b_bp, a_bp, red_val, z_red);
        
        % --- C. CẬP NHẬT CỬA SỔ TRƯỢT (Sliding Window) ---
        red_raw_buf(1:end-1) = red_raw_buf(2:end);
        red_raw_buf(end) = red_val;
        
        red_filt_buf(1:end-1) = red_filt_buf(2:end);
        red_filt_buf(end) = red_clean;
        
        count = count + 1;
        
        % --- D. THUẬT TOÁN ĐO & PHẢN HỒI CẢNH BÁO (Cập nhật mỗi 1 giây) ---
        if mod(count, Fs) == 0
            % Tìm các đỉnh nhịp tim trong bộ đệm 5 giây gần nhất
            [pks, locs] = findpeaks(red_filt_buf, 'MinPeakDistance', Fs * 0.33);
            
            if length(locs) >= 3
                % Tính thời gian trung bình giữa các nhịp và đổi ra số nhịp/phút (BPM)
                avg_interval = mean(diff(locs)) / Fs;
                BPM = 60 / avg_interval;
                if BPM > 100
                    % BẤT THƯỜNG (CA0): Ép đèn chớp cực nhanh (Cảnh báo)
                    % Giảm chu kỳ xuống rất thấp (dao động từ 250ms xuống 80ms)
                    blink_delay = 250 - (BPM - 100) * 10;
                    if blink_delay < 80; blink_delay = 80; end 
                    
                    writeline(s, num2str(round(blink_delay))); 
                    status_str = sprintf('Nhịp Tim nhanh: %.1f BPM - CẢNH BÁO!', BPM);
                    
                elseif BPM < 55
                    % BẤT THƯỜNG (THẤP): Ép đèn chớp cực nhanh (Cảnh báo)
                    blink_delay = 250 - (55 - BPM) * 20;
                    if blink_delay < 80; blink_delay = 80; end
                    
                    writeline(s, num2str(round(blink_delay))); 
                    status_str = sprintf('Nhịp Tim chậm: %.1f BPM - CẢNH BÁO!', BPM);
                    
                else
                    blink_delay = (60000 / BPM) / 2;
                    
                    writeline(s, num2str(round(blink_delay))); 
                    status_str = sprintf('Bình thường: %.1f BPM', BPM);
                end
                
                % Cập nhật tiêu đề đồ thị
                set(title_filt, 'String', status_str);
                
                set(title_filt, 'String', status_str);
                set(title_filt, 'String', status_str);
            else
                set(title_filt, 'String', 'Đang phân tích dữ liệu... Hãy giữ yên ngón tay!');
            end
        end
        
        % --- E. VẼ ĐỒ THỊ LÊN MÀN HÌNH (Tốc độ 25 Khung hình/giây) ---
        if mod(count, 4) == 0
            set(h_raw, 'YData', red_raw_buf);
            set(h_filt, 'YData', red_filt_buf);
            
            % Tự động scale trục Y ôm khít biên độ sóng để nhìn rõ nhất
            ylim(ax1, [min(red_raw_buf)-200, max(red_raw_buf)+200]);
            ylim(ax2, [min(red_filt_buf)-50, max(red_filt_buf)+50]);
            
            drawnow limitrate;
        end
    catch
        continue;
    end
        if mod(count, Fs) == 0
            
            % -----------------------------------------------------------
            % BƯỚC 1: TIỀN XỬ LÝ TOÀN BỘ CỬA SỔ (PRE-PROCESSING PIPELINE)
            % -----------------------------------------------------------
            buf_median = medfilt1(red_raw_buf, 5);

            buf_smooth = movmean(buf_median, 7);
            
            % 1.3. Lọc Dải Tần (Bandpass 0.5 - 3.0 Hz) lại một lần nữa trên buffer sạch
            % (Dùng filtfilt để không làm xô lệch vị trí các đỉnh sóng)
            buf_final = filtfilt(b_bp, a_bp, buf_smooth);
            
            % -----------------------------------------------------------
            % BƯỚC 2: KIỂM TRA CHẤT LƯỢNG TÍN HIỆU (SQI - Signal Quality)
            % -----------------------------------------------------------

            signal_variance = std(buf_final);
            
            % Ngưỡng 400 là giá trị kinh nghiệm (Bạn có thể tinh chỉnh lại cho phù hợp với tay mình)
            if signal_variance > 400 
                writeline(s, "ALERT_ON"); % Bật còi báo cho bệnh nhân biết đang đo sai
                set(title_filt, 'String', 'Vui lòng đặt tay nằm yên...');
                
            else
                % -----------------------------------------------------------
                % BƯỚC 3: TÍNH NHỊP TIM KHI TÍN HIỆU ĐÃ SẠCH VÀ ỔN ĐỊNH
                % -----------------------------------------------------------
                [pks, locs] = findpeaks(buf_final, 'MinPeakDistance', Fs * 0.33);
                
                if length(locs) >= 3
                    avg_interval = mean(diff(locs)) / Fs;
                    BPM = 60 / avg_interval;

                if BPM > 100

                    blink_delay = 250 - (BPM - 100) * 10;
                    if blink_delay < 80; blink_delay = 80; end 
                    
                    writeline(s, num2str(round(blink_delay))); 
                    status_str = sprintf('Canh Bao Nhip Nhanh %.1f BPM !', BPM);
                    
                elseif BPM < 55

                    blink_delay = 250 - (55 - BPM) * 20;
                    if blink_delay < 80; blink_delay = 80; end
                    
                    writeline(s, num2str(round(blink_delay))); 
                    status_str = sprintf('Canh Bao Nhip Tim Cham %.1f BPM !', BPM);
                    
                else
                    blink_delay = (60000 / BPM) / 2;
                    
                    writeline(s, num2str(round(blink_delay))); 
                    status_str = sprintf('BInh Thuong: %.1f BPM', BPM);
                end

                set(title_filt, 'String', status_str);
                else
                    set(title_filt, 'String', 'Dang Do');
                end
            end
            
       
            red_filt_buf = buf_final; 
        end
end

%% 5. GIẢI PHÓNG HỆ THỐNG KHI ĐÓNG ĐỒ THỊ
clear s;
disp('Dong COM');