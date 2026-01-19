function [params, continue_sim] = parameter_config_gui()
% 参数配置GUI - 修复切换选项卡数据丢失问题

    % 使用独立的默认参数函数
    params = get_default_parameters_gui();
    continue_sim = true;
    
    % 创建主窗口
    fig = figure('Name', '固定翼无人机进近仿真参数配置', ...
                 'NumberTitle', 'off', ...
                 'Position', [100, 50, 1000, 700], ...
                 'MenuBar', 'figure', ...
                 'ToolBar', 'figure', ...
                 'Color', [0.95 0.95 0.95], ...
                 'Resize', 'on');
    
    % 存储数据
    fig_data.params = params;
    fig_data.continue_sim = true;
    fig_data.tab_buttons = [];
    fig_data.current_tab = 1;
    fig_data.is_collecting = false; % 防止递归调用
    fig_data.figure_handle = fig;   % 保存图形句柄
    
    set(fig, 'UserData', fig_data);
    
    % 设置关闭回调
    set(fig, 'DeleteFcn', @on_figure_delete);
    
    % 创建标题
    uicontrol('Parent', fig, ...
              'Style', 'text', ...
              'String', '固定翼无人机自动进近仿真参数配置', ...
              'Position', [200, 650, 600, 30], ...
              'FontSize', 16, ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.95 0.95 0.95]);
    
    % 创建选项卡区域
    tab_panel = uipanel('Parent', fig, ...
                       'Title', '', ...
                       'Position', [0.05, 0.20, 0.9, 0.70], ...
                       'BackgroundColor', [0.95 0.95 0.95], ...
                       'BorderType', 'none');

    % 创建选项卡按钮
    tab_names = {'进近参数', '飞机参数', '气动参数', '控制器参数', ...
                 '控制限制', '初始条件', '仿真设置', '风场参数', '高级参数'};

    tab_buttons = cell(1, length(tab_names));
    button_width = 95;
    button_height = 28;
    start_x = 10;
    button_y = 5;

    for i = 1:length(tab_names)
        tab_buttons{i} = uicontrol('Parent', tab_panel, ...
                                  'Style', 'togglebutton', ...
                                  'String', tab_names{i}, ...
                                  'Position', [start_x+(i-1)*button_width, button_y, button_width, button_height], ...
                                  'BackgroundColor', [0.85 0.85 0.85], ...
                                  'Callback', {@switch_tab_callback, i}, ...
                                  'Tag', sprintf('tab_btn_%d', i));
    end

    % 创建内容面板
    content_panel = uipanel('Parent', tab_panel, ...
                           'Title', '', ...
                           'Position', [0.02, 0.15, 0.96, 0.80], ...
                           'BackgroundColor', [0.98 0.98 0.98], ...
                           'BorderType', 'line', ...
                           'Tag', 'content_panel');
    
    % 存储面板句柄
    fig_data.tab_buttons = tab_buttons;
    fig_data.content_panel = content_panel;
    set(fig, 'UserData', fig_data);
    
    % 初始化所有选项卡数据
    fig_data = init_all_tabs_data(fig);
    
    % 创建第一个选项卡内容
    create_approach_panel_simple(fig);
    
    % 创建底部按钮
    create_bottom_buttons(fig);
    
    % 等待用户操作
    uiwait(fig);
    
    % 获取结果
    if ishandle(fig)
        fig_data = get(fig, 'UserData');
        params = fig_data.params;
        continue_sim = fig_data.continue_sim;
        close(fig);
    else
        continue_sim = false;
        params = [];
    end
end

%% 图形删除回调函数
function on_figure_delete(src, ~)
    % 图形关闭时的回调函数
    fig_data = get(src, 'UserData');
    
    if isfield(fig_data, 'current_tab') && fig_data.current_tab > 0
        % 确保保存当前选项卡数据
        save_current_tab_data(src);
        update_params_from_tab_data(src);
    end
    
    % 如果用户没有点击开始仿真按钮，则设置取消标志
    if ~isfield(fig_data, 'continue_sim') || isempty(fig_data.continue_sim)
        fig_data.continue_sim = false;
        set(src, 'UserData', fig_data);
    end
    
    % 恢复UI等待
    if strcmp(get(src, 'WaitStatus'), 'waiting')
        uiresume(src);
    end
end

%% 默认参数函数（放在前面确保可访问）
function params = get_default_parameters_gui()
    % 进近参数
    params.approach.glide_slope = 3.0;
    params.approach.distance_FAF = 5000;
    params.approach.flare_start = 15;
    
    % 计算几何一致的FAF高度
    distance_from_threshold_to_flare = params.approach.flare_start / tand(params.approach.glide_slope);
    params.approach.initial_alt = params.approach.flare_start + ...
        (params.approach.distance_FAF - distance_from_threshold_to_flare) * tand(params.approach.glide_slope);
    
    params.approach.target_speed = 28;
    params.approach.DH = 60;
    params.approach.touchdown_zone = 300;
    
    % 飞机参数
    params.UAV.mass = 600;
    params.UAV.wing_area = 12.5;
    params.UAV.max_thrust = 2200;
    params.UAV.CL0 = 0.55;
    params.UAV.CL_alpha = 4.8;
    params.UAV.CD0 = 0.035;
    params.UAV.CD_alpha = 0.30;
    params.UAV.engine_time_constant = 2.0;
    params.UAV.pitch_damping = 2.5;
    
    % 大气参数
    params.atmosphere.rho = 1.225;
    params.atmosphere.g = 9.81;
    
    % 控制器参数
    params.ctrl.mode = 'GS_TRACK';
    params.ctrl.target_gs_angle = 3.0;
    params.ctrl.gs_Kp = 0.18;
    params.ctrl.gs_Ki = 0.008;
    params.ctrl.gs_Kd = 0.12;
    params.ctrl.speed_Kp = 0.35;
    params.ctrl.speed_Ki = 0.015;
    params.ctrl.speed_Kd = 0.08;
    params.ctrl.flare_Kp = 0.6;
    params.ctrl.flare_Ki = 0.015;
    params.ctrl.target_sink_rate = -0.5;
    
    % 限制参数
    params.ctrl.max_pitch = 3;
    params.ctrl.min_pitch = -6;
    params.ctrl.max_throttle = 0.25;
    params.ctrl.min_throttle = 0.05;
    params.ctrl.max_descent_rate = 3.0;
    params.ctrl.max_elevator = 0.3;
    params.ctrl.max_climb_rate = 5.0;
    
    % 风参数
    params.wind_params.enable = false;
    params.wind_params.speed = 5.0;
    params.wind_params.direction = 90;
    
    % 仿真参数
    params.sim_params.dt = 0.05;
    params.sim_params.T = 250;
    
    % 初始条件
    params.initial_conditions.speed = params.approach.target_speed * 0.95;
    params.initial_conditions.pitch = 3.0;
    params.initial_conditions.descent_rate = -params.approach.target_speed * sind(params.approach.glide_slope) * 0.9;
    params.initial_conditions.alpha = 6.0;
end

%% 以下是所有其他辅助函数...
%% 初始化所有选项卡数据
function fig_data = init_all_tabs_data(fig)
    fig_data = get(fig, 'UserData');
    
    % 为每个选项卡创建数据存储结构
    num_tabs = 9;
    fig_data.tab_data = cell(1, num_tabs);
    
    % 初始化每个选项卡的存储数据
    for i = 1:num_tabs
        fig_data.tab_data{i} = struct();
    end
    
    % 使用当前参数初始化选项卡数据
    current_params = fig_data.params;
    fig_data.tab_data{1} = get_tab1_defaults(current_params);
    fig_data.tab_data{2} = get_tab2_defaults(current_params);
    fig_data.tab_data{3} = get_tab3_defaults(current_params);
    fig_data.tab_data{4} = get_tab4_defaults(current_params);
    fig_data.tab_data{5} = get_tab5_defaults(current_params);
    fig_data.tab_data{6} = get_tab6_defaults(current_params);
    fig_data.tab_data{7} = get_tab7_defaults(current_params);
    fig_data.tab_data{8} = get_tab8_defaults(current_params);
    fig_data.tab_data{9} = get_tab9_defaults(current_params);
    
    set(fig, 'UserData', fig_data);
end

