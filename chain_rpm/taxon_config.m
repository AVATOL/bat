function [taxa,meta] = taxon_config(names,part_names,part_mask)
%

meta.all_names = {'Artibeus','Noctilio','Trachops','Molossus',...
    'Mormoops','Saccopteryx','Glossophaga','Desmodus'};
meta.all_parts = {'I1','C','P4','P5','M1','M2'};
meta.colorset = hsv(length(meta.all_parts));

if nargin < 2
    part_names = meta.all_parts;
    part_mask = ones(1,length(part_names));
end

meta.taxon_list = names;
meta.part_list = part_names;

num_taxa = length(names);
taxa(num_taxa).name = names{num_taxa};

for i = 1:length(names)
    % common
    taxa(i).rt_dir = '../data/vent_small/';
    taxa(i).num_train_data = 8;
    taxa(i).name = names{i};

    if strcmp(names{i},'Artibeus')
        taxa(i).num_parts = 6;
        taxa(i).bb_const1 = 0.8;
        taxa(i).bb_const2 = 1.5;
        taxa(i).part_name = {'I1','C','P4','P5','M1','M2'};
        taxa(i).part_mask = logical([1 1 1 1 1 1]);
        taxa(i).prefix = 'A';
    elseif strcmp(names{i},'Noctilio')
        taxa(i).num_parts = 5;
        taxa(i).parent = 0:taxa(i).num_parts-1;
        taxa(i).bb_const1 = 0.8;
        taxa(i).bb_const2 = 1.5;
        taxa(i).part_name = {'I1','C','P5','M1','M2'};
        taxa(i).part_mask = logical([1 1 0 1 1 1]);
        taxa(i).prefix = 'N';
    elseif strcmp(names{i},'Trachops')
        taxa(i).num_parts = 6;
        taxa(i).parent = 0:taxa(i).num_parts-1;
        taxa(i).bb_const1 = 0.8;
        taxa(i).bb_const2 = 1.5;
        taxa(i).part_name = {'I1','C','P4','P5','M1','M2'};
        taxa(i).part_mask = logical([1 1 1 1 1 1]);
        taxa(i).prefix = 'T';
    elseif strcmp(names{i},'Molossus')
        taxa(i).num_parts = 5;
        taxa(i).parent = 0:taxa(i).num_parts-1;
        taxa(i).bb_const1 = 0.8;
        taxa(i).bb_const2 = 1.5;
        taxa(i).part_name = {'I1','C','P5','M1','M2'};
        taxa(i).part_mask = logical([1 1 0 1 1 1]);
        taxa(i).prefix = 'M1';
    elseif strcmp(names{i},'Mormoops')
        taxa(i).num_parts = 6;
        taxa(i).parent = 0:taxa(i).num_parts-1;
        taxa(i).bb_const1 = 0.8;
        taxa(i).bb_const2 = 1.5;
        taxa(i).part_name = {'I1','C','P4','P5','M1','M2'};
        taxa(i).part_mask = logical([1 1 1 1 1 1]);
        taxa(i).prefix = 'M2';
    elseif strcmp(names{i},'Saccopteryx')
        taxa(i).num_parts = 5;
        taxa(i).parent = 0:taxa(i).num_parts-1;
        taxa(i).bb_const1 = 0.8;
        taxa(i).bb_const2 = 1.2;
        taxa(i).part_name = {'C','P4','P5','M1','M2'};
        taxa(i).part_mask = logical([0 1 1 1 1 1]);
        taxa(i).prefix = 'S';
    elseif strcmp(names{i},'Glossophaga')
        taxa(i).num_parts = 6;
        taxa(i).parent = 0:taxa(i).num_parts-1;
        taxa(i).bb_const1 = 0.8;
        taxa(i).bb_const2 = 1.5;
        taxa(i).part_name = {'I1','C','P4','P5','M1','M2'};
        taxa(i).part_mask = logical([1 1 1 1 1 1]);
    elseif strcmp(names{i},'Desmodus')
        taxa(i).num_parts = 4;
        taxa(i).parent = 0:taxa(i).num_parts-1;
        taxa(i).bb_const1 = 0.8;
        taxa(i).bb_const2 = 1.0;
        taxa(i).part_name = {'I1','C','P5','M1'};
        taxa(i).part_mask = logical([1 1 0 1 1 0]);
        taxa(i).prefix = 'D';
    end

    % common
    taxa(i).part_name = intersect(taxa(i).part_name, part_names);
    taxa(i).part_mask = taxa(i).part_mask & part_mask;
    
    taxa(i).data_dir = [taxa(i).rt_dir, taxa(i).prefix, '/'];
    taxa(i).parent = 0:taxa(i).num_parts-1;
    
    %taxa(i).part_color = mat2cell(meta.colorset(taxa(i).part_mask,:), ...
    %    ones(1,taxa(i).num_parts), 3);
    taxa(i).part_color = mat2cell(meta.colorset, ...
        ones(1,length(meta.all_parts)), 3);
end
