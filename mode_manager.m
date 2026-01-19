function [new_mode, params] = mode_manager(current_mode, radio_alt, ...
    descent_rate, gs_error, approach, current_time, distance)
% 模式管理函数（最终修正版）

    params.flare_factor = 0;
    new_mode = current_mode;
    
    % 判断是否飞过跑道入口
    is_past_threshold = (distance < 0);
    
    % 将决断高度检查放宽到80米
    if radio_alt <= approach.DH && abs(gs_error) > 80 && ~is_past_threshold
        new_mode = 'GO_AROUND';
        if ~strcmp(current_mode, 'GO_AROUND')
            fprintf('时间%.1fs: 决断高度处下滑道偏差过大(%.1fm > 80m)，执行复飞！\n', ...
                current_time, abs(gs_error));
        end
        return;
    end
    
    % 下降率过大检查
    if radio_alt > approach.DH && descent_rate < -approach.target_speed * 0.3
        new_mode = 'GO_AROUND';
        if ~strcmp(current_mode, 'GO_AROUND')
            fprintf('时间%.1fs: 下降率过大(%.2fm/s > %.2fm/s)，执行复飞！\n', ...
                current_time, descent_rate, -approach.target_speed * 0.3);
        end
        return;
    end
    
    % 飞过跑道但高度过高 - 复飞
    if is_past_threshold && radio_alt > 30
        new_mode = 'GO_AROUND';
        if ~strcmp(current_mode, 'GO_AROUND')
            fprintf('时间%.1fs: 飞过跑道入口但高度过高(%.1fm > 30m)，执行复飞！\n', ...
                current_time, radio_alt);
        end
        return;
    end
    
    % 模式切换逻辑
    switch current_mode
        case 'GS_TRACK'
            % 计算拉平应该开始的距离
            distance_for_flare = approach.flare_start / tand(approach.glide_slope);
            
            % 简化拉平触发：主要基于距离
            if distance <= distance_for_flare && distance > 0
                % 到达拉平开始点
                new_mode = 'FLARE';
                if ~strcmp(current_mode, 'FLARE')
                    fprintf('时间%.1fs: 到达拉平点，距入口%.0fm，高度%.1fm，进入拉平\n', ...
                        current_time, distance, radio_alt);
                end
            elseif radio_alt <= approach.flare_start * 0.8 && distance > 0
                % 高度接近拉平高度，也触发拉平
                new_mode = 'FLARE';
                if ~strcmp(current_mode, 'FLARE')
                    fprintf('时间%.1fs: 高度接近拉平高度(%.1fm)，进入拉平\n', ...
                        current_time, radio_alt);
                end
            else
                new_mode = 'GS_TRACK';
            end
            
        case 'FLARE'
            if radio_alt <= 0.5 && abs(descent_rate) < 2.5
                new_mode = 'TOUCHDOWN';
                if ~strcmp(current_mode, 'TOUCHDOWN')
                    fprintf('时间%.1fs: 接地！高度%.2fm，下降率%.2fm/s，误差%.1fm\n', ...
                        current_time, radio_alt, descent_rate, gs_error);
                end
            elseif is_past_threshold && radio_alt > 20
                new_mode = 'GO_AROUND';
                if ~strcmp(current_mode, 'GO_AROUND')
                    fprintf('时间%.1fs: 飞过跑道但高度过高(%.1fm)，执行复飞！\n', current_time, radio_alt);
                end
            elseif radio_alt > 60
                new_mode = 'GS_TRACK';
                if ~strcmp(current_mode, 'GS_TRACK')
                    fprintf('时间%.1fs: 高度回升过多(%.1fm)，返回下滑模式\n', current_time, radio_alt);
                end
            else
                new_mode = 'FLARE';
                % 计算拉平因子
                if distance > 0
                    params.flare_factor = 1 - (radio_alt / approach.flare_start);
                else
                    params.flare_factor = min(1, 1 - (distance / -150));
                end
                params.flare_factor = max(0, min(1, params.flare_factor));
                
                % 调试信息
                if current_time < 10 || mod(floor(current_time), 5) == 0
                    fprintf('时间%.1fs: 拉平模式，高度%.1fm，下降率%.2f，因子%.2f\n', ...
                        current_time, radio_alt, descent_rate, params.flare_factor);
                end
            end
            
        case 'TOUCHDOWN'
            if radio_alt <= 0.1
                new_mode = 'ROLLOUT';
                if ~strcmp(current_mode, 'ROLLOUT')
                    fprintf('时间%.1fs: 开始滑跑\n', current_time);
                end
            else
                new_mode = 'TOUCHDOWN';
            end
            
        case 'ROLLOUT'
            new_mode = 'ROLLOUT';
            
        case 'GO_AROUND'
            new_mode = 'GO_AROUND';
            
        otherwise
            new_mode = 'GS_TRACK';
    end
end