%% 选项卡切换回调函数（修复版）
function switch_tab_callback(src, event, tab_index)
    fig = ancestor(src, 'figure');
    fig_data = get(fig, 'UserData');
    
    % 防止重复调用
    if fig_data.is_collecting
        return;
    end
    
    % 1. 保存当前选项卡的数据
    if fig_data.current_tab > 0 && fig_data.current_tab <= 9
        save_current_tab_data(fig);
    end
    
    % 2. 更新当前选项卡索引
    fig_data.current_tab = tab_index;
    
    % 3. 重置所有按钮颜色
    for i = 1:length(fig_data.tab_buttons)
        set(fig_data.tab_buttons{i}, 'BackgroundColor', [0.85 0.85 0.85]);
    end
    
    % 4. 设置当前按钮颜色
    set(fig_data.tab_buttons{tab_index}, 'BackgroundColor', [0.7 0.8 0.9]);
    
    % 5. 清空内容面板
    delete(get(fig_data.content_panel, 'Children'));
    
    % 6. 创建新选项卡内容
    fig_data.is_collecting = true; % 标记正在收集数据
    set(fig, 'UserData', fig_data);
    
    try
        % 根据选项卡索引创建内容
        switch tab_index
            case 1
                create_approach_panel_simple(fig);
            case 2
                create_uav_panel_simple(fig);
            case 3
                create_aerodynamic_panel_simple(fig);
            case 4
                create_controller_panel_simple(fig);
            case 5
                create_limits_panel_simple(fig);
            case 6
                create_initial_conditions_panel_simple(fig);
            case 7
                create_simulation_panel_simple(fig);
            case 8
                create_wind_panel_simple(fig);
            case 9
                create_advanced_panel_simple(fig);
        end
    catch ME
        disp(['创建选项卡错误: ' ME.message]);
    end
    
    % 恢复状态
    fig_data.is_collecting = false;
    set(fig, 'UserData', fig_data);
end

%% 保存当前选项卡数据
function save_current_tab_data(fig)
    fig_data = get(fig, 'UserData');
    panel = fig_data.content_panel;
    
    if isempty(panel) || ~ishandle(panel)
        return;
    end
    
    current_tab = fig_data.current_tab;
    if current_tab < 1 || current_tab > 9
        return;
    end
    
    % 获取所有编辑框
    edits = findobj(panel, 'Style', 'edit');
    for i = 1:length(edits)
        tag = get(edits(i), 'Tag');
        value_str = get(edits(i), 'String');
        
        try
            value = str2double(value_str);
            if ~isnan(value)
                % 保存到选项卡特定数据
                fig_data.tab_data{current_tab}.(tag) = value;
            end
        catch
            % 忽略转换错误
        end
    end
    
    % 获取所有复选框
    checkboxes = findobj(panel, 'Style', 'checkbox');
    for i = 1:length(checkboxes)
        tag = get(checkboxes(i), 'Tag');
        value = get(checkboxes(i), 'Value');
        fig_data.tab_data{current_tab}.(tag) = value;
    end
    
    set(fig, 'UserData', fig_data);
end

%% 从选项卡数据更新全局参数
function update_params_from_tab_data(fig)
    fig_data = get(fig, 'UserData');
    
    % 合并所有选项卡数据到全局参数
    for tab_idx = 1:9
        tab_data = fig_data.tab_data{tab_idx};
        fields = fieldnames(tab_data);
        
        for i = 1:length(fields)
            field_name = fields{i};
            field_value = tab_data.(field_name);
            
            % 更新全局参数
            fig_data.params = update_param_by_tag(fig_data.params, field_name, field_value);
        end
    end
    
    set(fig, 'UserData', fig_data);
end

%% 创建参数行（辅助函数） - 修改版，添加自动保存回调
function create_param_row(panel, label, value, unit, x, y, tag)
    % 标签
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', label, ...
              'Position', [x, y, 150, 25], ...
              'HorizontalAlignment', 'right', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    % 编辑框 - 添加回调自动保存
    uicontrol('Parent', panel, ...
              'Style', 'edit', ...
              'String', num2str(value), ...
              'Position', [x+160, y, 80, 25], ...
              'BackgroundColor', [1 1 1], ...
              'Tag', tag, ...
              'Callback', @(src,evt) on_edit_changed(ancestor(panel, 'figure'), tag));
    
    % 单位
    if ~isempty(unit)
        uicontrol('Parent', panel, ...
                  'Style', 'text', ...
                  'String', unit, ...
                  'Position', [x+250, y, 50, 25], ...
                  'HorizontalAlignment', 'left', ...
                  'BackgroundColor', [0.98 0.98 0.98]);
    end
end

%% 创建信息行（辅助函数）
function create_info_row(panel, label, value, x, y)
    % 标签
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', label, ...
              'Position', [x, y, 150, 25], ...
              'HorizontalAlignment', 'right', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    % 值
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', value, ...
              'Position', [x+160, y, 120, 25], ...
              'BackgroundColor', [1 1 1]);
end

%% 编辑框变化回调
function on_edit_changed(fig, tag)
    fig_data = get(fig, 'UserData');
    
    % 找到编辑框
    edit_obj = findobj(fig_data.content_panel, 'Tag', tag, 'Style', 'edit');
    if ~isempty(edit_obj)
        value_str = get(edit_obj, 'String');
        
        try
            value = str2double(value_str);
            if ~isnan(value)
                % 保存到当前选项卡数据
                current_tab = fig_data.current_tab;
                fig_data.tab_data{current_tab}.(tag) = value;
                
                % 更新全局参数
                fig_data.params = update_param_by_tag(fig_data.params, tag, value);
                set(fig, 'UserData', fig_data);
            end
        catch
            % 忽略错误
        end
    end
end

%% 辅助函数：获取字段值
function value = get_field_value(structure, field_name, default_value)
    if isfield(structure, field_name)
        value = structure.(field_name);
    else
        value = default_value;
    end
end

%% 1. 进近参数面板（修改版）
function create_approach_panel_simple(fig)
    fig_data = get(fig, 'UserData');
    panel = fig_data.content_panel;
    current_tab = fig_data.current_tab;
    
    % 获取当前选项卡数据
    if ~isempty(fig_data.tab_data{current_tab})
        tab_data = fig_data.tab_data{current_tab};
    else
        tab_data = get_tab1_defaults(fig_data.params);
        fig_data.tab_data{current_tab} = tab_data;
        set(fig, 'UserData', fig_data);
    end
    
    % 标题
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', '进近参数配置', ...
              'Position', [350, 320, 200, 25], ...
              'FontSize', 14, ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    % 创建参数编辑框
    y_pos = 280;
    spacing = 40;
    
    % 下滑道角度（从存储的数据加载）
    glide_slope = get_field_value(tab_data, 'glide_slope', fig_data.params.approach.glide_slope);
    create_param_row(panel, '下滑道角度:', glide_slope, '度', ...
                    100, y_pos, 'glide_slope');
    
    % 目标速度
    target_speed = get_field_value(tab_data, 'target_speed', fig_data.params.approach.target_speed);
    create_param_row(panel, '目标进近速度:', target_speed, 'm/s', ...
                    100, y_pos-spacing, 'target_speed');
    
    % FAF距离
    distance_FAF = get_field_value(tab_data, 'distance_FAF', fig_data.params.approach.distance_FAF);
    create_param_row(panel, 'FAF距跑道入口:', distance_FAF, 'm', ...
                    100, y_pos-2*spacing, 'distance_FAF');
    
    % FAF高度
    initial_alt = get_field_value(tab_data, 'initial_alt', fig_data.params.approach.initial_alt);
    create_param_row(panel, 'FAF点高度:', initial_alt, 'm', ...
                    100, y_pos-3*spacing, 'initial_alt');
    
    % 拉平开始高度
    flare_start = get_field_value(tab_data, 'flare_start', fig_data.params.approach.flare_start);
    create_param_row(panel, '拉平开始高度:', flare_start, 'm', ...
                    500, y_pos, 'flare_start');
    
    % 决断高度
    DH = get_field_value(tab_data, 'DH', fig_data.params.approach.DH);
    create_param_row(panel, '决断高度(DH):', DH, 'm', ...
                    500, y_pos-spacing, 'DH');
    
    % 接地区长度
    touchdown_zone = get_field_value(tab_data, 'touchdown_zone', fig_data.params.approach.touchdown_zone);
    create_param_row(panel, '接地区长度:', touchdown_zone, 'm', ...
                    500, y_pos-2*spacing, 'touchdown_zone');
    
    % 计算按钮
    uicontrol('Parent', panel, ...
              'Style', 'pushbutton', ...
              'String', '计算几何参数', ...
              'Position', [350, 50, 150, 30], ...
              'BackgroundColor', [0.3 0.6 0.9], ...
              'Callback', @(src,evt) calculate_approach_geometry_simple(fig));
end

