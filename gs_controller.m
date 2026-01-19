function [pitch_cmd, throttle_cmd] = gs_controller(...
    gs_error, current_speed, target_speed, descent_rate, gamma, ctrl, dt, iter, current_altitude, wind_params)
% 下滑道跟踪控制器 - 增强风场支持版本
% gs_error = 实际高度 - 理想高度
% gs_error > 0: 飞机高于下滑道 -> 需要增加下降率（低头）
% gs_error < 0: 飞机低于下滑道 -> 需要减少下降率（抬头）

    % 1. 基础俯仰角设置（考虑风场）
    if isfield(wind_params, 'enable') && wind_params.enable && wind_params.speed > 0
        approach_heading = 270;
        relative_angle = wind_params.direction - approach_heading;
        headwind = wind_params.speed * cosd(relative_angle);
        
        if headwind < -2  % 顺风
            base_pitch = 2.2;  % 顺风时需要更小的俯仰角
        elseif headwind < -1
            base_pitch = 2.5;
        elseif headwind > 2  % 顶风
            base_pitch = 3.2;  % 顶风时需要稍大俯仰角
        elseif headwind > 1
            base_pitch = 3.0;
        else
            base_pitch = 3.0;
        end
    else
        base_pitch = 3.0;
    end
    
    % 2. 风场对俯仰的额外调整（定义 wind_pitch_adjust）
    if isfield(wind_params, 'enable') && wind_params.enable && wind_params.speed > 0
        % 计算顶风分量
        approach_heading = 270;
        relative_angle = wind_params.direction - approach_heading;
        headwind = wind_params.speed * cosd(relative_angle);
        
        % 顺风情况：需要更大的俯仰角以保持下滑道
        if headwind < -3  % 强顺风
            wind_pitch_adjust = -0.8;  % 减少俯仰角
        elseif headwind < -2  % 中等顺风
            wind_pitch_adjust = -0.6;
        elseif headwind < -1  % 轻微顺风
            wind_pitch_adjust = -0.3;
        elseif headwind > 3  % 强顶风
            wind_pitch_adjust = 0.8;   % 增加俯仰角
        elseif headwind > 2  % 中等顶风
            wind_pitch_adjust = 0.5;
        elseif headwind > 1  % 轻微顶风
            wind_pitch_adjust = 0.2;
        else
            wind_pitch_adjust = 0;
        end
    else
        wind_pitch_adjust = 0;
    end
    
    % 3. 速度控制
    speed_error = current_speed - target_speed;
    
    % 基础油门设置 - 更精细的控制
    if speed_error > 5  % 速度过高
        throttle_cmd = 0.0005;
    elseif speed_error > 3
        throttle_cmd = 0.001;
    elseif speed_error > 2
        throttle_cmd = 0.002;
    elseif speed_error > 1
        throttle_cmd = 0.004;
    elseif speed_error > -1
        throttle_cmd = 0.008;  % 维持速度
    elseif speed_error > -2
        throttle_cmd = 0.012;  % 轻微加速
    elseif speed_error > -3
        throttle_cmd = 0.016;
    elseif speed_error > -5
        throttle_cmd = 0.020;
    else  % 速度过低
        throttle_cmd = 0.025;
    end
    
    % 4. 风场调整（油门部分）
    if isfield(wind_params, 'enable') && wind_params.enable && wind_params.speed > 0
        % 计算顶风分量
        approach_heading = 270;
        relative_angle = wind_params.direction - approach_heading;
        headwind = wind_params.speed * cosd(relative_angle);
        
        % 根据风况调整油门
        if headwind < -2  % 顺风
            throttle_adjust = -0.008;  % 顺风时减小油门
        elseif headwind > 2  % 顶风
            throttle_adjust = 0.012;   % 顶风时增加油门
        else
            throttle_adjust = 0;
        end
        
        throttle_cmd = throttle_cmd + throttle_adjust;
    end
    
    % 5. 下滑道误差修正
    if gs_error < -25
        pitch_correction = 3.2;
    elseif gs_error < -20
        pitch_correction = 2.3;
    elseif gs_error < -15
        pitch_correction = 1.6;
    elseif gs_error < -10
        pitch_correction = 1.0;
    elseif gs_error < -5
        pitch_correction = 0.5;
    elseif gs_error < -2
        pitch_correction = 0.25;
    elseif gs_error < 2
        pitch_correction = 0.0;
    elseif gs_error < 5
        pitch_correction = -0.35;
    elseif gs_error < 10
        pitch_correction = -0.8;
    elseif gs_error < 15
        pitch_correction = -1.3;
    elseif gs_error < 20
        pitch_correction = -2.3;
    elseif gs_error < 25
        pitch_correction = -3.2;
    else
        pitch_correction = -4.2;
    end
    
    % 6. 下降率修正
    ideal_descent = -target_speed * sind(3);
    descent_error = descent_rate - ideal_descent;
    
   % 在 gs_controller.m 中，只调整下降率修正部分：

% 当前下降率-1.71m/s vs 理论-1.47m/s，需要减小下降率
if descent_error < -0.6  % 下降率比理论值小0.6 m/s以上（更负）
    descent_correction = 1.6;  % 增加抬头（原1.4）
elseif descent_error < -0.3
    descent_correction = 0.8;  % 增加抬头（原0.7）
elseif descent_error < -0.1
    descent_correction = 0.4;  % 增加抬头（原0.35）
elseif descent_error < 0.1
    descent_correction = 0.0;
elseif descent_error < 0.3
    descent_correction = -0.2; % 低头（原-0.25）
elseif descent_error < 0.6
    descent_correction = -0.5;  % 低头（原-0.6）
else
    descent_correction = -1.0;  % 低头（原-1.2）
end
    
    % 7. 速度过高时的俯仰控制
    if speed_error > 3
        speed_pitch_adjust = -1.5;
    elseif speed_error > 2
        speed_pitch_adjust = -1.0;
    elseif speed_error > 1
        speed_pitch_adjust = -0.5;
    elseif speed_error < -3
        speed_pitch_adjust = 1.0;
    elseif speed_error < -2
        speed_pitch_adjust = 0.5;
    elseif speed_error < -1
        speed_pitch_adjust = 0.2;
    else
        speed_pitch_adjust = 0;
    end
    
    % 8. 最终俯仰指令
    pitch_cmd = base_pitch + pitch_correction + descent_correction + wind_pitch_adjust + speed_pitch_adjust;
    
    % 9. 高度相关修正
    if current_altitude < 100
        pitch_cmd = pitch_cmd * 0.9;
        throttle_cmd = throttle_cmd * 1.2;
    end
    
    % 10. 限制范围
    pitch_cmd = max(-2.0, min(8.0, pitch_cmd));
    throttle_cmd = max(0.0005, min(0.08, throttle_cmd));
    
    % 11. 调试信息
    if mod(iter, 20) == 0
        fprintf('控制器: 高度=%.0fm, gs_err=%.1fm, pitch=%.1f°(基%.1f+修%.1f+风%.1f), 下降率=%.2f/%.2f, 油门=%.4f\n', ...
            current_altitude, gs_error, pitch_cmd, base_pitch, pitch_correction, wind_pitch_adjust, ...
            descent_rate, ideal_descent, throttle_cmd);
    end
end