%% 固定翼无人机自动进近仿真 - GUI版本
% 最终修正版 - 带可靠参数配置

clear; close all; clc;

%% 1. 显示欢迎信息
disp('===============================================');
disp('  固定翼无人机自动进近仿真系统 (GUI版本)');
disp('===============================================');
disp(' ');

%% 2. 创建参数设置GUI - 使用可靠版本
[params, continue_sim] = parameter_config_gui();  % 使用可靠版本

if ~continue_sim
    disp('用户取消仿真。');
    return;
end

%% 3. 提取参数
approach = params.approach;
UAV = params.UAV;
atmosphere = params.atmosphere;
ctrl = params.ctrl;
sim_params = params.sim_params;
wind_params = params.wind_params;

%% 4. 显示设置参数
disp('=== 仿真参数设置 ===');
disp(['下滑道角度: ', num2str(approach.glide_slope), ' 度']);
disp(['目标速度: ', num2str(approach.target_speed), ' m/s']);
disp(['决断高度: ', num2str(approach.DH), ' m']);
disp(['拉平高度: ', num2str(approach.flare_start), ' m']);
disp(['最大下降率限制: ', num2str(ctrl.max_descent_rate), ' m/s']);
disp(['仿真时间: ', num2str(sim_params.T), ' 秒']);
if wind_params.enable
    disp(['风速: ', num2str(wind_params.speed), ' m/s, 风向: ', num2str(wind_params.direction), ' 度']);
end
disp(' ');

%% 5. 计算理论参数
theoretical_descent = -approach.target_speed * sind(approach.glide_slope);
glide_distance = approach.distance_FAF;
theoretical_time = glide_distance / approach.target_speed;

% 计算拉平开始点距离
distance_from_threshold_to_flare = approach.flare_start / tand(approach.glide_slope);

fprintf('理论%.1f度下滑道参数 (从FAF开始):\n', approach.glide_slope);
fprintf('  FAF距跑道入口: %.0f m\n', approach.distance_FAF);
fprintf('  FAF高度: %.0f m\n', approach.initial_alt);
fprintf('  理论下降率: %.2f m/s (%.0f ft/min)\n', ...
    theoretical_descent, abs(theoretical_descent) * 196.85);
fprintf('  拉平开始点距跑道入口: %.0f m\n', distance_from_threshold_to_flare);
fprintf('  进近距离: %.0f m\n', glide_distance);
fprintf('  理论进近时间: %.0f 秒\n', theoretical_time);

% 检查几何一致性
required_FAF_altitude = approach.flare_start + (approach.distance_FAF - distance_from_threshold_to_flare) * tand(approach.glide_slope);
altitude_discrepancy = approach.initial_alt - required_FAF_altitude;

if abs(altitude_discrepancy) > 5
    fprintf('\n警告: FAF高度与下滑道几何不一致！\n');
    fprintf('  理论需要的FAF高度: %.1f m\n', required_FAF_altitude);
    fprintf('  当前设置FAF高度: %.1f m\n', approach.initial_alt);
    fprintf('  偏差: %.1f m\n', altitude_discrepancy);
    
    if altitude_discrepancy > 0
        fprintf('  建议: 降低FAF高度到 %.1f m 或增加下滑角到 %.1f 度\n', ...
            required_FAF_altitude, atand(approach.initial_alt/(approach.distance_FAF - distance_from_threshold_to_flare)));
    else
        fprintf('  建议: 增加FAF高度到 %.1f m 或减小下滑角到 %.1f 度\n', ...
            required_FAF_altitude, atand(approach.initial_alt/(approach.distance_FAF - distance_from_threshold_to_flare)));
    end
end
disp(' ');

%% 6. 设置仿真参数
dt = sim_params.dt;
T = sim_params.T;
t = 0:dt:T;
N = length(t);

fprintf('仿真设置: 步长=%.3fs, 总时间=%.1fs, 总步数=%d\n', dt, T, N);

%% 7. 飞机初始状态（从GUI获取或使用默认）
state.distance = approach.distance_FAF;
state.altitude = approach.initial_alt;

