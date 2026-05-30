% Xóa toàn bộ biến cũ, đóng đồ thị cũ và làm sạch màn hình lệnh
clear all; close all; clc;

%% 1. KẾT NỐI CỔNG SERIAL COM
port = "COM3";        
baudrate = 115200;
try
    s = serialport(port, baudrate);
    configureTerminator(s, "CR/LF");
    flush(s);
    disp('Đã Sẵn Sàng, Hãy Đặt Tay Lên Cảm Biến');
catch
    error('Không thể mở cổng COM! Hãy chắc chắn bạn đã tắt Serial Monitor bên Arduino.');
end

%% 2. THIẾT KẾ BỘ LỌC ĐỒNG BỘ TỐC ĐỘ CAO (Fs = 100 Hz)
Fs = 100; 
[b_bp, a_bp] = butter(2, [0.5 3.0]/(Fs/2), 'bandpass');
z_red = zeros(max(length(b_bp), length(a_bp))-1, 1);

%% 3. THIẾT LẬP MÀN HÌNH GIÁM SÁT (MONITOR GUI)
window_sec = 5; 
window_length = window_sec * Fs; 
t_win = (0:window_length-1) / Fs;

red_raw_buf = zeros(1, window_length);
red_filt_buf = zeros(1, window_length);

fig = figure('Name', 'Hệ thống giám sát và phản hồi cảnh báo y khoa', 'Position', [100, 100, 900, 600]);

ax1 = subplot(2,1,1);
h_raw = plot(t_win, red_raw_buf, 'k', 'LineWidth', 1);
title('1. Tín hiệu thô Tia Đỏ (Tần số cao 100Hz)'); ylabel('ADC'); grid on;

ax2 = subplot(2,1,2);
h_filt = plot(t_win, red_filt_buf, 'r', 'LineWidth', 1.3);
title_filt = title('2. Đang chờ dữ liệu ổn định...');
xlabel('Thời gian (giây)'); ylabel('Biên độ AC'); grid on;

%% 4. VÒNG LẶP XỬ LÝ VÀ PHẢN HỒI THỜI GIAN THỰC
count = 0;

while ishandle(fig)
    try
        % --- A. ĐỌC DỮ LIỆU THÔ ---
        dataStr = readline(s);
        red_val = str2double(dataStr);
        
        if isnan(red_val) || red_val < 5000
            continue; 
        end
        
        % --- B. LỌC REAL-TIME & CẬP NHẬT CỬA SỔ TRƯỢT ---
        [red_clean, z_red] = filter(b_bp, a_bp, red_val, z_red);
        
        red_raw_buf(1:end-1) = red_raw_buf(2:end);
        red_raw_buf(end) = red_val;
        
        red_filt_buf(1:end-1) = red_filt_buf(2:end);
        red_filt_buf(end) = red_clean;
        
        count = count + 1;
        
        % --- C. THUẬT TOÁN ĐO, LỌC NHIỄU SÂU & PHẢN HỒI (Cập nhật mỗi 1 giây) ---
        if mod(count, Fs) == 0
            
            % 1. Lọc nhiễu rung tay (Median -> Moving Average -> Bandpass)
            buf_median = medfilt1(red_raw_buf, 5);
            buf_smooth = movmean(buf_median, 7);
            buf_final = filtfilt(b_bp, a_bp, buf_smooth);
            
            % 2. Kiểm tra chất lượng tín hiệu (SQI)
            signal_variance = std(buf_final);
            
            if signal_variance > 400 
                writeline(s, "100"); % Ép chớp đèn nhanh báo lỗi
                set(title_filt, 'String', '⚠️ Tín hiệu nhiễu: Vui lòng giữ ngón tay nằm yên...');
            else
                % 3. Phân tích nhịp tim
                [pks, locs] = findpeaks(buf_final, 'MinPeakDistance', Fs * 0.33);
                
                if length(locs) >= 3
                    avg_interval = mean(diff(locs)) / Fs;
                    BPM = 60 / avg_interval;
                    
                    % 4. Vòng lặp phản hồi tốc độ nháy đèn
                    if BPM > 100
                        blink_delay = 250 - (BPM - 100) * 10;
                        if blink_delay < 80; blink_delay = 80; end 
                        writeline(s, num2str(round(blink_delay))); 
                        status_str = sprintf('⚠️ Cảnh báo Nhịp nhanh: %.1f BPM !', BPM);
                        
                    elseif BPM < 55
                        blink_delay = 250 - (55 - BPM) * 20;
                        if blink_delay < 80; blink_delay = 80; end
                        writeline(s, num2str(round(blink_delay))); 
                        status_str = sprintf('⚠️ Cảnh báo Nhịp chậm: %.1f BPM !', BPM);
                        
                    else
                        blink_delay = (60000 / BPM) / 2;
                        writeline(s, num2str(round(blink_delay))); 
                        status_str = sprintf('✅ Bình thường: %.1f BPM', BPM);
                    end
                    
                    set(title_filt, 'String', status_str);
                else
                    set(title_filt, 'String', 'Đang đo nhịp tim...');
                end
            end
            
            % Hiển thị đồ thị đã được làm siêu mượt
            red_filt_buf = buf_final; 
        end
        
        % --- D. VẼ ĐỒ THỊ LÊN MÀN HÌNH (Tốc độ 25 fps) ---
        if mod(count, 4) == 0
            set(h_raw, 'YData', red_raw_buf);
            set(h_filt, 'YData', red_filt_buf);
            
            ylim(ax1, [min(red_raw_buf)-200, max(red_raw_buf)+200]);
            ylim(ax2, [min(red_filt_buf)-50, max(red_filt_buf)+50]);
            drawnow limitrate;
        end
        
    catch
        % Bỏ qua lỗi giao tiếp nhỏ để hệ thống không bị treo
        continue; 
    end
end

%% 5. DỌN DẸP
clear s;
disp('Đã đóng cổng COM an toàn.');