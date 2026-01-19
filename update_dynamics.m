function new_state = update_dynamics(state, pitch_cmd, throttle_cmd, ...
    elevator_cmd, UAV, atmosphere, dt, max_descent_rate, wind_params, target_speed)
% 飞机动力学更新函数（最终修正版）- 修复风场问题

    % 解包当前状态
    x = state.distance;
    h = state.altitude;
    V = state.speed; % 空速（指示空速）
    theta = state.pitch;
    theta_rad = deg2rad(theta);
    h_dot = state.descent_rate;
    
    % 1. 计算当前航迹角
    if V > 0.5
        gamma = asind(h_dot / V);
    else
        gamma = 0;
    end
    gamma_rad = deg2rad(gamma);
    
  % 2. 风效应计算（修复版）- 关键修正
if wind_params.enable && wind_params.speed > 0
    wind_speed = wind_params.speed;
    wind_direction = wind_params.direction;  % 气象风向，风吹来的方向
    
    % 假设飞机向西进近（跑道朝向270度）
    approach_heading = 270;  % 飞机航向向西
    
    % 关键修正：计算真实顶风分量
    % 风向是风吹来的方向，所以：
    % 飞机航向与风向的夹角 = 风向 - 航向
    % 顶风分量 = 风速 * cos(风向 - 航向)
    % 当风向=航向时，cos(0)=1，表示完全顶风
    % 当风向=航向+180时，cos(180)=-1，表示完全顺风
    
    relative_angle = wind_direction - approach_heading;
    headwind = wind_speed * cosd(relative_angle);
    crosswind = wind_speed * sind(relative_angle);
    
    % 地速 = 空速 - 顶风分量
    % 顶风（headwind为正）减小地速，顺风（headwind为负）增加地速
    ground_speed = V - headwind;  % 关键修正
    
    % 确保最小地速
    if ground_speed < 5
        ground_speed = 5;
    end
    
    % 调试信息
    persistent wind_debug_counter;
    if isempty(wind_debug_counter)
        wind_debug_counter = 0;
    end
    wind_debug_counter = wind_debug_counter + 1;
    
    if wind_debug_counter <= 5 || mod(wind_debug_counter, 50) == 0
        % 修正：正确显示顶风/顺风
        if headwind > 0
            wind_type = '顶风';
        else
            wind_type = '顺风';
        end
        fprintf('风场: 风速%.1fm/s, 风向%.0f°(吹来的方向), 航向%.0f°\n', ...
            wind_speed, wind_direction, approach_heading);
        fprintf('  相对角度: %.0f°, %s: %.2f m/s, 侧风: %.2f m/s\n', ...
            relative_angle, wind_type, abs(headwind), crosswind);
        fprintf('  空速: %.1f m/s, 地速: %.1f m/s\n', V, ground_speed);
    end
    
    % 保存风效应信息
    wind_headwind = headwind;
    wind_crosswind = crosswind;
    
else
    ground_speed = V;
    wind_headwind = 0;
    wind_crosswind = 0;
