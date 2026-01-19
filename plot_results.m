function plot_results(history, approach, N)
% 绘制仿真结果（简化版）

    time = history.time(1:N);
    
    figure('Position', [50, 50, 1200, 800], 'Name', '固定翼无人机自动进近仿真结果', ...
        'NumberTitle', 'off');
    
    % 1. 轨迹图
    subplot(2, 3, 1);
    plot(history.distance(1:N), history.altitude(1:N), 'b-', 'LineWidth', 2);
    hold on;
    
    % 绘制理想轨迹
    flare_start_alt = approach.flare_start;
    glide_slope_angle = approach.glide_slope;
    distance_from_threshold_to_flare = flare_start_alt / tand(glide_slope_angle);
    distance_FAF_to_flare = approach.distance_FAF - distance_from_threshold_to_flare;
    
    % 拉平段
    if distance_from_threshold_to_flare > 0
        x_flare = linspace(0, distance_from_threshold_to_flare, 50);
        k = 3.5 / distance_from_threshold_to_flare;
        y_flare = flare_start_alt * exp(-k * (distance_from_threshold_to_flare - x_flare));
        plot(x_flare, y_flare, 'r--', 'LineWidth', 1.5);
    end
    
    % 下滑段
    if distance_FAF_to_flare > 0
        x_gs = linspace(distance_from_threshold_to_flare, approach.distance_FAF, 50);
        y_gs = flare_start_alt + (x_gs - distance_from_threshold_to_flare) * tand(glide_slope_angle);
        plot(x_gs, y_gs, 'r--', 'LineWidth', 1.5);
    end
    
    % 跑道和标记
    plot([-200, 500], [0, 0], 'k-', 'LineWidth', 4);
    plot([0, 0], [0, max(history.altitude)*1.1], 'r:', 'LineWidth', 1.5);
    plot(approach.distance_FAF, approach.initial_alt, 'b^', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
    text(approach.distance_FAF, approach.initial_alt + 20, 'FAF', 'FontSize', 10, 'FontWeight', 'bold');
    
    xlabel('距跑道入口距离 [m]');
    ylabel('高度 [m]');
    title('进近轨迹');
    legend('实际轨迹', '理想轨迹(含拉平)', '跑道', '跑道入口', 'FAF点', ...
        'Location', 'best', 'NumColumns', 2);
    grid on;
    
    % 2. 高度-时间图
    subplot(2, 3, 2);
    plot(time, history.altitude(1:N), 'b-', 'LineWidth', 2);
    hold on;
    plot([time(1), time(end)], [approach.DH, approach.DH], 'r--', 'LineWidth', 1.5);
    plot([time(1), time(end)], [approach.flare_start, approach.flare_start], 'g--', 'LineWidth', 1.5);
    xlabel('时间 [s]');
    ylabel('高度 [m]');
    title('高度变化');
    legend('实际高度', '决断高度', '拉平高度');
    grid on;
    
    % 3. 下降率图
    subplot(2, 3, 3);
    plot(time, history.descent_rate(1:N), 'b-', 'LineWidth', 2);
    hold on;
    theoretical_sink = -approach.target_speed * sind(approach.glide_slope);
    plot([time(1), time(end)], [theoretical_sink, theoretical_sink], 'r--', 'LineWidth', 1.5);
    plot([time(1), time(end)], [0, 0], 'k--', 'LineWidth', 1);
    xlabel('时间 [s]');
    ylabel('下降率 [m/s]');
    title('垂直速度');
    legend('实际下降率', '理论下降率', '水平线', 'Location', 'best');
    grid on;
    
    % 4. 空速图
    subplot(2, 3, 4);
    plot(time, history.speed(1:N), 'b-', 'LineWidth', 2);
    hold on;
    plot([time(1), time(end)], [approach.target_speed, approach.target_speed], 'r--', 'LineWidth', 1.5);
    xlabel('时间 [s]');
    ylabel('空速 [m/s]');
    title('空速变化');
    legend('实际空速', '目标空速');
    grid on;
    
    % 5. 俯仰角图
    subplot(2, 3, 5);
    plot(time, history.pitch(1:N), 'b-', 'LineWidth', 2);
    hold on;
    plot([time(1), time(end)], [-approach.glide_slope, -approach.glide_slope], 'r--', 'LineWidth', 1.5);
    xlabel('时间 [s]');
    ylabel('俯仰角 [度]');
    title('俯仰姿态');
    legend('实际俯仰', '理论俯仰');
    grid on;
    
    % 6. 控制指令图
    subplot(2, 3, 6);
    plot(time, history.throttle(1:N)*100, 'r-', 'LineWidth', 2);
    hold on;
    plot(time, history.elevator(1:N)*50, 'b-', 'LineWidth', 2);
    xlabel('时间 [s]');
    ylabel('控制指令');
    title('控制指令');
    legend('油门 [%]', '升降舵 [%]', 'Location', 'best');
    grid on;
    
    % 总标题
    sgtitle(sprintf('固定翼无人机自动进近仿真 - 总时间: %.1f秒', time(end)), ...
        'FontSize', 14, 'FontWeight', 'bold');
    
    set(gcf, 'Color', 'white');
end