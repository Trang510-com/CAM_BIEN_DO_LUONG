clc; clear; close all;

%% 1. ĐỌC VÀ LÀM SẠCH DỮ LIỆU TỪ FILE STATIC_EMA.TXT
% Đọc file dưới dạng văn bản trước để xử lý lọc bỏ các dòng text lỗi
opts = detectImportOptions('static_EMA.txt', 'FileType', 'text', 'Delimiter', ',');
% Ép các cột quan trọng về kiểu chuỗi (string) để dễ lọc dòng nhiễu
opts.VariableTypes{1} = 'string'; % Time_ms
opts.VariableTypes{2} = 'string'; % StepID
opts.VariableTypes{6} = 'string'; % Alt_Raw_m
opts.VariableTypes{7} = 'string'; % Alt_EMA_m

raw_table = readtable('static_EMA.txt', opts);

% Chuyển đổi ngược lại sang dạng số, dòng nào chứa chữ sẽ tự động thành NaN
Time_ms     = str2double(raw_table.Time_ms);
StepID      = str2double(raw_table.StepID);
Alt_Raw_m   = str2double(raw_table.Alt_Raw_m);
Alt_EMA_m   = str2double(raw_table.Alt_EMA_m);

% Tạo bảng dữ liệu sạch (chỉ giữ lại các dòng mà tất cả đều là số hợp lệ)
valid_idx = ~isnan(Time_ms) & ~isnan(StepID) & ~isnan(Alt_Raw_m) & ~isnan(Alt_EMA_m);

data = table();
data.Time_ms   = Time_ms(valid_idx);
data.StepID    = StepID(valid_idx);
data.Alt_Raw_m = Alt_Raw_m(valid_idx);
data.Alt_EMA_m = Alt_EMA_m(valid_idx);

% Định nghĩa giá trị thực tế H (Ground Truth) cho từng bậc (StepID từ 0 đến 5)
steps_val = 0:5;
H_truth_map = [0.0, 0.2, 0.38, 0.56, 0.76, 0.95];

% Gán giá trị H thực tế vào cột mới
data.H_Truth = zeros(height(data), 1);
for i = 1:length(steps_val)
    idx = (data.StepID == steps_val(i));
    data.H_Truth(idx) = H_truth_map(i);
end

% Tính toán sai số
data.Error_Raw = data.Alt_Raw_m - data.H_Truth;
data.Error_EMA = data.Alt_EMA_m - data.H_Truth;

%% 2. ĐỒ THỊ 1: CHUỖI THỜI GIAN TỔNG THỂ
figure('Name', 'Chuỗi thời gian tổng thể', 'NumberTitle', 'off');
plot(data.Alt_Raw_m, 'Color', [0.7 0.7 0.7], 'LineWidth', 0.8);
hold on;
plot(data.Alt_EMA_m, 'b-', 'LineWidth', 1.5);
plot(data.H_Truth, 'r--', 'LineWidth', 2);

% Vẽ các đường nét đứt màu đen phân tách giữa các bậc độ cao
step_changes = find(diff(data.StepID) ~= 0);
ymin = min(data.Alt_Raw_m);
ymax = max(data.Alt_Raw_m);
for i = 1:length(step_changes)
    plot([step_changes(i) step_changes(i)], [ymin ymax], 'k:', 'LineWidth', 1.2);
end

grid on;
xlabel('Chỉ số mẫu (Thời gian)');
ylabel('Độ cao (m)');
title('So sánh Chuỗi Thời Gian Tổng Thể');
legend('Dữ liệu thô (Raw)', 'Lọc EMA', 'Độ cao thực tế (H)', 'Phân chia bậc', 'Location', 'best');

%% 3. ĐỒ THỊ 2: HỒI QUY TUYẾN TÍNH (Bây giờ chắc chắn sẽ hiện đường hồi quy)
figure('Name', 'Hồi quy tuyến tính', 'NumberTitle', 'off');
scatter(data.H_Truth, data.Alt_EMA_m, 35, 'filled');
hold on;

% Tính toán đường hồi quy tuyến tính bậc 1
p = polyfit(data.H_Truth, data.Alt_EMA_m, 1);
x_fit = linspace(min(H_truth_map), max(H_truth_map), 100);
y_fit = polyval(p, x_fit);

% Tính toán hệ số xác định R^2
y_pred = polyval(p, data.H_Truth);
y_resid = data.Alt_EMA_m - y_pred;
SSresid = sum(y_resid.^2);
SStotal = (length(data.Alt_EMA_m)-1) * var(data.Alt_EMA_m);
Rsq = 1 - SSresid/SStotal;

plot(x_fit, y_fit, 'r-', 'LineWidth', 2);
plot([0 1], [0 1], 'k--', 'LineWidth', 1); % Đường lý tưởng tỷ lệ 1:1