%% 2. 飞机参数面板（修改版）
function create_uav_panel_simple(fig)
    fig_data = get(fig, 'UserData');
    panel = fig_data.content_panel;
    current_tab = fig_data.current_tab;
    
    % 获取当前选项卡数据
    if ~isempty(fig_data.tab_data{current_tab})
        tab_data = fig_data.tab_data{current_tab};
    else
        tab_data = get_tab2_defaults(fig_data.params);
        fig_data.tab_data{current_tab} = tab_data;
        set(fig, 'UserData', fig_data);
    end
    
    % 标题
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', '飞机基本参数', ...
              'Position', [350, 320, 200, 25], ...
              'FontSize', 14, ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    y_pos = 280;
    spacing = 40;
    
    % 质量（从存储的数据加载）
    mass = get_field_value(tab_data, 'mass', fig_data.params.UAV.mass);
    create_param_row(panel, '飞机质量:', mass, 'kg', ...
                    100, y_pos, 'mass');
    
    % 翼面积
    wing_area = get_field_value(tab_data, 'wing_area', fig_data.params.UAV.wing_area);
    create_param_row(panel, '机翼面积:', wing_area, 'm²', ...
                    100, y_pos-spacing, 'wing_area');
    
    % 最大推力
    max_thrust = get_field_value(tab_data, 'max_thrust', fig_data.params.UAV.max_thrust);
    create_param_row(panel, '最大推力:', max_thrust, 'N', ...
                    100, y_pos-2*spacing, 'max_thrust');
    
    % 发动机时间常数
    engine_time_constant = get_field_value(tab_data, 'engine_time_constant', fig_data.params.UAV.engine_time_constant);
    create_param_row(panel, '发动机时间常数:', engine_time_constant, 's', ...
                    100, y_pos-3*spacing, 'engine_time_constant');
    
    % 俯仰阻尼
    pitch_damping = get_field_value(tab_data, 'pitch_damping', fig_data.params.UAV.pitch_damping);
    create_param_row(panel, '俯仰阻尼:', pitch_damping, '', ...
                    500, y_pos, 'pitch_damping');
    
    % 展弦比
    aspect_ratio = get_field_value(tab_data, 'aspect_ratio', 8);
    create_param_row(panel, '机翼展弦比:', aspect_ratio, '', ...
                    500, y_pos-spacing, 'aspect_ratio');
    
    % 最大俯仰角速度
    max_pitch_rate = get_field_value(tab_data, 'max_pitch_rate', 4);
    create_param_row(panel, '最大俯仰角速度:', max_pitch_rate, '度/s', ...
                    500, y_pos-2*spacing, 'max_pitch_rate');
end

%% 3. 气动参数面板（修改版）
function create_aerodynamic_panel_simple(fig)
    fig_data = get(fig, 'UserData');
    panel = fig_data.content_panel;
    current_tab = fig_data.current_tab;
    
    % 获取当前选项卡数据
    if ~isempty(fig_data.tab_data{current_tab})
        tab_data = fig_data.tab_data{current_tab};
    else
        tab_data = get_tab3_defaults(fig_data.params);
        fig_data.tab_data{current_tab} = tab_data;
        set(fig, 'UserData', fig_data);
    end
    
    % 标题
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', '气动参数配置', ...
              'Position', [350, 320, 200, 25], ...
              'FontSize', 14, ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    y_pos = 280;
    spacing = 40;
    
    % 升力参数
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', '升力参数:', ...
              'Position', [50, y_pos+20, 100, 25], ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    % 零升力系数（从存储的数据加载）
    CL0 = get_field_value(tab_data, 'CL0', fig_data.params.UAV.CL0);
    create_param_row(panel, '零升力系数CL₀:', CL0, '', ...
                    50, y_pos-spacing, 'CL0');
    
    % 升力线斜率
    CL_alpha = get_field_value(tab_data, 'CL_alpha', fig_data.params.UAV.CL_alpha);
    create_param_row(panel, '升力线斜率CL_α:', CL_alpha, '/rad', ...
                    50, y_pos-2*spacing, 'CL_alpha');
    
    % 最大升力系数
    CL_max = get_field_value(tab_data, 'CL_max', 1.5);
    create_param_row(panel, '最大升力系数:', CL_max, '', ...
                    50, y_pos-3*spacing, 'CL_max');
    
    % 阻力参数
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', '阻力参数:', ...
              'Position', [350, y_pos+20, 100, 25], ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    % 零阻力系数
    CD0 = get_field_value(tab_data, 'CD0', fig_data.params.UAV.CD0);
    create_param_row(panel, '零阻力系数CD₀:', CD0, '', ...
                    350, y_pos-spacing, 'CD0');
    
    % 阻力系数alpha项
    CD_alpha = get_field_value(tab_data, 'CD_alpha', fig_data.params.UAV.CD_alpha);
    create_param_row(panel, '阻力系数CD_α:', CD_alpha, '/rad²', ...
                    350, y_pos-2*spacing, 'CD_alpha');
    
    % 奥斯瓦尔德效率因子
    oswald_efficiency = get_field_value(tab_data, 'oswald_efficiency', 0.85);
    create_param_row(panel, '奥斯瓦尔德效率因子:', oswald_efficiency, '', ...
                    350, y_pos-3*spacing, 'oswald_efficiency');
    
    % 性能参数
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', '性能估算:', ...
              'Position', [650, y_pos+20, 100, 25], ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    % 计算失速速度
    stall_speed = sqrt(2 * fig_data.params.UAV.mass * 9.81 / (1.225 * fig_data.params.UAV.wing_area * 1.3));
    create_info_row(panel, '失速速度估算:', sprintf('%.1f m/s', stall_speed), ...
                    650, y_pos-spacing);
    
    % 推重比
    TWR = fig_data.params.UAV.max_thrust / (fig_data.params.UAV.mass * 9.81);
    create_info_row(panel, '推重比(T/W):', sprintf('%.2f', TWR), ...
                    650, y_pos-2*spacing);
    
    % 翼载荷
    wing_loading = fig_data.params.UAV.mass * 9.81 / fig_data.params.UAV.wing_area;
    create_info_row(panel, '翼载荷:', sprintf('%.1f N/m²', wing_loading), ...
                    650, y_pos-3*spacing);
end

%% 4. 控制器参数面板（修改版）
function create_controller_panel_simple(fig)
    fig_data = get(fig, 'UserData');
    panel = fig_data.content_panel;
    current_tab = fig_data.current_tab;
    
    % 获取当前选项卡数据
    if ~isempty(fig_data.tab_data{current_tab})
        tab_data = fig_data.tab_data{current_tab};
    else
        tab_data = get_tab4_defaults(fig_data.params);
        fig_data.tab_data{current_tab} = tab_data;
        set(fig, 'UserData', fig_data);
    end
    
    % 标题
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', '控制器参数配置', ...
              'Position', [350, 320, 200, 25], ...
              'FontSize', 14, ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    y_pos = 280;
    spacing = 40;
    
    % 下滑道控制器（从存储的数据加载）
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', '下滑道控制器 (PID):', ...
              'Position', [50, y_pos+20, 200, 25], ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    gs_Kp = get_field_value(tab_data, 'gs_Kp', fig_data.params.ctrl.gs_Kp);
    create_param_row(panel, '比例增益 Kp:', gs_Kp, '', ...
                    50, y_pos-spacing, 'gs_Kp');
    
    gs_Ki = get_field_value(tab_data, 'gs_Ki', fig_data.params.ctrl.gs_Ki);
    create_param_row(panel, '积分增益 Ki:', gs_Ki, '', ...
                    50, y_pos-2*spacing, 'gs_Ki');
    
    gs_Kd = get_field_value(tab_data, 'gs_Kd', fig_data.params.ctrl.gs_Kd);
    create_param_row(panel, '微分增益 Kd:', gs_Kd, '', ...
                    50, y_pos-3*spacing, 'gs_Kd');
    
    % 速度控制器
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', '速度控制器 (PID):', ...
              'Position', [350, y_pos+20, 200, 25], ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    speed_Kp = get_field_value(tab_data, 'speed_Kp', fig_data.params.ctrl.speed_Kp);
    create_param_row(panel, '比例增益 Kp:', speed_Kp, '', ...
                    350, y_pos-spacing, 'speed_Kp');
    
    speed_Ki = get_field_value(tab_data, 'speed_Ki', fig_data.params.ctrl.speed_Ki);
    create_param_row(panel, '积分增益 Ki:', speed_Ki, '', ...
                    350, y_pos-2*spacing, 'speed_Ki');
    
    speed_Kd = get_field_value(tab_data, 'speed_Kd', fig_data.params.ctrl.speed_Kd);
    create_param_row(panel, '微分增益 Kd:', speed_Kd, '', ...
                    350, y_pos-3*spacing, 'speed_Kd');
    
    % 拉平控制器
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', '拉平控制器:', ...
              'Position', [650, y_pos+20, 200, 25], ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    flare_Kp = get_field_value(tab_data, 'flare_Kp', fig_data.params.ctrl.flare_Kp);
    create_param_row(panel, '比例增益 Kp:', flare_Kp, '', ...
                    650, y_pos-spacing, 'flare_Kp');
    
    flare_Ki = get_field_value(tab_data, 'flare_Ki', fig_data.params.ctrl.flare_Ki);
    create_param_row(panel, '积分增益 Ki:', flare_Ki, '', ...
                    650, y_pos-2*spacing, 'flare_Ki');
    
    target_sink_rate = get_field_value(tab_data, 'target_sink_rate', fig_data.params.ctrl.target_sink_rate);
    create_param_row(panel, '目标下降率:', target_sink_rate, 'm/s', ...
                    650, y_pos-3*spacing, 'target_sink_rate');