% 使用GUI中设置的初始值或计算默认值
if isfield(params, 'initial_conditions')
    state.speed = params.initial_conditions.speed;
    state.pitch = params.initial_conditions.pitch;
    state.descent_rate = params.initial_conditions.descent_rate;
    state.alpha = params.initial_conditions.alpha;
else
    state.speed = approach.target_speed * 0.95;  % 略低于目标速度
    state.pitch = 3.0;   % 关键：改为3度俯仰（理论值）
    state.descent_rate = theoretical_descent * 0.9;  % 略小于理论下降率
    state.alpha = 6.0;  % 对应3度下滑的迎角
end

state.throttle = 0.03;
state.elevator = 0;

%% 7.5 强制确保初始模式正确
ctrl.mode = 'GS_TRACK';
fprintf('确保初始模式: %s\n', ctrl.mode);

%% 7.6 初始误差计算
fprintf('\n=== 初始状态检查 ===\n');
fprintf('当前距离: %.1f m (FAF)\n', state.distance);
fprintf('当前高度: %.1f m\n', state.altitude);
fprintf('当前速度: %.1f m/s\n', state.speed);
fprintf('理论%.1f度下滑下降率: %.2f m/s\n', approach.glide_slope, theoretical_descent);
fprintf('最大允许下降率: %.2f m/s\n', ctrl.max_descent_rate);

% 风场分析
if wind_params.enable
    approach_heading = 270;  % 向西进近
    relative_angle = wind_params.direction - approach_heading;
    headwind = wind_params.speed * cosd(relative_angle);
    crosswind = wind_params.speed * sind(relative_angle);
    
    fprintf('\n=== 风场分析 ===\n');
    fprintf('风速: %.1f m/s\n', wind_params.speed);
    fprintf('风向: %.0f° (风吹来的方向)\n', wind_params.direction);
    fprintf('跑道方向: %.0f° (向西)\n', approach_heading);
    fprintf('相对角度: %.0f°\n', relative_angle);
    
    % 修正：正确显示顶风/顺风
    if headwind > 0
        fprintf('顶风分量: %.2f m/s\n', headwind);
    else
        fprintf('顺风分量: %.2f m/s\n', abs(headwind));
    end
    fprintf('侧风分量: %.2f m/s\n', crosswind);
    
    % 风场警告
    if headwind < -5  % 强顺风
        fprintf('警告: 强顺风(%.1f m/s)，进近距离将显著缩短！\n', abs(headwind));
        fprintf('建议: 增加进近速度或减小下滑角\n');
    elseif headwind < -2  % 中等顺风
        fprintf('注意: 中等顺风(%.1f m/s)，进近距离将缩短\n', abs(headwind));
    elseif headwind > 5  % 强顶风
        fprintf('警告: 强顶风(%.1f m/s)，进近距离将显著延长！\n', headwind);
        fprintf('建议: 减小进近速度或增加下滑角\n');
    elseif headwind > 2  % 中等顶风
        fprintf('注意: 中等顶风(%.1f m/s)，进近距离将延长\n', headwind);
    end
    
    if abs(crosswind) > 5
        fprintf('警告: 强侧风(%.1f m/s)，可能需要侧滑修正！\n', abs(crosswind));
    elseif abs(crosswind) > 2
        fprintf('注意: 中等侧风(%.1f m/s)\n', abs(crosswind));
    end
    
    % 计算受风影响的进近距离
    if abs(headwind) > 0.5
        theoretical_ground_speed = approach.target_speed - headwind;
        adjusted_distance = approach.distance_FAF * (approach.target_speed / theoretical_ground_speed);
        fprintf('\n受风影响的进近距离估算:\n');
        
        % 修正：使用正确的风类型描述
        if headwind > 0
            wind_type_str = '顶';
        else
            wind_type_str = '顺';
        end
        
        fprintf('  理论地速: %.1f m/s (空速%.1f m/s %s风%.1f m/s)\n', ...
            theoretical_ground_speed, approach.target_speed, ...
            wind_type_str, abs(headwind));
        fprintf('  理论进近距离: %.0f m\n', approach.distance_FAF);
        fprintf('  受风影响距离: %.0f m (变化: %.0f%%)\n', ...
            adjusted_distance, (adjusted_distance/approach.distance_FAF-1)*100);
    end
