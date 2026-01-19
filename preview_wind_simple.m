%% 风场预览函数（修复版本）
function preview_wind_simple(fig)
    fig_data = get(fig, 'UserData');
    
    % 先收集当前面板数据
    collect_current_panel_data(fig);
    fig_data = get(fig, 'UserData');
    params = fig_data.params;
    
    if params.wind_params.enable
        wind_speed = params.wind_params.speed;
        wind_dir = params.wind_params.direction;
        
        h_fig = figure('Name', '风场预览', 'NumberTitle', 'off', ...
            'Position', [400, 200, 800, 600]);
        
        % 第1个子图：风场极坐标图（使用传统polar函数）
        subplot(2,2,1);
        
        % 计算风向向量（转换为弧度）
        wind_dir_rad = deg2rad(wind_dir);
        
        % 创建极坐标图
        polar(0, wind_speed * 1.2); % 设置范围
        hold on;
        
        % 绘制风向量
        polar([0 wind_dir_rad], [0 wind_speed], 'r-', 'LineWidth', 3);
        
        % 绘制参考圆
        theta = linspace(0, 2*pi, 100);
        r = wind_speed * 0.5 * ones(size(theta));
        polar(theta, r, 'b--');
        
        % 标记跑道方向（270度，向西）
        runway_dir = deg2rad(270);
        polar([0 runway_dir], [0 wind_speed], 'g-', 'LineWidth', 2);
        
        title(sprintf('风场极坐标图\n风速: %.1f m/s, 风向: %.0f°', wind_speed, wind_dir));
        grid on;
        
        % 第2个子图：风分量图
        subplot(2,2,2);
        
        % 计算风分量
        approach_heading = 270;  % 跑道方向向西
        relative_angle = wind_dir - approach_heading - 180;
        headwind = wind_speed * cosd(relative_angle);
        crosswind = wind_speed * sind(relative_angle);
        
        % 创建柱状图
        components = [headwind, crosswind];
        bar(components, 'FaceColor', [0.7 0.9 1.0]);
        set(gca, 'XTickLabel', {'顶风分量', '侧风分量'});
        ylabel('风速 (m/s)');
        title('风分量分解');
        
        % 在柱子上添加数值标签
        for i = 1:length(components)
            if components(i) >= 0
                text(i, components(i)+0.1, sprintf('%.1f', components(i)), ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
            else
                text(i, components(i)-0.1, sprintf('%.1f', components(i)), ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
            end
        end
        
        % 第3个子图：风场对进近的影响
        subplot(2,2,[3 4]);
        
        % 创建进近示意图
        plot([0 100], [0 0], 'k-', 'LineWidth', 3);  % 跑道
        hold on;
        
        % 绘制飞机位置
        plot(50, 20, 'b^', 'MarkerSize', 15, 'MarkerFaceColor', 'b');
        
        % 绘制风向量
        wind_scale = 2;  % 缩放因子
        quiver(50, 20, ...
            wind_speed * cosd(wind_dir) / wind_scale, ...
            wind_speed * sind(wind_dir) / wind_scale, ...
            'r', 'LineWidth', 2, 'MaxHeadSize', 1);
        
        % 绘制进近路径
        plot([30 70], [50 0], 'g--', 'LineWidth', 1.5);
        
        % 标注
        text(50, 25, '飞机', 'HorizontalAlignment', 'center', ...
            'FontWeight', 'bold', 'Color', 'b');
        text(50 + wind_speed*cosd(wind_dir)/wind_scale + 5, ...
            20 + wind_speed*sind(wind_dir)/wind_scale, ...
            sprintf('风 %.1fm/s', wind_speed), ...
            'HorizontalAlignment', 'left', 'Color', 'r');
        text(40, 30, '进近路径', 'HorizontalAlignment', 'center', ...
            'Color', 'g', 'Rotation', -45);
        
        % 设置图形范围
        axis([0 100 0 60]);
        axis equal;
        grid on;
        title('进近风场示意图');
        xlabel('水平距离 (m)');
        ylabel('高度 (m)');
        
        % 添加信息文本框
        info_str = sprintf('风场信息:\n');
        info_str = [info_str sprintf('风速: %.1f m/s\n', wind_speed)];
        info_str = [info_str sprintf('风向: %.0f°\n', wind_dir)];
        info_str = [info_str sprintf('跑道方向: 270° (向西)\n')];
        info_str = [info_str sprintf('相对角度: %.0f°\n', mod(relative_angle+180,360)-180)];
        info_str = [info_str sprintf('顶风分量: %.1f m/s\n', headwind)];
        info_str = [info_str sprintf('侧风分量: %.1f m/s\n', crosswind)];
        
        if headwind > 0
            info_str = [info_str sprintf('\n影响: 顶风\n')];
            info_str = [info_str sprintf('• 增加指示空速\n')];
            info_str = [info_str sprintf('• 减小地速\n')];
            info_str = [info_str sprintf('• 延长进近距离\n')];
        elseif headwind < 0
            info_str = [info_str sprintf('\n影响: 顺风\n')];
            info_str = [info_str sprintf('• 减小指示空速\n')];
            info_str = [info_str sprintf('• 增加地速\n')];
            info_str = [info_str sprintf('• 缩短进近距离\n')];
        else
            info_str = [info_str sprintf('\n影响: 纯侧风\n')];
        end
        
        % 在图形中添加文本框
        annotation('textbox', [0.02, 0.02, 0.4, 0.2], ...
            'String', info_str, ...
            'BackgroundColor', [0.95 0.95 0.95], ...
            'EdgeColor', 'k', ...
            'FontSize', 9);
        
    else
        msgbox('请先启用风场以预览', '风场未启用', 'warn');
    end
end