end

%% 5. 控制限制面板（修改版）
function create_limits_panel_simple(fig)
    fig_data = get(fig, 'UserData');
    panel = fig_data.content_panel;
    current_tab = fig_data.current_tab;
    
    % 获取当前选项卡数据
    if ~isempty(fig_data.tab_data{current_tab})
        tab_data = fig_data.tab_data{current_tab};
    else
        tab_data = get_tab5_defaults(fig_data.params);
        fig_data.tab_data{current_tab} = tab_data;
        set(fig, 'UserData', fig_data);
    end
    
    % 标题
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', '控制限制参数', ...
              'Position', [350, 320, 200, 25], ...
              'FontSize', 14, ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    y_pos = 280;
    spacing = 40;
    
    % 俯仰限制（从存储的数据加载）
    max_pitch = get_field_value(tab_data, 'max_pitch', fig_data.params.ctrl.max_pitch);
    create_param_row(panel, '最大俯仰角:', max_pitch, '度', ...
                    100, y_pos, 'max_pitch');
    
    min_pitch = get_field_value(tab_data, 'min_pitch', fig_data.params.ctrl.min_pitch);
    create_param_row(panel, '最小俯仰角:', min_pitch, '度', ...
                    100, y_pos-spacing, 'min_pitch');
    
    max_elevator = get_field_value(tab_data, 'max_elevator', fig_data.params.ctrl.max_elevator);
    create_param_row(panel, '最大升降舵偏角:', max_elevator, '', ...
                    100, y_pos-2*spacing, 'max_elevator');
    
    % 油门限制
    max_throttle = get_field_value(tab_data, 'max_throttle', fig_data.params.ctrl.max_throttle);
    create_param_row(panel, '最大油门:', max_throttle, '', ...
                    400, y_pos, 'max_throttle');
    
    min_throttle = get_field_value(tab_data, 'min_throttle', fig_data.params.ctrl.min_throttle);
    create_param_row(panel, '最小油门:', min_throttle, '', ...
                    400, y_pos-spacing, 'min_throttle');
    
    % 速率限制
    max_descent_rate = get_field_value(tab_data, 'max_descent_rate', fig_data.params.ctrl.max_descent_rate);
    create_param_row(panel, '最大下降率:', max_descent_rate, 'm/s', ...
                    700, y_pos, 'max_descent_rate');
    
    max_climb_rate = get_field_value(tab_data, 'max_climb_rate', fig_data.params.ctrl.max_climb_rate);
    create_param_row(panel, '最大爬升率:', max_climb_rate, 'm/s', ...
                    700, y_pos-spacing, 'max_climb_rate');
end

%% 6. 初始条件面板（修改版）
function create_initial_conditions_panel_simple(fig)
    fig_data = get(fig, 'UserData');
    panel = fig_data.content_panel;
    current_tab = fig_data.current_tab;
    
    % 获取当前选项卡数据
    if ~isempty(fig_data.tab_data{current_tab})
        tab_data = fig_data.tab_data{current_tab};
    else
        tab_data = get_tab6_defaults(fig_data.params);
        fig_data.tab_data{current_tab} = tab_data;
        set(fig, 'UserData', fig_data);
    end
    
    % 标题
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', '初始条件配置', ...
              'Position', [350, 320, 200, 25], ...
              'FontSize', 14, ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    y_pos = 280;
    spacing = 40;
    
    % 初始速度（从存储的数据加载）
    init_speed = get_field_value(tab_data, 'init_speed', fig_data.params.initial_conditions.speed);
    create_param_row(panel, '初始速度:', init_speed, 'm/s', ...
                    100, y_pos, 'init_speed');
    
    % 初始俯仰角
    init_pitch = get_field_value(tab_data, 'init_pitch', fig_data.params.initial_conditions.pitch);
    create_param_row(panel, '初始俯仰角:', init_pitch, '度', ...
                    100, y_pos-spacing, 'init_pitch');
    
    % 初始下降率
    init_descent_rate = get_field_value(tab_data, 'init_descent_rate', fig_data.params.initial_conditions.descent_rate);
    create_param_row(panel, '初始下降率:', init_descent_rate, 'm/s', ...
                    100, y_pos-2*spacing, 'init_descent_rate');
    
    % 初始迎角
    init_alpha = get_field_value(tab_data, 'init_alpha', fig_data.params.initial_conditions.alpha);
    create_param_row(panel, '初始迎角:', init_alpha, '度', ...
                    100, y_pos-3*spacing, 'init_alpha');
    
    % 初始距离
    init_distance = get_field_value(tab_data, 'init_distance', fig_data.params.approach.distance_FAF);
    create_param_row(panel, '初始距离:', init_distance, 'm', ...
                    500, y_pos, 'init_distance');
    
    % 初始高度
    init_altitude = get_field_value(tab_data, 'init_altitude', fig_data.params.approach.initial_alt);
    create_param_row(panel, '初始高度:', init_altitude, 'm', ...
                    500, y_pos-spacing, 'init_altitude');
    
    % 初始油门
    init_throttle = get_field_value(tab_data, 'init_throttle', 0.03);
    create_param_row(panel, '初始油门:', init_throttle, '', ...
                    500, y_pos-2*spacing, 'init_throttle');
    
    % 初始升降舵
    init_elevator = get_field_value(tab_data, 'init_elevator', 0);
    create_param_row(panel, '初始升降舵:', init_elevator, '', ...
                    500, y_pos-3*spacing, 'init_elevator');
    
    % 重置按钮
    uicontrol('Parent', panel, ...
              'Style', 'pushbutton', ...
              'String', '重置为理论值', ...
              'Position', [350, 50, 150, 30], ...
              'BackgroundColor', [0.3 0.6 0.9], ...
              'Callback', @(src,evt) reset_to_theoretical_simple(fig));
end

%% 7. 仿真设置面板（修改版）
function create_simulation_panel_simple(fig)
    fig_data = get(fig, 'UserData');
    panel = fig_data.content_panel;
    current_tab = fig_data.current_tab;
    
    % 获取当前选项卡数据
    if ~isempty(fig_data.tab_data{current_tab})
        tab_data = fig_data.tab_data{current_tab};
    else
        tab_data = get_tab7_defaults(fig_data.params);
        fig_data.tab_data{current_tab} = tab_data;
        set(fig, 'UserData', fig_data);
    end
    
    % 标题
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', '仿真设置', ...
              'Position', [350, 320, 200, 25], ...
              'FontSize', 14, ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    y_pos = 280;
    spacing = 40;
    
    % 仿真步长（从存储的数据加载）
    dt = get_field_value(tab_data, 'dt', fig_data.params.sim_params.dt);
    create_param_row(panel, '仿真步长:', dt, 's', ...
                    100, y_pos, 'dt');
    
    % 总仿真时间
    T = get_field_value(tab_data, 'T', fig_data.params.sim_params.T);
    create_param_row(panel, '总仿真时间:', T, 's', ...
                    100, y_pos-spacing, 'T');
    
    % 仿真选项
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', '仿真选项:', ...
              'Position', [400, y_pos-100, 100, 25], ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    % 启用风场
    enable_wind_sim = get_field_value(tab_data, 'enable_wind_sim', fig_data.params.wind_params.enable);
    uicontrol('Parent', panel, ...
              'Style', 'checkbox', ...
              'String', '启用风场扰动', ...
              'Value', enable_wind_sim, ...
              'Position', [400, y_pos-140, 150, 25], ...
              'BackgroundColor', [0.98 0.98 0.98], ...
              'Tag', 'enable_wind_sim', ...
              'Callback', @(src,evt) on_checkbox_changed(ancestor(panel, 'figure'), 'enable_wind_sim'));
    
    % 启用传感器噪声
    enable_noise = get_field_value(tab_data, 'enable_noise', 0);
    uicontrol('Parent', panel, ...
              'Style', 'checkbox', ...
              'String', '启用传感器噪声', ...
              'Value', enable_noise, ...
              'Position', [400, y_pos-180, 150, 25], ...
              'BackgroundColor', [0.98 0.98 0.98], ...
              'Tag', 'enable_noise', ...
              'Callback', @(src,evt) on_checkbox_changed(ancestor(panel, 'figure'), 'enable_noise'));
    
    % 启用执行器限制
    enable_actuator_limits = get_field_value(tab_data, 'enable_actuator_limits', 1);
    uicontrol('Parent', panel, ...
              'Style', 'checkbox', ...
              'String', '启用执行器限制', ...
              'Value', enable_actuator_limits, ...
              'Position', [400, y_pos-220, 150, 25], ...
              'BackgroundColor', [0.98 0.98 0.98], ...
              'Tag', 'enable_actuator_limits', ...
              'Callback', @(src,evt) on_checkbox_changed(ancestor(panel, 'figure'), 'enable_actuator_limits'));
    
    % 启用复飞逻辑
    enable_goaround = get_field_value(tab_data, 'enable_goaround', 1);
    uicontrol('Parent', panel, ...
              'Style', 'checkbox', ...
              'String', '启用复飞逻辑', ...
              'Value', enable_goaround, ...
              'Position', [600, y_pos-140, 150, 25], ...
              'BackgroundColor', [0.98 0.98 0.98], ...
              'Tag', 'enable_goaround', ...
              'Callback', @(src,evt) on_checkbox_changed(ancestor(panel, 'figure'), 'enable_goaround'));
