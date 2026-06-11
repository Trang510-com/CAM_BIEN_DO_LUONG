clc; clear; close all;

%% 1. ĐỌC DỮ LIỆU TỪ FILE TRANG.TXT
% Sử dụng hàm readtable cơ bản kèm định nghĩa dấu Tab để tăng tính tương thích
data = readtable('trang.txt', 'Delimiter', '\t');

% Định nghĩa giá trị thực tế H (Ground Truth) cho từng bậc (Step từ 0 đến 5)
steps_val = 0:5;
H_truth_map = [0.0, 0.2, 0.38, 0.56, 0.76, 0.95];

% Gán giá trị H thực tế vào một cột mới trong bảng dữ liệu dựa trên cột Step
data.H_Truth = zeros(height(data), 1);
for i = 1:length(steps_val)
    idx = (data.Step == steps_val(i));
    data.H_Truth(idx) = H_truth_map(i);
end

% Tính toán sai số của dữ liệu thô (Raw) và bộ lọc Kalman so với thực tế
data.Error_Raw = data.Alt_Raw_m - data.H_Truth;
data.Error_Kalman = data.Alt_Kalman_m - data.H_Truth;

%% 2. ĐỒ THỊ 1: CHUỖI THỜI GIAN TỔNG THỂ
figure('Name', 'Chuỗi thời gian tổng thể', 'NumberTitle', 'off');
plot(data.Alt_Raw_m, 'Color', [0.7 0.7 0.7], 'LineWidth', 0.8);
hold on;
plot(data.Alt_Kalman_m, 'b-', 'LineWidth', 1.5);
plot(data.H_Truth, 'r--', 'LineWidth', 2);

% Vẽ các đường nét đứt màu đen phân tách giữa các bậc độ cao
step_changes = find(diff(data.Step) ~= 0);
ymin = min(data.Alt_Raw_m);
ymax = max(data.Alt_Raw_m);
for i = 1:length(step_changes)
    plot([step_changes(i) step_changes(i)], [ymin ymax], 'k:', 'LineWidth', 1.2);
end

grid on;
xlabel('Chỉ số mẫu (Thời gian)');
ylabel('Độ cao (m)');
title('So sánh Chuỗi Thời Gian Tổng Thể');
legend('Dữ liệu thô (Raw)', 'Lọc Kalman', 'Độ cao thực tế (H)', 'Phân chia bậc', 'Location', 'best');

%% 3. ĐỒ THỊ 2: HỒI QUY TUYẾN TÍNH (LINEAR REGRESSION)
figure('Name', 'Hồi quy tuyến tính', 'NumberTitle', 'off');
scatter(data.H_Truth, data.Alt_Kalman_m, 35, 'filled');
hold on;

% Tính toán đường hồi quy tuyến tính bậc 1 bằng hàm core polyfit
p = polyfit(data.H_Truth, data.Alt_Kalman_m, 1);
x_fit = linspace(min(H_truth_map), max(H_truth_map), 100);
y_fit = polyval(p, x_fit);

% Tính toán hệ số xác định R^2 để đánh giá độ chính xác
y_pred = polyval(p, data.H_Truth);
y_resid = data.Alt_Kalman_m - y_pred;
SSresid = sum(y_resid.^2);
SStotal = (length(data.Alt_Kalman_m)-1) * var(data.Alt_Kalman_m);
Rsq = 1 - SSresid/SStotal;

plot(x_fit, y_fit, 'r-', 'LineWidth', 2);
plot([0 1], [0 1], 'k--', 'LineWidth', 1); % Đường lý tưởng tỷ lệ 1:1

grid on;
xlabel('Độ cao thực tế H (m)');
ylabel('Độ cao lọc Kalman (m)');
title('Đồ thị Hồi quy Tuyến tính');
legend('Dữ liệu thực nghiệm', sprintf('Đường hồi quy (R^2 = %.4f)', Rsq), 'Đường lý tưởng (1:1)', 'Location', 'northwest');

%% 4. ĐỒ THỊ 3: MẬT ĐỘ PHÂN PHỐI TẦN SUẤT SAI SỐ (HISTOGRAM RAW vs KALMAN)
figure('Name', 'Mật độ phân phối sai số', 'NumberTitle', 'off');
titles_hist = {
    'Bậc 0: H = 0m (Mặt đất)', 'Bậc 1: H = 0.2m', ...
    'Bậc 2: H = 0.38m', 'Bậc 3: H = 0.56m', ...
    'Bậc 4: H = 0.76m', 'Bậc 5: H = 0.95m'
};

