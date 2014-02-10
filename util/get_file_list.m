function fileList = get_file_list(rt_path)
    % get fileList
    files = dir(rt_path);
    fileList = cell(length(files)-2,1);
    for j = 3:length(files)
        fstr = files(j).name;
        if length(fstr) < 10
            continue
        end
        if strncmp(fstr(end-9:end), 'resize.png', 10) == 0
            continue
        end
        fileList{j-2} = files(j).name;
    end  
end