end

%% 8. 风场参数面板（修改版）
function create_wind_panel_simple(fig)
    fig_data = get(fig, 'UserData');
    panel = fig_data.content_panel;
    current_tab = fig_data.current_tab;
    
    % 获取当前选项卡数据
    if ~isempty(fig_data.tab_data{current_tab})
        tab_data = fig_data.tab_data{current_tab};
    else
        tab_data = get_tab8_defaults(fig_data.params);
        fig_data.tab_data{current_tab} = tab_data;
        set(fig, 'UserData', fig_data);
    end
    
    % 标题
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', '风场参数配置', ...
              'Position', [350, 320, 200, 25], ...
              'FontSize', 14, ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    y_pos = 280;
    spacing = 40;
    
    % 启用风场（从存储的数据加载）
    enable_wind = get_field_value(tab_data, 'enable_wind', fig_data.params.wind_params.enable);
    uicontrol('Parent', panel, ...
              'Style', 'checkbox', ...
              'String', '启用风场', ...
              'Value', enable_wind, ...
              'Position', [100, y_pos, 150, 25], ...
              'BackgroundColor', [0.98 0.98 0.98], ...
              'Tag', 'enable_wind', ...
              'Callback', @(src,evt) on_checkbox_changed(ancestor(panel, 'figure'), 'enable_wind'));
    
    wind_speed = get_field_value(tab_data, 'wind_speed', fig_data.params.wind_params.speed);
    create_param_row(panel, '风速:', wind_speed, 'm/s', ...
                    100, y_pos-spacing, 'wind_speed');
    
    wind_direction = get_field_value(tab_data, 'wind_direction', fig_data.params.wind_params.direction);
    create_param_row(panel, '风向:', wind_direction, '度', ...
                    100, y_pos-2*spacing, 'wind_direction');
    
    % 说明文本
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', '注意：风向指风吹来的方向，正北为0°，顺时针增加', ...
              'Position', [100, y_pos-120, 400, 25], ...
              'FontSize', 10, ...
              'ForegroundColor', [0.5 0.5 0.5], ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    % 常用风向按钮
    uicontrol('Parent', panel, ...
              'Style', 'pushbutton', ...
              'String', '设置顶风(270°)', ...
              'Position', [350, y_pos-80, 120, 25], ...
              'BackgroundColor', [0.8 0.9 1.0], ...
              'Callback', @(src,evt) set_wind_direction(fig, 270));
    
    uicontrol('Parent', panel, ...
              'Style', 'pushbutton', ...
              'String', '设置顺风(90°)', ...
              'Position', [500, y_pos-80, 120, 25], ...
              'BackgroundColor', [0.9 0.9 0.8], ...
              'Callback', @(src,evt) set_wind_direction(fig, 90));
    
    uicontrol('Parent', panel, ...
              'Style', 'pushbutton', ...
              'String', '设置侧风(180°)', ...
              'Position', [650, y_pos-80, 120, 25], ...
              'BackgroundColor', [1.0 0.9 0.8], ...
              'Callback', @(src,evt) set_wind_direction(fig, 180));
    
    % 预览按钮
    uicontrol('Parent', panel, ...
              'Style', 'pushbutton', ...
              'String', '预览风场', ...
              'Position', [350, 50, 120, 30], ...
              'BackgroundColor', [0.3 0.6 0.9], ...
              'Callback', @(src,evt) preview_wind_simple(fig));
    
    % 测试按钮
    uicontrol('Parent', panel, ...
              'Style', 'pushbutton', ...
              'String', '测试风效应', ...
              'Position', [500, 50, 120, 30], ...
              'BackgroundColor', [0.9 0.6 0.3], ...
              'Callback', @(src,evt) test_wind_effect_simple(fig));
end

%% 9. 高级参数面板（修改版）
function create_advanced_panel_simple(fig)
    fig_data = get(fig, 'UserData');
    panel = fig_data.content_panel;
    current_tab = fig_data.current_tab;
    
    % 获取当前选项卡数据
    if ~isempty(fig_data.tab_data{current_tab})
        tab_data = fig_data.tab_data{current_tab};
    else
        tab_data = get_tab9_defaults(fig_data.params);
        fig_data.tab_data{current_tab} = tab_data;
        set(fig, 'UserData', fig_data);
    end
    
    % 标题
    uicontrol('Parent', panel, ...
              'Style', 'text', ...
              'String', '高级参数配置', ...
              'Position', [350, 320, 200, 25], ...
              'FontSize', 14, ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.98 0.98 0.98]);
    
    y_pos = 280;
    spacing = 40;
    
    % 大气参数（从存储的数据加载）
    air_density = get_field_value(tab_data, 'air_density', fig_data.params.atmosphere.rho);
    create_param_row(panel, '空气密度:', air_density, 'kg/m³', ...
                    100, y_pos, 'air_density');
    
    gravity = get_field_value(tab_data, 'gravity', fig_data.params.atmosphere.g);
    create_param_row(panel, '重力加速度:', gravity, 'm/s²', ...
                    100, y_pos-spacing, 'gravity');
    
    % 数据管理按钮
    uicontrol('Parent', panel, ...
              'Style', 'pushbutton', ...
              'String', '保存参数文件', ...
              'Position', [350, 150, 150, 30], ...
              'BackgroundColor', [0.3 0.6 0.9], ...
              'Callback', @(src,evt) save_configuration_simple(fig));
    
    uicontrol('Parent', panel, ...
              'Style', 'pushbutton', ...
              'String', '加载参数文件', ...
              'Position', [350, 100, 150, 30], ...
              'BackgroundColor', [0.4 0.7 0.4], ...
              'Callback', @(src,evt) load_configuration_simple(fig));
    
    uicontrol('Parent', panel, ...
              'Style', 'pushbutton', ...
              'String', '导出为MAT文件', ...
              'Position', [350, 50, 150, 30], ...
              'BackgroundColor', [0.9 0.6 0.3], ...
              'Callback', @(src,evt) export_mat_file_simple(fig));
end

%% 创建底部按钮
function create_bottom_buttons(fig)
    button_panel = uipanel('Parent', fig, ...
                          'Title', '', ...
                          'Position', [0.05, 0.05, 0.9, 0.08], ...
                          'BackgroundColor', [0.95 0.95 0.95], ...
                          'BorderType', 'none');
    
    % 开始仿真按钮
    uicontrol('Parent', button_panel, ...
              'Style', 'pushbutton', ...
              'String', '▶ 开始仿真', ...
              'Position', [700, 10, 120, 40], ...
              'FontSize', 12, ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.3 0.7 0.3], ...
              'Callback', @(src,evt) start_simulation_simple(fig));
    
    % 取消按钮
    uicontrol('Parent', button_panel, ...
              'Style', 'pushbutton', ...
              'String', '✗ 取消', ...
              'Position', [550, 10, 120, 40], ...
              'FontSize', 12, ...
              'BackgroundColor', [0.9 0.3 0.3], ...
              'Callback', @(src,evt) cancel_simulation_simple(fig));
    
    % 重置按钮
    uicontrol('Parent', button_panel, ...
              'Style', 'pushbutton', ...
              'String', '🔄 重置为默认', ...
              'Position', [100, 10, 120, 40], ...
              'FontSize', 10, ...
              'BackgroundColor', [0.7 0.7 0.7], ...
              'Callback', @(src,evt) reset_to_default_simple(fig));