for i = 1:length(steps_val)
    subplot(3, 2, i);
    idx = (data.Step == steps_val(i));
    
    err_raw_step = data.Error_Raw(idx);
    err_kalman_step = data.Error_Kalman(idx);
    
    % Vẽ biểu đồ histogram dạng mật độ xác suất (pdf) - Raw (Màu xám trong suốt)
    histogram(err_raw_step, 'Normalization', 'pdf', 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', 'none', 'FaceAlpha', 0.6);
    hold on;
    % Vẽ biểu đồ histogram - Kalman (Màu xanh dương trong suốt)
    histogram(err_kalman_step, 'Normalization', 'pdf', 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.6);
    
    % Vẽ đường cong phân phối chuẩn cho Raw
    mu_raw = mean(err_raw_step); sigma_raw = std(err_raw_step);
    if sigma_raw > 0
        x_grid_raw = linspace(min(err_raw_step), max(err_raw_step), 100);
        y_norm_raw = (1 / (sigma_raw * sqrt(2 * pi))) * exp(-((x_grid_raw - mu_raw).^2) / (2 * sigma_raw^2));
        plot(x_grid_raw, y_norm_raw, 'k--', 'LineWidth', 1);
    end
    
    % Vẽ đường cong phân phối chuẩn cho Kalman
    mu_kal = mean(err_kalman_step); sigma_kal = std(err_kalman_step);
    if sigma_kal > 0
        x_grid_kal = linspace(min(err_kalman_step), max(err_kalman_step), 100);
        y_norm_kal = (1 / (sigma_kal * sqrt(2 * pi))) * exp(-((x_grid_kal - mu_kal).^2) / (2 * sigma_kal^2));
        plot(x_grid_kal, y_norm_kal, 'r-', 'LineWidth', 1.5);
    end
    
    grid on;
    title(titles_hist{i});
    xlabel('Sai số (m)');
    ylabel('Mật độ phân phối');
    if i == 1
        legend('Sai số Raw', 'Sai số Kalman', 'Chuẩn (Raw)', 'Chuẩn (Kalman)', 'Location', 'best');
    end
end

%% 5. ĐỒ THỊ 4: ĐÁNH GIÁ ĐỊNH LƯỢNG BỘ LỌC (SO SÁNH RMSE RAW vs KALMAN)
rmse_raw = zeros(1, length(steps_val));
rmse_kalman = zeros(1, length(steps_val));

for i = 1:length(steps_val)
    idx = (data.Step == steps_val(i));
    
    err_raw_step = data.Error_Raw(idx);
    err_kalman_step = data.Error_Kalman(idx);
    
    rmse_raw(i) = sqrt(mean(err_raw_step.^2));       % RMSE Dữ liệu Thô
    rmse_kalman(i) = sqrt(mean(err_kalman_step.^2)); % RMSE Bộ lọc Kalman
end

figure('Name', 'Đánh giá định lượng bộ lọc (RMSE)', 'NumberTitle', 'off');
% Gom cụm hai giá trị RMSE để vẽ cột đôi (Grouped Bar Chart)
bar_data = [rmse_raw' rmse_kalman'];
b = bar(steps_val, bar_data, 'grouped');

% Đặt màu sắc riêng cho từng cụm cột
b(1).FaceColor = [0.6 0.6 0.6]; % Màu xám cho dữ liệu thô (Raw)
b(2).FaceColor = [0.15 0.55 0.35]; % Màu xanh lá cho Kalman

grid on;
% Cấu hình trục tọa độ X
set(gca, 'XTick', steps_val);
set(gca, 'XTickLabel', {'Bậc 0 (0m)', 'Bậc 1 (0.2m)', 'Bậc 2 (0.38m)', 'Bậc 3 (0.56m)', 'Bậc 4 (0.76m)', 'Bậc 5 (0.95m)'});
xlabel('Các bậc độ cao thực tế');
ylabel('Giá trị RMSE (m)');
title('Đánh giá Định lượng Bộ lọc: So sánh sai số RMSE giữa Raw và Kalman');
legend('RMSE Dữ liệu Thô (Raw)', 'RMSE Bộ lọc Kalman', 'Location', 'northwest');

% Tự động điền số liệu RMSE cụ thể lên trên đầu mỗi cột một cách chuẩn xác
for i = 1:length(steps_val)
    % Tọa độ X và giá trị hiển thị cho cột Raw
    x_pos_raw = steps_val(i) - 0.15; 
    text(x_pos_raw, rmse_raw(i) + max(rmse_raw)*0.01, sprintf('%.4f', rmse_raw(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
    
    % Tọa độ X và giá trị hiển thị cho cột Kalman
    x_pos_kalman = steps_val(i) + 0.15;
    text(x_pos_kalman, rmse_kalman(i) + max(rmse_raw)*0.01, sprintf('%.4f', rmse_kalman(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9, 'Color', [0 0.4 0]);
end