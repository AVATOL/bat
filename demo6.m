clear
close all
globals;

%% annotation and train/test split
%species_name = {'Artibeus', 'Noctilio', 'Trachops', 'Molossus'};
species_name = {'Mormoops','Saccopteryx','Glossophaga','Desmodus'};
species = cell(size(species_name));
for j = 1:length(species)
  species{j} = demo_config(species_name{j});
  species{j}.part_color = cell(1,species{j}.num_parts);
  colorset = hsv((length(species{j}.part_mask)-1) / 2 + 1);
  colorset = [colorset; colorset(2:end,:)];
  colorset = colorset(species{j}.part_mask,:);
  for i = 1:species{j}.num_parts
      species{j}.part_color{i} = colorset(i,:);
  end

  all_files = dir(species{j}.data_dir);
  png    = arrayfun(@(x) ~isempty(strfind(x.name, 'png')), all_files);
  all_files = all_files(logical(png));
  %perm = randperm(numel(all_files));
  perm = 1:numel(all_files);
  train_index = perm(1:species{j}.num_train_data);
  test_index = perm(species{j}.num_train_data+1:end);
  train_files = all_files(train_index);
  test_files = all_files(test_index);

  % annotation
  annotateParts(species{j}.data_dir, 'png', '', species{j}.part_name, train_files);

  % prepare training and testing data
  [trainX testX] = prepareData(species{j}.data_dir, train_files, test_files);

  % convert annotated points to bounding boxes
  % TODO: test data
  species{j}.tr = pointtobox(trainX,species{j}.parent,species{j}.bb_const1,species{j}.bb_const2);
  
  dag = zeros(length(species{j}.parent));
  pa = species{j}.parent;
  for i = 1:length(pa)
    if pa(i) == 0
      continue
    end
    dag(pa(i),i) = 1;
  end
  species{j}.dag = dag;

  % visualize training data
  show_data = 0;
  if (show_data == 1)
      % show data
      for i=1:length(species{j}.tr)
          B = [species{j}.tr(i).x1;species{j}.tr(i).y1;species{j}.tr(i).x2;species{j}.tr(i).y2];
          B = reshape(B,[4*length(species{j}.parent),1])';
          A = imread(species{j}.tr(i).im);
          showboxes(A,B,species{j}.part_color);
          pause;
      end
  end
end % species

clear trainX train_files train_index testX test_files test_index all_files png perm colorset A B dag

%% training RPM
sbin = 8; % Spatial resolution of HOG cell
model = train_interface(species,sbin);

%% training with SSVM
%model = trainmodel_ssvm(species.name, pos, species.num_mix, species.parent, sbin, 100, 100, 1);

return

% visualize model
figure(1); visualizemodel(model);
figure(2); visualizeskeleton(model);

%% testing
model.thresh = 0;
model.thresh = min(model.thresh,-5);
[boxes,pscores] = testmodel(species.name, model, testX, num2str(species.num_mix')');

% visualize predictions
figure(3);
for ti = 1:length(testX)
    im = imread(testX(ti).im);
    showboxes(im, boxes{ti}(1,:), species.part_color);
    fprintf('press enter to continue...\n');
    pause;
end