end

%% 复选框变化回调
function on_checkbox_changed(fig, tag)
    fig_data = get(fig, 'UserData');
    
    % 找到复选框
    checkbox_obj = findobj(fig_data.content_panel, 'Tag', tag, 'Style', 'checkbox');
    if ~isempty(checkbox_obj)
        value = get(checkbox_obj, 'Value');
        
        % 保存到当前选项卡数据
        current_tab = fig_data.current_tab;
        fig_data.tab_data{current_tab}.(tag) = value;
        
        % 更新全局参数
        fig_data.params = update_param_by_tag(fig_data.params, tag, value);
        set(fig, 'UserData', fig_data);
    end
end

%% 选项卡默认值函数
function tab_data = get_tab1_defaults(params)
    tab_data = struct();
    tab_data.glide_slope = params.approach.glide_slope;
    tab_data.target_speed = params.approach.target_speed;
    tab_data.distance_FAF = params.approach.distance_FAF;
    tab_data.initial_alt = params.approach.initial_alt;
    tab_data.flare_start = params.approach.flare_start;
    tab_data.DH = params.approach.DH;
    tab_data.touchdown_zone = params.approach.touchdown_zone;
end

function tab_data = get_tab2_defaults(params)
    tab_data = struct();
    tab_data.mass = params.UAV.mass;
    tab_data.wing_area = params.UAV.wing_area;
    tab_data.max_thrust = params.UAV.max_thrust;
    tab_data.engine_time_constant = params.UAV.engine_time_constant;
    tab_data.pitch_damping = params.UAV.pitch_damping;
    tab_data.aspect_ratio = 8;
    tab_data.max_pitch_rate = 4;
end

function tab_data = get_tab3_defaults(params)
    tab_data = struct();
    tab_data.CL0 = params.UAV.CL0;
    tab_data.CL_alpha = params.UAV.CL_alpha;
    tab_data.CL_max = 1.5;
    tab_data.CD0 = params.UAV.CD0;
    tab_data.CD_alpha = params.UAV.CD_alpha;
    tab_data.oswald_efficiency = 0.85;
end

function tab_data = get_tab4_defaults(params)
    tab_data = struct();
    tab_data.gs_Kp = params.ctrl.gs_Kp;
    tab_data.gs_Ki = params.ctrl.gs_Ki;
    tab_data.gs_Kd = params.ctrl.gs_Kd;
    tab_data.speed_Kp = params.ctrl.speed_Kp;
    tab_data.speed_Ki = params.ctrl.speed_Ki;
    tab_data.speed_Kd = params.ctrl.speed_Kd;
    tab_data.flare_Kp = params.ctrl.flare_Kp;
    tab_data.flare_Ki = params.ctrl.flare_Ki;
    tab_data.target_sink_rate = params.ctrl.target_sink_rate;
end

function tab_data = get_tab5_defaults(params)
    tab_data = struct();
    tab_data.max_pitch = params.ctrl.max_pitch;
    tab_data.min_pitch = params.ctrl.min_pitch;
    tab_data.max_elevator = params.ctrl.max_elevator;
    tab_data.max_throttle = params.ctrl.max_throttle;
    tab_data.min_throttle = params.ctrl.min_throttle;
    tab_data.max_descent_rate = params.ctrl.max_descent_rate;
    tab_data.max_climb_rate = params.ctrl.max_climb_rate;
end

function tab_data = get_tab6_defaults(params)
    tab_data = struct();
    tab_data.init_speed = params.initial_conditions.speed;
    tab_data.init_pitch = params.initial_conditions.pitch;
    tab_data.init_descent_rate = params.initial_conditions.descent_rate;
    tab_data.init_alpha = params.initial_conditions.alpha;
    tab_data.init_distance = params.approach.distance_FAF;
    tab_data.init_altitude = params.approach.initial_alt;
    tab_data.init_throttle = 0.03;
    tab_data.init_elevator = 0;
end

function tab_data = get_tab7_defaults(params)
    tab_data = struct();
    tab_data.dt = params.sim_params.dt;
    tab_data.T = params.sim_params.T;
    tab_data.enable_wind_sim = params.wind_params.enable;
    tab_data.enable_noise = 0;
    tab_data.enable_actuator_limits = 1;
    tab_data.enable_goaround = 1;
end

function tab_data = get_tab8_defaults(params)
    tab_data = struct();
    tab_data.enable_wind = params.wind_params.enable;
    tab_data.wind_speed = params.wind_params.speed;
    tab_data.wind_direction = params.wind_params.direction;
end

function tab_data = get_tab9_defaults(params)
    tab_data = struct();
    tab_data.air_density = params.atmosphere.rho;
    tab_data.gravity = params.atmosphere.g;
end

%% 回调函数
function start_simulation_simple(fig)
    % 确保保存当前选项卡数据
    save_current_tab_data(fig);
    
    % 更新全局参数
    update_params_from_tab_data(fig);
    
    fig_data = get(fig, 'UserData');
    fig_data.continue_sim = true;
    set(fig, 'UserData', fig_data);
    
    uiresume(fig);
end

function cancel_simulation_simple(fig)
    fig_data = get(fig, 'UserData');
    fig_data.continue_sim = false;
    set(fig, 'UserData', fig_data);
    
    uiresume(fig);
end

function reset_to_default_simple(fig)
    fig_data = get(fig, 'UserData');
    fig_data.params = get_default_parameters_gui(); % 使用独立函数
    
    % 重新初始化选项卡数据
    fig_data = init_all_tabs_data(fig);
    set(fig, 'UserData', fig_data);
    
    % 刷新当前面板
    current_tab = fig_data.current_tab;
    switch_tab_callback([], [], current_tab);
end

function calculate_approach_geometry_simple(fig)
    fig_data = get(fig, 'UserData');
    
    % 先收集当前参数
    save_current_tab_data(fig);
    update_params_from_tab_data(fig);
    fig_data = get(fig, 'UserData');
    params = fig_data.params;
    
    % 自动调整几何参数
    distance_from_threshold_to_flare = params.approach.flare_start / tand(params.approach.glide_slope);
    params.approach.initial_alt = params.approach.flare_start + ...
        (params.approach.distance_FAF - distance_from_threshold_to_flare) * tand(params.approach.glide_slope);
    
    % 更新初始条件
    params.initial_conditions.descent_rate = -params.approach.target_speed * sind(params.approach.glide_slope) * 0.9;
    
    fig_data.params = params;
    
    % 更新选项卡数据
    current_tab = fig_data.current_tab;
    fig_data.tab_data{current_tab}.initial_alt = params.approach.initial_alt;
    fig_data.tab_data{current_tab}.init_altitude = params.approach.initial_alt;
    fig_data.tab_data{6}.init_descent_rate = params.initial_conditions.descent_rate; % 第6个是初始条件选项卡
    
    set(fig, 'UserData', fig_data);
    
    % 刷新显示
    switch_tab_callback([], [], current_tab);
    
    msgbox(sprintf('已自动调整FAF高度为 %.1f m', params.approach.initial_alt), '几何调整完成', 'help');
end

function reset_to_theoretical_simple(fig)
    fig_data = get(fig, 'UserData');
    
    % 先收集当前参数
    save_current_tab_data(fig);
    update_params_from_tab_data(fig);
    fig_data = get(fig, 'UserData');
    params = fig_data.params;
    
    % 计算理论初始条件
    theoretical_descent = -params.approach.target_speed * sind(params.approach.glide_slope);
    
    params.initial_conditions.speed = params.approach.target_speed * 0.95;
    params.initial_conditions.pitch = 3.0;
    params.initial_conditions.descent_rate = theoretical_descent * 0.9;
    params.initial_conditions.alpha = 6.0;
    
    fig_data.params = params;
    
    % 更新选项卡数据
    fig_data.tab_data{6}.init_speed = params.initial_conditions.speed;
    fig_data.tab_data{6}.init_pitch = params.initial_conditions.pitch;
    fig_data.tab_data{6}.init_descent_rate = params.initial_conditions.descent_rate;
    fig_data.tab_data{6}.init_alpha = params.initial_conditions.alpha;
    
    set(fig, 'UserData', fig_data);
    
    % 刷新显示
    current_tab = fig_data.current_tab;
    switch_tab_callback([], [], current_tab);
    
    msgbox('已重置为理论初始条件', '重置完成', 'help');