end
% 计算推重比
TWR = UAV.max_thrust / (UAV.mass * atmosphere.g);
fprintf('推重比: %.2f\n', TWR);
if TWR < 0.8
    fprintf('警告: 推重比偏低，复飞性能可能不足\n');
elseif TWR > 1.5
    fprintf('注意: 推重比偏高，控制需更精细\n');
end

% 计算进近速度下的升力系数
required_CL = UAV.mass * atmosphere.g / (0.5 * atmosphere.rho * state.speed^2 * UAV.wing_area);
fprintf('平飞所需CL: %.3f\n', required_CL);
fprintf('零升力系数CL0: %.3f\n', UAV.CL0);

if UAV.CL0 > required_CL * 1.2
    fprintf('警告: CL0偏高，飞机可能过"轻"，拉平控制困难\n');
elseif UAV.CL0 < required_CL * 0.8
    fprintf('警告: CL0偏低，飞机可能过"重"，需更大迎角\n');
else
    fprintf('CL0与所需CL匹配良好\n');
end

% 计算下滑所需CL
CL_for_glide = required_CL * cosd(approach.glide_slope);
fprintf('%.1f度下滑理想CL: %.3f (比平飞小%.1f%%)\n', ...
    approach.glide_slope, CL_for_glide, (1 - CL_for_glide/required_CL)*100);

% 计算理论所需迎角和俯仰角
if UAV.CL_alpha > 0
    target_CL = CL_for_glide;
    required_alpha = (target_CL - UAV.CL0) / UAV.CL_alpha;
    target_gamma = deg2rad(-approach.glide_slope);
    required_pitch = rad2deg(required_alpha + target_gamma);
    
    fprintf('理论分析:\n');
    fprintf('  下滑所需CL: %.3f\n', target_CL);
    fprintf('  所需迎角: %.1f度\n', rad2deg(required_alpha));
    fprintf('  目标航迹角: %.1f度\n', rad2deg(target_gamma));
    fprintf('  理论俯仰角: %.1f度\n', required_pitch);
    fprintf('  当前俯仰角: %.1f度\n', state.pitch);
    
    if abs(state.pitch - required_pitch) > 3
        fprintf('  注意: 当前俯仰角与理论值偏差较大\n');
    end
end

% 计算初始高度误差
if state.distance >= approach.distance_FAF
    ideal_alt = approach.initial_alt;
elseif state.distance <= distance_from_threshold_to_flare
    k = 3.5 / distance_from_threshold_to_flare;
    ideal_alt = approach.flare_start * exp(-k * (distance_from_threshold_to_flare - state.distance));
else
    ideal_alt = approach.flare_start + (state.distance - distance_from_threshold_to_flare) * tand(approach.glide_slope);
end

initial_gs_error = state.altitude - ideal_alt;
fprintf('初始下滑道误差: %.1f m\n', initial_gs_error);

if abs(initial_gs_error) > 10
    fprintf('警告: 初始下滑道误差较大\n');
end
fprintf('----------------------------------------\n');

%% 8. 数据存储
history.time = t;
history.distance = zeros(1, N);
history.altitude = zeros(1, N);
history.speed = zeros(1, N);
history.pitch = zeros(1, N);
history.descent_rate = zeros(1, N);
history.throttle = zeros(1, N);
history.elevator = zeros(1, N);
history.mode = cell(1, N);
history.gs_error = zeros(1, N);
history.radio_alt = zeros(1, N);
history.glide_path_angle = zeros(1, N);
history.alpha = zeros(1, N);
history.wind_effect = zeros(1, N);
history.speed_error = zeros(1, N);

