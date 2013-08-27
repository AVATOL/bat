function [pos test] = getPositiveDataSeparate(directory, im_regex, dir_txt, lm_regex, testIdx)
% testIdx: e.g. [1,2]

  % remove trailing slash from the directory if need be
  if isequal(directory(end), '/') directory = directory(1:end-1); end
  
  % get the directory of positive examples
  contents = dir(directory);
  posim    = arrayfun(@(x) regexMatch(x.name, im_regex), contents);
  posim    = contents(logical(posim));
  
  if ~ischar(dir_txt)
      poslm = dir_txt; % directly pass points of parts
      %[nIm, nParts, nAxis] = size(poslm);
  else
      annotations = dir(dir_txt);  
      poslm    = arrayfun(@(x) regexMatch(x.name, lm_regex), annotations);
      poslm    = annotations(logical(poslm));
  end
  
  % get the number of examples
  numposim = length(posim);
  numposlm = length(poslm);
  if ~isequal(numposim, numposlm) 
      error('The number of matched images and annotations is not equal'); 
  end
  
  % import the examples into the structure
  for n = 1:numposim
    pos(n).im    = [directory '/' posim(n).name];
    if ~ischar(dir_txt)
        pos(n).point = squeeze(poslm(n,:,:));
    else
        pos(n).point = dlmread([dir_txt '/' poslm(n).name]);
    end
  end
  
  % split them for training and testing
  test = pos(testIdx);
  pos  = pos(setdiff(1:numposim,testIdx));
  
end

function in = regexMatch(string, regex)
  if strfind(string, regex), in = 1; else in = 0; end
end