end

%% 风场相关函数（修正版）
function set_wind_direction(fig, direction)
    fig_data = get(fig, 'UserData');
    
    % 更新选项卡数据
    current_tab = fig_data.current_tab;
    fig_data.tab_data{current_tab}.wind_direction = direction;
    fig_data.tab_data{current_tab}.enable_wind = true;
    
    % 更新全局参数
    fig_data.params.wind_params.direction = direction;
    fig_data.params.wind_params.enable = true;
    
    set(fig, 'UserData', fig_data);
    
    % 更新界面显示
    wind_dir_edit = findobj(fig_data.content_panel, 'Tag', 'wind_direction');
    wind_checkbox = findobj(fig_data.content_panel, 'Tag', 'enable_wind');
    
    if ~isempty(wind_dir_edit)
        set(wind_dir_edit, 'String', num2str(direction));
    end
    if ~isempty(wind_checkbox)
        set(wind_checkbox, 'Value', 1);
    end
    
    % 计算风类型显示
    approach_heading = 270;  % 跑道方向向西
    relative_angle = direction - approach_heading;
    headwind = cosd(relative_angle);  % 归一化的顶风分量
    
    if headwind > 0
        wind_type_str = '顶风';
        wind_effect_str = '吹来的方向';
    elseif headwind < 0
        wind_type_str = '顺风';
        wind_effect_str = '吹向的方向';
    else
        wind_type_str = '侧风';
        wind_effect_str = '吹来的方向';
    end
    
    msgbox(sprintf('风向已设置为 %.0f°\n%s\n（%s）', ...
        direction, wind_type_str, wind_effect_str), '风向设置', 'help');
end