%% 9. 显示初始状态
disp('=== 初始状态 ===');
fprintf('位置: FAF点 (距跑道入口 %.0f m)\n', state.distance);
fprintf('高度: %.0f m (FAF高度)\n', state.altitude);
fprintf('速度: %.1f m/s\n', state.speed);
fprintf('俯仰角: %.1f 度\n', state.pitch);
fprintf('下降率: %.2f m/s (理论: %.2f m/s)\n', state.descent_rate, theoretical_descent);
if wind_params.enable
    fprintf('风场: %.1f m/s, %d度\n', wind_params.speed, wind_params.direction);
end
disp(' ');

%% 10. 创建进度条
h = waitbar(0, '正在运行进近仿真...', 'Name', '仿真进度');
progress_step = ceil(N/100);

%% 11. 主仿真循环
disp('开始进近仿真...');
fprintf('时间 [s] | 距离 [m] | 高度 [m] | 速度 [m/s] | 下降率 [m/s] | 下滑道误差 [m] | 模式\n');
fprintf('---------|----------|----------|------------|--------------|------------------|--------\n');

debug_iterations = 5;
continue_simulation = true;

for i = 1:N
    if ~continue_simulation
        break;
    end
    
    current_time = t(i);
    
    % 更新进度条
    if mod(i, progress_step) == 0
        waitbar(i/N, h, sprintf('仿真进度: %.1f%%\n时间: %.1f秒', i/N*100, current_time));
    end
    
    % 检查是否取消
    try
        % 正常执行
    catch
        continue_simulation = false;
        break;
    end
    
    % 无线电高度
    radio_alt = state.altitude;
    
    % ========== 计算下滑道误差 ==========
    FAF_distance = approach.distance_FAF;
    FAF_altitude = approach.initial_alt;
    flare_start_alt = approach.flare_start;
    glide_slope_angle = approach.glide_slope;
    
    distance_from_threshold_to_flare = flare_start_alt / tand(glide_slope_angle);
    
    if state.distance >= FAF_distance
        ideal_alt = FAF_altitude;
    elseif state.distance <= 0
        ideal_alt = 0;
    elseif state.distance <= distance_from_threshold_to_flare
        k = 3.5 / distance_from_threshold_to_flare;
        ideal_alt = flare_start_alt * exp(-k * (distance_from_threshold_to_flare - state.distance));
    else
        ideal_alt = flare_start_alt + (state.distance - distance_from_threshold_to_flare) * tand(glide_slope_angle);
    end
    
    gs_error = state.altitude - ideal_alt;
    
     % 计算当前航迹角
    if state.speed > 0.5
        gamma = asind(state.descent_rate / state.speed);
    else
        gamma = 0;
    end
    
    % 模式管理
    [ctrl.mode, mode_params] = mode_manager(ctrl.mode, radio_alt, ...
        state.descent_rate, gs_error, approach, current_time, state.distance);
    
    % 根据模式选择控制器
    switch ctrl.mode
        case 'GS_TRACK'
            [pitch_cmd, throttle_cmd] = gs_controller(...
                gs_error, state.speed, approach.target_speed, ...
                state.descent_rate, gamma, ctrl, dt, i, state.altitude, wind_params); % 添加wind_params
            
        case 'FLARE'
            [pitch_cmd, throttle_cmd] = flare_controller(...
                radio_alt, state.descent_rate, state.speed, ...
                mode_params.flare_factor, ctrl, dt, UAV.mass, approach.target_speed);
            
        case 'TOUCHDOWN'
            pitch_cmd = 0;
            throttle_cmd = 0.1;
            
        case 'ROLLOUT'
            pitch_cmd = -1;
            throttle_cmd = 0;
            
        case 'GO_AROUND'
            pitch_cmd = 10;
            throttle_cmd = 0.8;
            if i < 10 || ~strcmp(history.mode{i-1}, 'GO_AROUND')
                fprintf('时间%.1fs: 执行复飞程序！\n', current_time);
            end
    end
    
    % 强力修正机制
    if i > 20
        % 如果误差持续过大，强制修正
        if abs(gs_error) > 30
            fprintf('强力修正：下滑道误差过大(%.1fm)，强制调整！\n', gs_error);
            
            if gs_error < -20  % 飞机过低
                % 强制大幅抬头，减小下降率
                pitch_cmd = 5.0;
                throttle_cmd = 0.04;  % 增加推力
                fprintf('  修正：飞机过低，抬头到%.1f度，增加推力\n', pitch_cmd);
            elseif gs_error > 20  % 飞机过高
                % 强制大幅低头，增加下降率
                pitch_cmd = -1.0;
                throttle_cmd = 0.01;  % 减小推力
                fprintf('  修正：飞机过高，低头到%.1f度，减小推力\n', pitch_cmd);
            end
        end
        
        % 检查下降率
        if state.descent_rate < -2.5  % 下降率过大
            pitch_cmd = max(pitch_cmd, 2.0);  % 强制抬头
            fprintf('  修正：下降率过大(%.2f)，抬头到%.1f度\n', state.descent_rate, pitch_cmd);
        elseif state.descent_rate > -0.5  % 下降率过小
            pitch_cmd = min(pitch_cmd, -1.0);  % 强制低头
            fprintf('  修正：下降率过小(%.2f)，低头到%.1f度\n', state.descent_rate, pitch_cmd);
        end
    end
    
    % 指令限制
    pitch_cmd = max(ctrl.min_pitch, min(ctrl.max_pitch, pitch_cmd));
    throttle_cmd = max(ctrl.min_throttle, min(ctrl.max_throttle, throttle_cmd));
    
    % 转换为升降舵指令
    pitch_error = pitch_cmd - state.pitch;
    elevator_cmd = pitch_error * 0.12;
    elevator_cmd = max(-ctrl.max_elevator, min(ctrl.max_elevator, elevator_cmd));
    
    % 更新飞机状态 - 修正风场问题
    state = update_dynamics(state, pitch_cmd, throttle_cmd, ...
        elevator_cmd, UAV, atmosphere, dt, ctrl.max_descent_rate, wind_params, approach.target_speed);
    
    % 存储数据
    history.distance(i) = state.distance;
    history.altitude(i) = state.altitude;
    history.speed(i) = state.speed;
    history.pitch(i) = state.pitch;
    history.descent_rate(i) = state.descent_rate;
    history.throttle(i) = throttle_cmd;
    history.elevator(i) = elevator_cmd;
    history.mode{i} = ctrl.mode;
    history.gs_error(i) = gs_error;
    history.radio_alt(i) = radio_alt;
    history.glide_path_angle(i) = gamma;
    history.alpha(i) = state.alpha;
    history.speed_error(i) = state.speed - approach.target_speed;
    
    if wind_params.enable
        history.wind_effect(i) = wind_params.speed;
    end
    
 % 显示进度（每5秒显示一次）
