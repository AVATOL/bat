%% baseline DPM
globals

colorset = hsv((13-1) / 2 + 1);
colorset = [colorset; colorset(2:end,:)];
colorset =  mat2cell(colorset, ones(1,13), [3]);

kk = 100; kkk = 100; fix_def = 0;
sp_names = {'Artibeus', 'Noctilio', 'Trachops', 'Molossus', ...
            'Mormoops','Saccopteryx','Glossophaga'};
          
partmasks = cell(numel(sp_names),1);
models = {};
testAll = [];
for i = 1:numel(sp_names)
  sp = demo_config(sp_names{i});
  
  partmasks{i} = sp.part_mask;
  
  cls = [sp.name '_final_' num2str(sp.num_mix')' '_' num2str(kk) '_' num2str(kkk) '_' num2str(fix_def)];
  load([cachedir cls]);
  models = [models model];
  
  all_files = dir(sp.data_dir);
  png    = arrayfun(@(x) ~isempty(strfind(x.name, 'png')), all_files);
  all_files = all_files(logical(png));
  perm = 1:numel(all_files);
  train_index = perm(1:sp.num_train_data);
  test_index = perm(sp.num_train_data+1:end);
  train_files = all_files(train_index);
  test_files = all_files(test_index);
  [~,testX] = prepareData(sp.data_dir, [], test_files);
  testAll = [testAll testX(1)];
end

boxes = baseline_DPM(models, testAll, colorset, partmasks, 1);