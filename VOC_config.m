function Species = VOC_config(viewpoint,nparts)

Species = {};

load VOC2011PersonLayout.mat

Species.tr = components{viewpoint,nparts}.tr;
Species.name = components{viewpoint,nparts}.prefix;
Species.prefix = Species.name;
Species.num_parts = components{viewpoint,nparts}.num_parts+1;
Species.bb_const1 = 0.5;
Species.bb_const2 = 0.7;
Species.parent = [0 1 1 1 2 2]; % TODO, now [head,belly,lhand,rhand,lfoot,rfoot]
Species.num_mix = [1 1 1 1 1 1];
Species.part_mask = [1 1 1 1 1 1];
Species.part_map = [1 2 3 4 5 6];
Species.num_train_data = ceil(numel(Species.tr)/2);

Species.part_color = cell(1,Species.num_parts);
colorset = hsv((length(Species.part_mask)-1) / 2 + 1);
colorset = [colorset; colorset(2:end,:)];
colorset = colorset(Species.part_mask,:);
for i = 1:Species.num_parts
    Species.part_color{i} = colorset(i,:);
end

dag = zeros(length(Species.parent));
pa = Species.parent;
for i = 1:length(pa)
  if pa(i) == 0
    continue
  end
  dag(pa(i),i) = 1;
end
Species.dag = dag;