if mod(i, 100) == 0
    if wind_params.enable
        % 计算顶风分量和地速
        approach_heading = 270;
        relative_angle = wind_params.direction - approach_heading;
        headwind = wind_params.speed * cosd(relative_angle);
        ground_speed = state.speed - headwind;
        
        % 判断风况
        if headwind > 0
            wind_type = '顶风';
        elseif headwind < 0
            wind_type = '顺风';
        else
            wind_type = '无风';
        end
        
        wind_info = sprintf('%s:%.1fm/s,地速:%.1fm/s', ...
            wind_type, abs(headwind), ground_speed);
    else
        wind_info = '无风';
    end
    
    fprintf('%7.1f | %8.0f | %8.0f | %10.1f | %12.2f | %16.2f | %s | %s\n', ...
        current_time, state.distance, state.altitude, state.speed, ...
        state.descent_rate, gs_error, ctrl.mode, wind_info);
end
    
    % 检查接地条件
    if state.altitude <= 0.3 && abs(state.descent_rate) < 1.5 && state.pitch > -5
        fprintf('\n--- 接地完成 ---\n');
        
        % 计算接地时的风信息 - 修正显示
        if wind_params.enable
            approach_heading = 270;
            relative_angle = wind_params.direction - approach_heading;
            headwind = wind_params.speed * cosd(relative_angle);
            ground_speed = state.speed - headwind;  % 注意：地速 = 空速 - 顶风分量
            
            % 修正显示
            if headwind > 0
                wind_type_str = '顶风';
            else
                wind_type_str = '顺风';
            end
            
            fprintf('接地时风速: %.1f m/s, 风向: %.0f°, %s: %.1f m/s\n', ...
                wind_params.speed, wind_params.direction, wind_type_str, abs(headwind));
            fprintf('接地空速: %.1f m/s, 接地地速: %.1f m/s\n', state.speed, ground_speed);
        end
        
        if state.distance >= 0
            fprintf('接地位置: 跑道入口前 %.1f m\n', state.distance);
        else
            fprintf('接地位置: 飞过跑道入口 %.1f m\n', -state.distance);
        end
        fprintf('接地速度: %.1f m/s (目标: %.1f m/s)\n', state.speed, approach.target_speed);
        fprintf('速度误差: %.1f m/s (%.1f%%)\n', ...
            state.speed - approach.target_speed, ...
            abs(state.speed - approach.target_speed)/approach.target_speed*100);
        fprintf('接地下降率: %.2f m/s\n', state.descent_rate);
        fprintf('接地俯仰角: %.1f 度\n', state.pitch);
        fprintf('最后下滑道误差: %.2f m\n', gs_error);
        fprintf('理想接地高度应为: %.2f m\n', ideal_alt);
        break;
    end
    
    % 检查复飞成功
    if strcmp(ctrl.mode, 'GO_AROUND') && state.altitude > approach.DH + 50
        fprintf('\n复飞成功，爬升到安全高度\n');
        break;
    end