function preview_wind_simple(fig)
    fig_data = get(fig, 'UserData');
    
    % 确保参数是最新的
    save_current_tab_data(fig);
    update_params_from_tab_data(fig);
    fig_data = get(fig, 'UserData');
    params = fig_data.params;
    
    if params.wind_params.enable
        wind_speed = params.wind_params.speed;
        wind_dir = params.wind_params.direction;
        
        h_fig = figure('Name', '风场预览', 'NumberTitle', 'off', ...
            'Position', [400, 200, 800, 500]);
        
        % 计算风分量
        approach_heading = 270;  % 跑道方向向西
        relative_angle = wind_dir - approach_heading;
        headwind = wind_speed * cosd(relative_angle);
        crosswind = wind_speed * sind(relative_angle);
        
        % 修正：正确显示风类型
        if headwind > 0
            wind_type_str = '顶风';
        else
            wind_type_str = '顺风';
        end
        
        % 第1个子图：风场极坐标图
        subplot(2,1,1);
        
        % 创建极坐标图
        polaraxes;
        hold on;
        
        % 绘制风向量
        wind_dir_rad = deg2rad(wind_dir);
        polarplot([0 wind_dir_rad], [0 wind_speed], 'r-', 'LineWidth', 3);
        
        % 绘制参考圆
        theta = linspace(0, 2*pi, 100);
        r = wind_speed * 0.5 * ones(size(theta));
        polarplot(theta, r, 'b--');
        
        % 标记跑道方向（270度，向西）
        runway_dir = deg2rad(270);
        polarplot([0 runway_dir], [0 wind_speed], 'g-', 'LineWidth', 2);
        
        title(sprintf('风场极坐标图\n风速: %.1f m/s, 风向: %.0f°', wind_speed, wind_dir));
        grid on;
        legend('风向（风吹来的方向）', '参考圆', '跑道方向（270°）', 'Location', 'best');
        
        subplot(2,1,2);
        
        % 创建简单的风分量图
        bar(1:2, [abs(headwind), abs(crosswind)], 'FaceColor', [0.2 0.6 0.8]);
        set(gca, 'XTick', 1:2, 'XTickLabel', {sprintf('%s分量', wind_type_str), '侧风分量'});
        xlabel('风分量类型');
        ylabel('风速 (m/s)');
        title(sprintf('风分量: %s=%.1f m/s, 侧风=%.1f m/s', wind_type_str, abs(headwind), crosswind));
        grid on;
        
        % 添加数值标签
        text(1, abs(headwind), sprintf('%.1f', abs(headwind)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 10);
        text(2, abs(crosswind), sprintf('%.1f', abs(crosswind)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 10);
        
        % 添加风向信息
        if headwind > 0
            wind_effect = '顶风（减小地速，延长进近距离）';
        else
            wind_effect = '顺风（增加地速，缩短进近距离）';
        end
        
        annotation('textbox', [0.02, 0.02, 0.96, 0.1], ...
            'String', sprintf('风向 %.0f° | 风速 %.1f m/s | 跑道方向 270° (向西) | %s', ...
                wind_dir, wind_speed, wind_effect), ...
            'BackgroundColor', [0.9 0.9 0.9], ...
            'EdgeColor', 'none', ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 10);
        
    else
        msgbox('请先启用风场以预览', '风场未启用', 'warn');
    end
end

function test_wind_effect_simple(fig)
    fig_data = get(fig, 'UserData');
    
    % 确保参数是最新的
    save_current_tab_data(fig);
    update_params_from_tab_data(fig);
    fig_data = get(fig, 'UserData');
    params = fig_data.params;
    
    if params.wind_params.enable
        % 显示详细风场信息
        wind_speed = params.wind_params.speed;
        wind_dir = params.wind_params.direction;
        
        % 计算对进近的影响
        approach_heading = 270;  % 假设向西进近
        aircraft_heading = approach_heading;
        
        % 计算风与飞机航向的相对角度
        relative_angle = wind_dir - aircraft_heading;
        headwind = wind_speed * cosd(relative_angle);
        crosswind = wind_speed * sind(relative_angle);
        
        % 修正：正确显示风类型
        if headwind > 0
            wind_type_str = '顶风';
        else
            wind_type_str = '顺风';
        end
        
        % 显示信息
        msg = sprintf('风场配置分析:\n');
        msg = [msg sprintf('---------------------------------\n')];
        msg = [msg sprintf('风速: %.1f m/s\n', wind_speed)];
        msg = [msg sprintf('风向: %.0f° (风吹来的方向)\n', wind_dir)];
        msg = [msg sprintf('跑道方向: %.0f° (向西)\n', approach_heading)];
        msg = [msg sprintf('相对角度: %.0f°\n', mod(relative_angle+180, 360)-180)];
        msg = [msg sprintf('%s分量: %.2f m/s\n', wind_type_str, abs(headwind))];
        msg = [msg sprintf('侧风分量: %.2f m/s\n', crosswind)];
        msg = [msg sprintf('---------------------------------\n')];
        
        % 显示风对性能的影响
        theoretical_sink = -params.approach.target_speed * sind(params.approach.glide_slope);
        theoretical_ground_speed = params.approach.target_speed - headwind;
        
        if headwind > 2
            msg = [msg sprintf('效果分析:\n')];
            msg = [msg sprintf('  • %s增加指示空速\n', wind_type_str)];
            msg = [msg sprintf('  • 减小地速，延长进近距离\n')];
            msg = [msg sprintf('  • 理论地速: %.1f m/s (减小%.1f%%)\n', ...
                theoretical_ground_speed, abs(headwind)/params.approach.target_speed*100)];
            msg = [msg sprintf('  • 建议: 适当减小油门，增加俯仰角\n')];
        elseif headwind < -2
            msg = [msg sprintf('效果分析:\n')];
            msg = [msg sprintf('  • %s减小指示空速\n', wind_type_str)];
            msg = [msg sprintf('  • 增加地速，缩短进近距离\n')];
            msg = [msg sprintf('  • 理论地速: %.1f m/s (增加%.1f%%)\n', ...
                theoretical_ground_speed, abs(headwind)/params.approach.target_speed*100)];
            msg = [msg sprintf('  • 建议: 适当增加油门，减小俯仰角\n')];
        elseif abs(crosswind) > 2
            msg = [msg sprintf('效果分析:\n')];
            msg = [msg sprintf('  • 主要侧风分量\n')];
            msg = [msg sprintf('  • 可能引起航向偏差\n')];
            msg = [msg sprintf('  • 建议: 需要侧滑或蟹形进场\n')];
        else
            msg = [msg sprintf('效果分析:\n')];
            msg = [msg sprintf('  • 风影响较小\n')];
            msg = [msg sprintf('  • 正常进近即可\n')];
        end
        
        % 计算对下降率的影响
        if abs(headwind) > 1
            effect_on_sink = theoretical_sink * (params.approach.target_speed / theoretical_ground_speed);
            msg = [msg sprintf('---------------------------------\n')];
            msg = [msg sprintf('性能影响估算:\n')];
            msg = [msg sprintf('  理论下降率: %.2f m/s\n', theoretical_sink)];
            msg = [msg sprintf('  受风影响下降率: %.2f m/s\n', effect_on_sink)];
            msg = [msg sprintf('  变化: %.1f%%\n', (effect_on_sink/theoretical_sink-1)*100)];
            msg = [msg sprintf('  理论进近距离: %.0f m\n', params.approach.distance_FAF)];
            msg = [msg sprintf('  受风影响距离: %.0f m\n', ...
                params.approach.distance_FAF * (params.approach.target_speed / theoretical_ground_speed))];
        end
        
        msgbox(msg, '风场效应分析', 'help');
    else
        msgbox('请先启用风场', '风场未启用', 'warn');
    end
end

function save_configuration_simple(fig)
    fig_data = get(fig, 'UserData');
    
    [filename, pathname] = uiputfile('*.mat', '保存仿真配置', 'sim_config.mat');
    
    if filename ~= 0
        fullpath = fullfile(pathname, filename);
        
        % 确保保存当前数据
        save_current_tab_data(fig);
        update_params_from_tab_data(fig);
        fig_data = get(fig, 'UserData');
        
        % 保存参数
        params = fig_data.params;
        save(fullpath, 'params');
        
        msgbox(sprintf('配置已保存到: %s', fullpath), '保存成功', 'help');
    end
end

function load_configuration_simple(fig)
    [filename, pathname] = uigetfile('*.mat', '加载仿真配置');
    
    if filename ~= 0
        fullpath = fullfile(pathname, filename);
        
        try
            loaded_data = load(fullpath);
            if isfield(loaded_data, 'params')
                params = loaded_data.params;
                
                fig_data = get(fig, 'UserData');
                fig_data.params = params;
                set(fig, 'UserData', fig_data);
                
                % 重新初始化选项卡数据
                fig_data = init_all_tabs_data(fig);
                set(fig, 'UserData', fig_data);
                
                % 刷新当前面板
                current_tab = fig_data.current_tab;
                switch_tab_callback([], [], current_tab);
                
                msgbox(sprintf('配置已从 %s 加载', filename), '加载成功', 'help');
            end
        catch
            errordlg('加载配置文件失败，请检查文件格式！', '加载错误');
        end
    end
end

function export_mat_file_simple(fig)
    fig_data = get(fig, 'UserData');
    
    [filename, pathname] = uiputfile('*.mat', '导出为MAT文件', 'simulation_params.mat');
    
    if filename ~= 0
        fullpath = fullfile(pathname, filename);
        
        % 确保保存当前数据
        save_current_tab_data(fig);
        update_params_from_tab_data(fig);
        fig_data = get(fig, 'UserData');
        
        % 导出参数
        params = fig_data.params;
        save(fullpath, 'params');
        
        msgbox(sprintf('参数已导出到: %s', fullpath), '导出成功', 'help');
    end
end

%% 更新参数函数
function params = update_param_by_tag(params, tag, value)
    % 根据标签更新参数
    
    % 进近参数
    switch tag
        case 'glide_slope'
            params.approach.glide_slope = value;
        case 'target_speed'
            params.approach.target_speed = value;
        case 'distance_FAF'
            params.approach.distance_FAF = value;
        case 'initial_alt'
            params.approach.initial_alt = value;
        case 'flare_start'
            params.approach.flare_start = value;
        case 'DH'
            params.approach.DH = value;
        case 'touchdown_zone'
            params.approach.touchdown_zone = value;
            
        % 飞机参数
        case 'mass'
            params.UAV.mass = value;
        case 'wing_area'
            params.UAV.wing_area = value;
        case 'max_thrust'
            params.UAV.max_thrust = value;
        case 'engine_time_constant'
            params.UAV.engine_time_constant = value;
        case 'pitch_damping'
            params.UAV.pitch_damping = value;
        case 'aspect_ratio'
            if ~isfield(params.UAV, 'aspect_ratio')
                params.UAV.aspect_ratio = value;
            else
                params.UAV.aspect_ratio = value;
            end
        case 'max_pitch_rate'
            if ~isfield(params.UAV, 'max_pitch_rate')
                params.UAV.max_pitch_rate = value;
            else
                params.UAV.max_pitch_rate = value;
            end
            
        % 气动参数
        case 'CL0'
            params.UAV.CL0 = value;
        case 'CL_alpha'
            params.UAV.CL_alpha = value;
        case 'CL_max'
            if ~isfield(params.UAV, 'CL_max')
                params.UAV.CL_max = value;
            else
                params.UAV.CL_max = value;
            end
        case 'CD0'
            params.UAV.CD0 = value;
        case 'CD_alpha'
            params.UAV.CD_alpha = value;
        case 'oswald_efficiency'
            if ~isfield(params.UAV, 'oswald_efficiency')
                params.UAV.oswald_efficiency = value;
            else
                params.UAV.oswald_efficiency = value;
            end
            
        % 控制器参数
        case 'gs_Kp'
            params.ctrl.gs_Kp = value;
        case 'gs_Ki'
            params.ctrl.gs_Ki = value;
        case 'gs_Kd'
            params.ctrl.gs_Kd = value;
        case 'speed_Kp'
            params.ctrl.speed_Kp = value;
        case 'speed_Ki'
            params.ctrl.speed_Ki = value;
        case 'speed_Kd'
            params.ctrl.speed_Kd = value;
        case 'flare_Kp'
            params.ctrl.flare_Kp = value;
        case 'flare_Ki'
            params.ctrl.flare_Ki = value;
        case 'target_sink_rate'
            params.ctrl.target_sink_rate = value;
            
        % 控制限制
        case 'max_pitch'
            params.ctrl.max_pitch = value;
        case 'min_pitch'
            params.ctrl.min_pitch = value;
        case 'max_elevator'
            params.ctrl.max_elevator = value;
        case 'max_throttle'
            params.ctrl.max_throttle = value;
        case 'min_throttle'
            params.ctrl.min_throttle = value;
        case 'max_descent_rate'
            params.ctrl.max_descent_rate = value;
        case 'max_climb_rate'
            params.ctrl.max_climb_rate = value;
            
        % 初始条件
        case 'init_speed'
            params.initial_conditions.speed = value;
        case 'init_pitch'
            params.initial_conditions.pitch = value;
        case 'init_descent_rate'
            params.initial_conditions.descent_rate = value;
        case 'init_alpha'
            params.initial_conditions.alpha = value;
        case 'init_throttle'
            if ~isfield(params.initial_conditions, 'throttle')
                params.initial_conditions.throttle = value;
            else
                params.initial_conditions.throttle = value;
            end
        case 'init_elevator'
            if ~isfield(params.initial_conditions, 'elevator')
                params.initial_conditions.elevator = value;
            else
                params.initial_conditions.elevator = value;
            end
        case 'init_distance'
            % 这个值应该与distance_FAF同步
            params.approach.distance_FAF = value;
        case 'init_altitude'
            % 这个值应该与initial_alt同步
            params.approach.initial_alt = value;
            
        % 仿真设置
        case 'dt'
            params.sim_params.dt = value;
        case 'T'
            params.sim_params.T = value;
        case 'enable_wind_sim'
            if ~isfield(params.sim_params, 'enable_wind_sim')
                params.sim_params.enable_wind_sim = value;
            else
                params.sim_params.enable_wind_sim = value;
            end
        case 'enable_noise'
            if ~isfield(params.sim_params, 'enable_noise')
                params.sim_params.enable_noise = value;
            else
                params.sim_params.enable_noise = value;
            end
        case 'enable_actuator_limits'
            if ~isfield(params.sim_params, 'enable_actuator_limits')
                params.sim_params.enable_actuator_limits = value;
            else
                params.sim_params.enable_actuator_limits = value;
            end
        case 'enable_goaround'
            if ~isfield(params.sim_params, 'enable_goaround')
                params.sim_params.enable_goaround = value;
            else
                params.sim_params.enable_goaround = value;
            end
            
        % 风场参数
        case 'enable_wind'
            params.wind_params.enable = value;
        case 'wind_speed'
            params.wind_params.speed = value;
        case 'wind_direction'
            params.wind_params.direction = value;
            
        % 大气参数
        case 'air_density'
            params.atmosphere.rho = value;
        case 'gravity'
            params.atmosphere.g = value;
    end
end