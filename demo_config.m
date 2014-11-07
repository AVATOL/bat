function Species = demo_config(prefix, input_folder, image_folder, anno_folder)
%

if nargin < 2
    input_folder = 'data/vent_small/';
end

Species = {};

if (strcmp(prefix,'Artibeus'))
    % Artibeus
    Species.rt_dir = input_folder;
    Species.prefix = 'A';
    Species.data_dir = fullfile(input_folder, image_folder, Species.prefix, '/');
    Species.anno_dir = fullfile(input_folder, anno_folder, Species.prefix, '/');
    Species.num_train_data = 8;
    Species.num_parts = 13;
    Species.bb_const1 = 0.8;
    Species.bb_const2 = 1.5;
    Species.name = [Species.prefix, '_', num2str(Species.num_parts), '_', num2str(Species.num_train_data)];
    Species.num_mix = [1 1 1 1 1 1 1 1 1 1 1 1 1];
    Species.parent = [0 1 2 3 4 5 6 1 8 9 10 11 12];
    Species.part_name = {'Nasal',...
        'I1 upper','C upper','P4 upper','P5 upper','M1 upper','M2 upper',...
        'I1 lower','C lower','P4 lower','P5 lower','M1 lower','M2 lower'};
    Species.part_mask = logical([1 1 1 1 1 1 1 1 1 1 1 1 1]);
elseif(strcmp(prefix,'Noctilio'))
    % Noctilio
    Species.rt_dir = input_folder;
    Species.prefix = 'N';
    Species.data_dir = fullfile(input_folder, image_folder, Species.prefix, '/');
    Species.anno_dir = fullfile(input_folder, anno_folder, Species.prefix, '/');
    Species.num_train_data = 8;
    Species.num_parts = 11;
    Species.bb_const1 = 0.8;
    Species.bb_const2 = 1.5;
    Species.name = [Species.prefix, '_', num2str(Species.num_parts), '_', num2str(Species.num_train_data)];
    Species.num_mix = [1 1 1 1 1 1 1 1 1 1 1];
    Species.parent = [0 1 2 3 4 5 1 7 8 9 10];
    Species.part_name = {'Nasal',...
        'I1 upper','C upper','P5 upper','M1 upper','M2 upper',...
        'I1 lower','C lower','P5 lower','M1 lower','M2 lower'};
    Species.part_mask = logical([1 1 1 0 1 1 1 1 1 0 1 1 1]);
elseif(strcmp(prefix,'Trachops'))
    % Trachops
    Species.rt_dir = input_folder;
    Species.prefix = 'T';
    Species.data_dir = fullfile(input_folder, image_folder, Species.prefix, '/');
    Species.anno_dir = fullfile(input_folder, anno_folder, Species.prefix, '/');
    Species.num_train_data = 8;
    Species.num_parts = 13;
    Species.bb_const1 = 0.8;
    Species.bb_const2 = 1.5;
    Species.name = [Species.prefix, '_', num2str(Species.num_parts), '_', num2str(Species.num_train_data)];
    Species.num_mix = [1 1 1 1 1 1 1 1 1 1 1 1 1];
    Species.parent = [0 1 2 3 4 5 6 1 8 9 10 11 12];
    Species.part_name = {'Nasal',...
        'I1 upper','C upper','P4 upper','P5 upper','M1 upper','M2 upper',...
        'I1 lower','C lower','P4 lower','P5 lower','M1 lower','M2 lower'};
    Species.part_mask = logical([1 1 1 1 1 1 1 1 1 1 1 1 1]);
elseif(strcmp(prefix,'Molossus'))
    % Noctilio
    Species.rt_dir = input_folder;
    Species.prefix = 'M1';
    Species.data_dir = fullfile(input_folder, image_folder, Species.prefix, '/');
    Species.anno_dir = fullfile(input_folder, anno_folder, Species.prefix, '/');
    Species.num_train_data = 8;
    Species.num_parts = 11;
    Species.bb_const1 = 0.8;
    Species.bb_const2 = 1.5;
    Species.name = [Species.prefix, '_', num2str(Species.num_parts), '_', num2str(Species.num_train_data)];
    Species.num_mix = [1 1 1 1 1 1 1 1 1 1 1];
    Species.parent = [0 1 2 3 4 5 1 7 8 9 10];
    Species.part_name = {'Nasal',...
        'I1 upper','C upper','P5 upper','M1 upper','M2 upper',...
        'I1 lower','C lower','P5 lower','M1 lower','M2 lower'};
    Species.part_mask = logical([1 1 1 0 1 1 1 1 1 0 1 1 1]);