end

% 关闭进度条
if ishandle(h)
    close(h);
end

% 截断未使用的数据
valid_N = min(i, N);
if valid_N < N
    history.time = history.time(1:valid_N);
    history.distance = history.distance(1:valid_N);
    history.altitude = history.altitude(1:valid_N);
    history.speed = history.speed(1:valid_N);
    history.pitch = history.pitch(1:valid_N);
    history.descent_rate = history.descent_rate(1:valid_N);
    history.throttle = history.throttle(1:valid_N);
    history.elevator = history.elevator(1:valid_N);
    history.mode = history.mode(1:valid_N);
    history.gs_error = history.gs_error(1:valid_N);
    history.radio_alt = history.radio_alt(1:valid_N);
    history.glide_path_angle = history.glide_path_angle(1:valid_N);
    history.alpha = history.alpha(1:valid_N);
    history.speed_error = history.speed_error(1:valid_N);
    history.wind_effect = history.wind_effect(1:valid_N);
end

%% 12. 性能分析
fprintf('\n=== 性能分析 ===\n');
fprintf('总仿真时间: %.1f 秒\n', history.time(end));
fprintf('平均下降率: %.2f m/s (理论: %.2f m/s)\n', ...
    mean(history.descent_rate(1:valid_N)), theoretical_descent);
fprintf('最大下降率: %.2f m/s\n', min(history.descent_rate(1:valid_N)));
fprintf('最小下降率: %.2f m/s\n', max(history.descent_rate(1:valid_N)));
fprintf('平均空速: %.1f m/s (目标: %.1f m/s)\n', ...
    mean(history.speed(1:valid_N)), approach.target_speed);
fprintf('平均速度误差: %.1f m/s\n', mean(history.speed_error(1:valid_N)));
fprintf('平均下滑道误差绝对值: %.2f m\n', mean(abs(history.gs_error(1:valid_N))));
fprintf('最大下滑道误差绝对值: %.2f m\n', max(abs(history.gs_error(1:valid_N))));

% 下滑道误差分析
gs_error_mean = mean(history.gs_error(1:valid_N));
gs_error_std = std(history.gs_error(1:valid_N));
fprintf('下滑道误差均值: %.2f m\n', gs_error_mean);
fprintf('下滑道误差标准差: %.2f m\n', gs_error_std);

