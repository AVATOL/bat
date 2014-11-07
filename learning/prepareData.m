function [train test] = prepareData(Species, train_files, test_files)
% 
  all_parts = {'N','I1','C','P4','P5','M1','M2'};
  part_mask = Species.part_mask(1:7);
  num_parts = Species.num_parts;
  half_np = sum(part_mask)-1;
  directory = Species.data_dir;
  annotation = Species.anno_dir;
  [train test] = deal([]);

  % remove trailing slash from the directory if need be
  if isequal(directory(end), '/') directory = directory(1:end-1); end
  
  % import the examples into the structure
  for n = 1:numel(train_files)
    train(n).im    = [directory '/' train_files(n).name];
    [lead name ext] = fileparts(train_files(n).name);
    %train(n).point = dlmread([directory '/' name 'parts.txt']);
    train(n).point = zeros(num_parts, 2);
    pts = dlmread([annotation '/' name '_' all_parts{1} '.txt']);
    train(n).point(1,:) = pts(1,:);
    k = 2;
    for p = 2:7
        if part_mask(p) == 0
            continue
        end
        pts = dlmread([annotation '/' name '_' all_parts{p} '.txt']);
        train(n).point(k,:) = pts(1,:);
        train(n).point(k+half_np,:) = pts(2,:);
        k = k + 1;
    end
  end
  
  for n = 1:numel(test_files)
    test(n).im    = [directory '/' test_files(n).name];
  end
  
end
