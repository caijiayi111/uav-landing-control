function [params, continue_sim] = create_parameter_gui()
% 简化版参数设置GUI - 现在调用新的综合GUI

    % 显示选项对话框
    answer = questdlg('选择参数配置方式:', ...
        '参数设置', ...
        '使用默认参数', '详细参数配置', '取消', '详细参数配置');
    
    switch answer
        case '使用默认参数'
            params = get_default_parameters();
            continue_sim = true;
            
        case '详细参数配置'
            % 调用新的综合GUI
            [params, continue_sim] = parameter_config_gui();
            
        case '取消'
            continue_sim = false;
            params = [];
    end
end