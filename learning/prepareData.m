function [train test] = prepareData(directory, train_files, test_files)
% 
  [train test] = deal([]);

  % remove trailing slash from the directory if need be
  if isequal(directory(end), '/') directory = directory(1:end-1); end
  
  % import the examples into the structure
  for n = 1:numel(train_files)
    train(n).im    = [directory '/' train_files(n).name];
    [lead name ext] = fileparts(train_files(n).name);
    train(n).point = dlmread([directory '/' name 'parts.txt']);
  end
  
  for n = 1:numel(test_files)
    test(n).im    = [directory '/' test_files(n).name];
  end
  
end
