function [pitch_cmd, throttle_cmd] = flare_controller(...
    radio_alt, descent_rate, speed, flare_factor, ctrl, dt, mass, target_speed)
% 拉平控制器（优化版）- 改善接地下降率

    % 1. 根据高度设置目标下降率（更平缓的过渡）
    if radio_alt > 20
        target_sink = -1.0;
    elseif radio_alt > 15
        target_sink = -0.8;
    elseif radio_alt > 10
        target_sink = -0.6;
    elseif radio_alt > 5
        target_sink = -0.4;
    elseif radio_alt > 2
        target_sink = -0.2;
    else
        target_sink = -0.1;  % 原ctrl.target_sink_rate，改为更小的值
    end
    
    % 2. 下降率控制（更温和的修正）
    sink_error = descent_rate - target_sink;
    
    P_term = ctrl.flare_Kp * sink_error * 0.8;  % 减小增益
    
    % 3. 俯仰指令（更平缓的拉平）
    base_pitch = 1.5;  % 原1.0，增加基础俯仰
    flare_pitch = flare_factor * 3.5;  % 原4.0，减小最大抬头
    pitch_cmd = base_pitch + flare_pitch + P_term;
    
    % 4. 油门控制
    speed_error = speed - target_speed;
    
    if speed_error > 2
        throttle_cmd = 0.04;  % 原0.05
    elseif speed_error > 0
        throttle_cmd = 0.05;  % 原0.06
    elseif speed_error > -2
        throttle_cmd = 0.06;  % 原0.07
    else
        throttle_cmd = 0.07;  % 原0.08
    end
    
    % 5. 随高度降低减小油门（更平缓）
    if radio_alt < 8
        altitude_factor = radio_alt / 8;
        throttle_cmd = throttle_cmd * altitude_factor;
    end
    
    % 6. 低高度时的额外抬头
    if radio_alt < 5 && descent_rate < -0.5
        extra_pitch = (5 - radio_alt) * 0.1;  % 高度越低，抬头越多
        pitch_cmd = pitch_cmd + extra_pitch;
    end
    
    % 7. 限制
    pitch_cmd = max(0.5, min(6.0, pitch_cmd));  % 限制范围调整
    throttle_cmd = max(0.02, min(0.10, throttle_cmd));
    
    % 8. 调试信息
    if mod(floor(radio_alt * 10), 2) == 0 || radio_alt < 3
        fprintf('拉平: 高度=%.1fm, 下降率=%.2f, 目标=%.2f, pitch=%.1f°, throttle=%.3f\n', ...
            radio_alt, descent_rate, target_sink, pitch_cmd, throttle_cmd);
    end
end