grid on;
xlabel('Độ cao thực tế H (m)');
ylabel('Độ cao lọc EMA (m)');
title('Đồ thị Hồi quy Tuyến tính');
legend('Dữ liệu thực nghiệm', sprintf('Đường hồi quy (R^2 = %.4f)', Rsq), 'Đường lý tưởng (1:1)', 'Location', 'northwest');

%% 4. ĐỒ THỊ 3: MẬT ĐỘ PHÂN PHỐI TẦN SUẤT SAI SỐ
figure('Name', 'Mật độ phân phối sai số', 'NumberTitle', 'off');
titles_hist = {
    'Bậc 0: H = 0m (Mặt đất)', 'Bậc 1: H = 0.2m', ...
    'Bậc 2: H = 0.38m', 'Bậc 3: H = 0.56m', ...
    'Bậc 4: H = 0.76m', 'Bậc 5: H = 0.95m'
};

for i = 1:length(steps_val)
    subplot(3, 2, i);
    idx = (data.StepID == steps_val(i));
    
    err_raw_step = data.Error_Raw(idx);
    err_ema_step = data.Error_EMA(idx);
    
    histogram(err_raw_step, 'Normalization', 'pdf', 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', 'none', 'FaceAlpha', 0.6);
    hold on;
    histogram(err_ema_step, 'Normalization', 'pdf', 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.6);
    
    mu_raw = mean(err_raw_step); sigma_raw = std(err_raw_step);
    if sigma_raw > 0
        x_grid_raw = linspace(min(err_raw_step), max(err_raw_step), 100);
        y_norm_raw = (1 / (sigma_raw * sqrt(2 * pi))) * exp(-((x_grid_raw - mu_raw).^2) / (2 * sigma_raw^2));
        plot(x_grid_raw, y_norm_raw, 'k--', 'LineWidth', 1);
    end
    
    mu_ema = mean(err_ema_step); sigma_ema = std(err_ema_step);
    if sigma_ema > 0
        x_grid_ema = linspace(min(err_ema_step), max(err_ema_step), 100);
        y_norm_ema = (1 / (sigma_ema * sqrt(2 * pi))) * exp(-((x_grid_ema - mu_ema).^2) / (2 * sigma_ema^2));
        plot(x_grid_ema, y_norm_ema, 'r-', 'LineWidth', 1.5);
    end
    
    grid on;
    title(titles_hist{i});
    xlabel('Sai số (m)');
    ylabel('Mật độ phân phối');
    if i == 1
        legend('Sai số Raw', 'Sai số EMA', 'Chuẩn (Raw)', 'Chuẩn (EMA)', 'Location', 'best');
    end
end

%% 5. ĐỒ THỊ 4: ĐÁNH GIÁ ĐỊNH LƯỢNG RMSE
rmse_raw = zeros(1, length(steps_val));
rmse_ema = zeros(1, length(steps_val));

for i = 1:length(steps_val)
    idx = (data.StepID == steps_val(i));
    
    err_raw_step = data.Error_Raw(idx);
    err_ema_step = data.Error_EMA(idx);
    
    rmse_raw(i) = sqrt(mean(err_raw_step.^2));
    rmse_ema(i) = sqrt(mean(err_ema_step.^2));
end

figure('Name', 'Đánh giá định lượng bộ lọc (RMSE)', 'NumberTitle', 'off');
bar_data = [rmse_raw' rmse_ema'];
b = bar(steps_val, bar_data, 'grouped');

b(1).FaceColor = [0.6 0.6 0.6];
b(2).FaceColor = [0.15 0.55 0.35];

grid on;
set(gca, 'XTick', steps_val);
set(gca, 'XTickLabel', {'Bậc 0 (0m)', 'Bậc 1 (0.2m)', 'Bậc 2 (0.38m)', 'Bậc 3 (0.56m)', 'Bậc 4 (0.76m)', 'Bậc 5 (0.95m)'});
xlabel('Các bậc độ cao thực tế');
ylabel('Giá trị RMSE (m)');
title('Đánh giá Định lượng Bộ lọc: So sánh sai số RMSE giữa Raw và EMA');
legend('RMSE Dữ liệu Thô (Raw)', 'RMSE Bộ lọc EMA', 'Location', 'northwest');

for i = 1:length(steps_val)
    x_pos_raw = steps_val(i) - 0.15; 
    text(x_pos_raw, rmse_raw(i) + max(rmse_raw)*0.01, sprintf('%.4f', rmse_raw(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
    
    x_pos_ema = steps_val(i) + 0.15;
    text(x_pos_ema, rmse_ema(i) + max(rmse_raw)*0.01, sprintf('%.4f', rmse_ema(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9, 'Color', [0 0.4 0]);
end