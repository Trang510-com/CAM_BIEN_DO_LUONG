% 1. Mở cửa sổ chọn file trực quan
[file, path] = uigetfile('*.txt', 'Chọn file dữ liệu của bạn');
if isequal(file, 0)
    disp('Bạn đã hủy chọn file.');
    return;
else
    fullFileName = fullfile(path, file);
    fileLines = readlines(fullFileName, 'Encoding', 'UTF-8');
end

% --- GIỮ NGUYÊN ĐOẠN CODE XỬ LÝ PHÍA DƯỚI ---
time = []; raw = []; kalman = [];

for i = 1:length(fileLines)
    currentLine = strtrim(fileLines(i));
    if isempty(currentLine) || contains(currentLine, '===') || contains(currentLine, '>>>') || contains(currentLine, 'Pressure')
        continue; 
    end
    
    tokens = strsplit(currentLine, ',');
    if length(tokens) >= 4
        t_val = str2double(erase(tokens{1}, 's'));
        raw_val = str2double(tokens{3});     
        kalman_val = str2double(tokens{4});  
        
        if ~isnan(t_val) && ~isnan(raw_val) && ~isnan(kalman_val)
            time(end+1) = t_val;
            raw(end+1) = raw_val;
            kalman(end+1) = kalman_val;
        end
    end
end

% Vẽ đồ thị
figure('Color', 'w');
plot(time, raw, 'r.-', 'LineWidth', 1, 'MarkerSize', 8); hold on;
plot(time, kalman, 'b-', 'LineWidth', 2);
grid on; grid minor;
xlabel('Thời gian (s)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Giá trị Độ cao / Khoảng cách (m)', 'FontSize', 12, 'FontWeight', 'bold');
title('Đồ thị so sánh tín hiệu Gốc (Raw) và sau bộ lọc Kalman', 'FontSize', 14);
legend('Dữ liệu Thô (Raw)', 'Dữ liệu Lọc (Kalman)', 'Location', 'best');
set(gca, 'FontSize', 11);