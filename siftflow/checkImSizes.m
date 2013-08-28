fd_path = '/home/hushell/working/AVATOL/datasets/Bat/vent_exp_transfer/';
dir_list = {'Artibeus'  'Desmodus'  'Glossophaga'  'Molossus'  ...
    'Mormoops'  'Noctilio'  'Saccopteryx'  'Trachops'};

allImSizes = [];
for fi = 1:numel(dir_list)
    rt_path = [fd_path dir_list{fi} '/'];
    files = dir(rt_path);
    fileList = cell(length(files)-2,1);
    for j = 3:length(files)
        fstr = files(j).name;
        if strncmp(fstr(end-3:end), '.png', 4) == 0
            continue
        end
        fileList{j-2} = files(j).name;
    end  

    imsizes = zeros(numel(fileList), 2);
    for i = 1:numel(fileList)
        if isempty(fileList{i})
            continue
        end
        im = double(imread([rt_path fileList{i}])) / 255;
        tsiz = size(im);
        imsizes(i,:) = tsiz(1:2);
    end
    allImSizes = [allImSizes; imsizes];
end

allImSizes = allImSizes(allImSizes(:,1) > 0, :);
sum(allImSizes,1)/length(allImSizes)