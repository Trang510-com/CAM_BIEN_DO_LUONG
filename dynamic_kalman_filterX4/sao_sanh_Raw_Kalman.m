%% 1. Đọc và xử lý dữ liệu từ file text
filename = 'dynamic_KALMAN_FILTERX4.txt';

% Mở file ở chế độ đọc thông thường
fileID = fopen(filename, 'r');
rawLines = textscan(fileID, '%s', 'Delimiter', '\n');
fclose(fileID);

rawLines = rawLines{1};
validData = [];

% Vòng lặp lọc dữ liệu
for i = 1:length(rawLines)
    lineStr = strtrim(rawLines{i});
    if isempty(lineStr) || contains(lineStr, '===') || contains(lineStr, 'Pressure') || contains(lineStr, '>>>')
        continue;
    end
    lineStr = strrep(lineStr, 's', '');
    columns = strsplit(lineStr, ',');
    if length(columns) >= 4
        numRow = [str2double(columns{1}), str2double(columns{2}), str2double(columns{3}), str2double(columns{4})];
        if ~any(isnan(numRow))
            validData = [validData; numRow]; %#ok<AGROW>
        end
    end
end

Time   = validData(:, 1); 
Raw    = validData(:, 3); 
Kalman = validData(:, 4); 

%% 2. Vẽ đồ thị so sánh Raw và Kalman
figure('Name', 'So sanh Bo loc Kalman', 'NumberTitle', 'off');
hold on;

plot(Time, Raw, 'Color', [0.85, 0.32, 0.10], 'LineWidth', 1.0, 'LineStyle', ':', 'DisplayName', 'Dữ liệu thô (Raw)');
plot(Time, Kalman, 'Color', [0.00, 0.45, 0.74], 'LineWidth', 2.0, 'DisplayName', 'Bộ lọc Kalman');

grid on; grid minor; 
title('Đồ thị so sánh tín hiệu Raw và Kalman', 'FontSize', 13, 'FontWeight', 'bold');
xlabel('Thời gian (giây)', 'FontSize', 11);
ylabel('Độ cao (m)', 'FontSize', 11);
legend('Location', 'best', 'FontSize', 10);
box on; hold off;