end
    
    % 3. 俯仰动力学
    theta_cmd_rad = deg2rad(pitch_cmd);
    
    max_pitch_rate = deg2rad(4);
    pitch_rate = (theta_cmd_rad - theta_rad) / 1.5;
    pitch_rate = sign(pitch_rate) * min(abs(pitch_rate), max_pitch_rate);
    
    new_theta_rad = theta_rad + pitch_rate * dt;
    new_theta = rad2deg(new_theta_rad);
    
    % 4. 迎角计算
    alpha = new_theta_rad - gamma_rad;
    
    max_alpha = deg2rad(15);
    min_alpha = deg2rad(-2);
    alpha = max(min_alpha, min(max_alpha, alpha));
    
    % 5. 气动力计算（使用空速V）
    dynamic_pressure = 0.5 * atmosphere.rho * V^2 * UAV.wing_area;
    
    % 升力系数计算
    CL = UAV.CL0 + UAV.CL_alpha * alpha;
    CL = max(0.3, min(1.5, CL));
    
    % 阻力系数
    CD0 = UAV.CD0;
    CD_alpha_term = UAV.CD_alpha * abs(alpha)^2;
    
    % 诱导阻力
    AR = 8;
    e = 0.85;
    CD_induced = (CL^2) / (pi * AR * e);
    
    CD = CD0 + CD_alpha_term + CD_induced;
    CD = max(0.03, min(0.5, CD));
    
    lift = dynamic_pressure * CL;
    drag = dynamic_pressure * CD;
    
    % 6. 推力系统
    thrust_cmd = throttle_cmd * UAV.max_thrust;
    
    max_thrust_rate = UAV.max_thrust * 0.1;
    current_thrust = state.throttle * UAV.max_thrust;
    thrust_rate = (thrust_cmd - current_thrust) / UAV.engine_time_constant;
    thrust_rate = sign(thrust_rate) * min(abs(thrust_rate), max_thrust_rate);
    
    thrust = current_thrust + thrust_rate * dt;
    
    max_allowed_thrust = UAV.mass * atmosphere.g * 0.8;
    thrust = min(thrust, max_allowed_thrust);
    
    % 7. 纵向动力学（基于空速）
    F_longitudinal = thrust * cos(alpha) - drag - UAV.mass * atmosphere.g * sin(gamma_rad);
    
    % 8. 空速变化
    V_dot = F_longitudinal / UAV.mass;
    new_V = V + V_dot * dt;
    
    % 速度控制辅助 - 如果速度过高，增加阻力
    if thrust < 200 && new_V > target_speed * 1.1
        extra_decel = (new_V - target_speed) / 5.0;
        new_V = new_V - extra_decel * dt;
    end
    
    % 速度限制
    stall_speed = sqrt(2 * UAV.mass * atmosphere.g / (atmosphere.rho * UAV.wing_area * 1.3));
    min_speed = stall_speed * 1.15;
    max_speed = target_speed * 1.3;
    
    new_V = max(min_speed, min(max_speed, new_V));
    
    % 9. 法向动力学
    F_normal = lift + thrust * sin(alpha) - UAV.mass * atmosphere.g * cos(gamma_rad);
    
    if new_V > 0.5
        gamma_dot = F_normal / (UAV.mass * new_V);
    else
        gamma_dot = 0;
    end
    gamma_dot_rad = gamma_dot;
    
    new_gamma_rad = gamma_rad + gamma_dot_rad * dt;
    
    max_gamma_climb = deg2rad(5);
    max_gamma_descent = asin(max_descent_rate / max(1, new_V));
    
    new_gamma_rad = max(-max_gamma_descent, min(max_gamma_climb, new_gamma_rad));
    new_gamma = rad2deg(new_gamma_rad);
    
    % 10. 垂直速度（基于空速）
    new_h_dot = new_V * sin(new_gamma_rad);
    
    % 11. 更新高度
    new_h = h + new_h_dot * dt;
    
    if new_h < 0
        new_h = 0;
        new_h_dot = 0;
        new_gamma_rad = 0;
        new_gamma = 0;
    end
    
    % 12. 距离计算（关键修复：使用地速）
    % 水平地速 = 地速 * cos(航迹角)
    horizontal_velocity = ground_speed * cos(new_gamma_rad);
    delta_x = horizontal_velocity * dt;
    
    new_x = x - delta_x;
    
    % 13. 打包新状态
    new_state.distance = new_x;
    new_state.altitude = new_h;
    new_state.speed = new_V; % 存储空速
    new_state.pitch = new_theta;
    new_state.descent_rate = new_h_dot;
    new_state.throttle = thrust / UAV.max_thrust;
    new_state.elevator = elevator_cmd;
    new_state.alpha = rad2deg(alpha);
    
    % 14. 调试信息
    persistent iteration_count;
    if isempty(iteration_count)
        iteration_count = 0;
    end
    iteration_count = iteration_count + 1;
    
    if iteration_count <= 10 || mod(iteration_count, 100) == 0
        if wind_params.enable && wind_params.speed > 0
            % 修正：正确显示风类型
            if wind_headwind > 0
                wind_type_display = '顶风';
            else
                wind_type_display = '顺风';
            end
            fprintf('动力学[%d]: 空速=%.1f(m/s), 地速=%.1f(m/s), pitch=%.1f°, h=%.0fm, h_dot=%.2f(m/s), 下降角=%.1f°, 距离=%.0fm\n', ...
                iteration_count, new_V, ground_speed, new_theta, new_h, new_h_dot, new_gamma, new_x);
            fprintf('  风场: %s%.1fm/s, 地速变化:%.1f%%\n', ...
                wind_type_display, abs(wind_headwind), (ground_speed/V-1)*100);
        else
            fprintf('动力学[%d]: 空速=%.1f(m/s), pitch=%.1f°, h=%.0fm, h_dot=%.2f(m/s), 下降角=%.1f°, 距离=%.0fm\n', ...
                iteration_count, new_V, new_theta, new_h, new_h_dot, new_gamma, new_x);
        end
    end
end