% 速度误差分析
speed_error_mean = mean(history.speed_error(1:valid_N));
speed_error_std = std(history.speed_error(1:valid_N));
fprintf('速度误差均值: %.1f m/s\n', speed_error_mean);
fprintf('速度误差标准差: %.1f m/s\n', speed_error_std);

% 下滑道跟踪性能评级
mean_abs_error = mean(abs(history.gs_error(1:valid_N)));
fprintf('平均绝对误差: %.2f m\n', mean_abs_error);

if mean_abs_error < 2.0
    fprintf('下滑道跟踪: 优秀 (误差 < 2m)\n');
elseif mean_abs_error < 5.0
    fprintf('下滑道跟踪: 良好 (误差 < 5m)\n');
elseif mean_abs_error < 10.0
    fprintf('下滑道跟踪: 合格 (误差 < 10m)\n');
else
    fprintf('下滑道跟踪: 需改进 (误差 ≥ 10m)\n');
end

% 速度控制性能评级
mean_abs_speed_error = mean(abs(history.speed_error(1:valid_N)));
fprintf('平均速度误差绝对值: %.1f m/s\n', mean_abs_speed_error);

if mean_abs_speed_error < 1.0
    fprintf('速度控制: 优秀 (误差 < 1m/s)\n');
elseif mean_abs_speed_error < 2.0
    fprintf('速度控制: 良好 (误差 < 2m/s)\n');
elseif mean_abs_speed_error < 4.0
    fprintf('速度控制: 合格 (误差 < 4m/s)\n');
else
    fprintf('速度控制: 需改进 (误差 ≥ 4m/s)\n');
end

% 接地质量评估
if history.altitude(end) <= 0.5
    sink_rate = history.descent_rate(end);
    speed = history.speed(end);
    final_gs_error = history.gs_error(end);
    
    fprintf('\n--- 接地质量评估 ---\n');
    fprintf('接地下降率: %.2f m/s', abs(sink_rate));
    if abs(sink_rate) < 0.5
        fprintf(' (优秀 - 非常轻柔)\n');
    elseif abs(sink_rate) < 1.0
        fprintf(' (良好 - 标准接地)\n');
    elseif abs(sink_rate) < 2.0
        fprintf(' (可接受 - 稍重)\n');
    else
        fprintf(' (需改进 - 过重)\n');
    end
    
    fprintf('接地速度: %.1f m/s (目标: %.1f m/s)', speed, approach.target_speed);
    speed_error_percent = abs(speed - approach.target_speed)/approach.target_speed*100;
    if speed_error_percent < 5
        fprintf(' (优秀 - 速度精确)\n');
    elseif speed_error_percent < 10
        fprintf(' (良好 - 速度适当)\n');
    elseif speed_error_percent < 20
        fprintf(' (可接受 - 速度偏差一般)\n');
    else
        fprintf(' (需改进 - 速度偏差大)\n');
    end
    
    fprintf('接地下滑道误差: %.2f m', final_gs_error);
    if abs(final_gs_error) < 3
        fprintf(' (优秀 - 完美对准)\n');
    elseif abs(final_gs_error) < 8
        fprintf(' (良好 - 可接受偏差)\n');
    else
        fprintf(' (需改进 - 偏差过大)\n');
    end
end

%% 13. 绘制结果
plot_results(history, approach, valid_N);

%% 14. 显示完成信息
disp(' ');
disp('===============================================');
disp('  仿真完成！');
disp('===============================================');

%% 15. 提供重新运行选项
choice = questdlg('仿真完成！是否要重新运行？', ...
    '重新运行选项', ...
    '是，使用相同参数', '是，修改参数', '否，退出', '是，修改参数');

switch choice
    case '是，使用相同参数'
        close all;
        approach_gui_main;
        
    case '是，修改参数'
        close all;
        approach_gui_main;
        
    case '否，退出'
        disp('感谢使用固定翼无人机自动进近仿真系统！');
end