elseif(strcmp(prefix,'Mormoops'))
    % Trachops
    Species.rt_dir = input_folder;
    Species.prefix = 'M2';
    Species.data_dir = fullfile(input_folder, image_folder, Species.prefix, '/');
    Species.anno_dir = fullfile(input_folder, anno_folder, Species.prefix, '/');
    Species.num_train_data = 8;
    Species.num_parts = 13;
    Species.bb_const1 = 1.0;
    Species.bb_const2 = 1.8;
    Species.name = [Species.prefix, '_', num2str(Species.num_parts), '_', num2str(Species.num_train_data)];
    Species.num_mix = [1 1 1 1 1 1 1 1 1 1 1 1 1];
    Species.parent = [0 1 2 3 4 5 6 1 8 9 10 11 12];
    Species.part_name = {'Nasal',...
        'I1 upper','C upper','P4 upper','P5 upper','M1 upper','M2 upper',...
        'I1 lower','C lower','P4 lower','P5 lower','M1 lower','M2 lower'};
    Species.part_mask = logical([1 1 1 1 1 1 1 1 1 1 1 1 1]);
elseif(strcmp(prefix,'Saccopteryx'))
    % Trachops
    Species.rt_dir = input_folder;
    Species.prefix = 'S';
    Species.data_dir = fullfile(input_folder, image_folder, Species.prefix, '/');
    Species.anno_dir = fullfile(input_folder, anno_folder, Species.prefix, '/');
    Species.num_train_data = 8;
    Species.num_parts = 11;
    Species.bb_const1 = 0.8;
    Species.bb_const2 = 1.2;
    Species.name = [Species.prefix, '_', num2str(Species.num_parts), '_', num2str(Species.num_train_data)];
    Species.num_mix = [1 1 1 1 1 1 1 1 1 1 1];
    Species.parent = [0 1 2 3 4 5 1 7 8 9 10];
    Species.part_name = {'Nasal',...
        'C upper','P4 upper','P5 upper','M1 upper','M2 upper',...
        'C lower','P4 lower','P5 lower','M1 lower','M2 lower'};
    Species.part_mask = logical([1 0 1 1 1 1 1 0 1 1 1 1 1]);
elseif(strcmp(prefix,'Glossophaga'))
    % Trachops
    Species.rt_dir = input_folder;
    Species.prefix = 'G';
    Species.data_dir = fullfile(input_folder, image_folder, Species.prefix, '/');
    Species.anno_dir = fullfile(input_folder, anno_folder, Species.prefix, '/');
    Species.num_train_data = 8;
    Species.num_parts = 13;
    Species.bb_const1 = 0.8;
    Species.bb_const2 = 1.5;
    Species.name = [Species.prefix, '_', num2str(Species.num_parts), '_', num2str(Species.num_train_data)];
    Species.num_mix = [1 1 1 1 1 1 1 1 1 1 1 1 1];
    Species.parent = [0 1 2 3 4 5 6 1 8 9 10 11 12];
    Species.part_name = {'Nasal',...
        'I1 upper','C upper','P4 upper','P5 upper','M1 upper','M2 upper',...
        'I1 lower','C lower','P4 lower','P5 lower','M1 lower','M2 lower'};
    Species.part_mask = logical([1 1 1 1 1 1 1 1 1 1 1 1 1]);
elseif(strcmp(prefix,'Desmodus'))
    % Trachops
    Species.rt_dir = input_folder;
    Species.prefix = 'D';
    Species.data_dir = fullfile(input_folder, image_folder, Species.prefix, '/');
    Species.anno_dir = fullfile(input_folder, anno_folder, Species.prefix, '/');
    Species.num_train_data = 8;
    Species.num_parts = 9;
    Species.bb_const1 = 0.8;
    Species.bb_const2 = 1.0;
    Species.name = [Species.prefix, '_', num2str(Species.num_parts), '_', num2str(Species.num_train_data)];
    Species.num_mix = [1 1 1 1 1 1 1 1 1];
    Species.parent = [0 1 2 3 4 1 6 7 8];
    Species.part_name = {'Nasal',...
        'I1 upper','C upper','P5 upper','M1 upper',...
        'I1 lower','C lower','P5 lower','M1 lower'};
    Species.part_mask = logical([1 1 1 0 1 1 0 1 1 0 1 1 0]);    
end

Species.part_color = cell(1,Species.num_parts);
colorset = hsv((length(Species.part_mask)-1) / 2 + 1);
colorset = [colorset; colorset(2:end,:)];
colorset = colorset(Species.part_mask,:);
Species.part_color = mat2cell(colorset, ones(1,Species.num_parts), 3);
