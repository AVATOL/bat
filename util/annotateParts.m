function annotateParts(directory, regex, replace, part_labels, train_files)
%
% directory: dir where contains images to be trained
% regex: common pattern of positive images 
% replace: string to be replaced in image name 
% part_labels: name of each part
% train_files: files to be used for training, randomly selected from dir()
% example:
% dir = '../../AClass/pos/';
% pname = {'r','c','u1','u2','u3','u4','d1','d2','d3','d4'};
% annotateParts(dir, 'pos', '', pname);
%
% modified by by Shell Hu

  if nargin < 5
      train_files = [];
  end

  % remove trailing slash from the directory if need be
  if isequal(directory(end), '/') directory = directory(1:end-1); end
  
  % get the directory of positive examples
  if isempty(train_files)
      contents = dir(directory);
      posex    = arrayfun(@(x) regexMatch(x.name, regex), contents);
      posex    = contents(logical(posex));
  else
      contents = train_files;
      posex    = arrayfun(@(x) regexMatch(x.name, regex), contents);
      posex    = contents(logical(posex));
  end
  
  numpos   = numel(posex);
  
  % get the number and labels of each of the parts
  numparts = numel(part_labels);
  
  % ask the user to annotate each positive image
  ESC = 27;
  handle = figure;
  for n = 1:numpos
    [lead name ext] = fileparts(posex(n).name);
    if exist([directory '/' name 'parts.txt'], 'file')
        fprintf('%s has been annotated!\n', posex(n).name);
        continue
    end
    
    fprintf('-- annotating image %s --\n', posex(n).name);
    partloc = zeros(numparts,2);

    im = imread([directory '/' name ext]);
    hold off; imagesc(im); axis image; axis off; hold on;
    retry = 1;
    % allow the user to retry by pressing the ESCAPE key
    while retry
      retry = 0;
      % loop over each part and bring up a cursor for selecting (x,y)
      for p = 1:numparts
        title(['Click on the ' part_labels{p}]);
        [x, y, button] = ginput(1);
        if button == ESC
          retry = 1;
          break;
        end
        plot(x,y,'g.');
        partloc(p,:) = [x y];
      end
    end
    % write the part positions to file
    idx = strfind(name, replace);
    if idx
      name(idx:idx+length(replace)-1) = [];
      name = [name(1:idx-1) 'parts' name(idx:end)];
    else
      name = [name 'parts'];
    end
    dlmwrite([directory '/' name '.txt'], partloc);
  end
  close(handle);
end


function in = regexMatch(string, regex)
  if strfind(string, regex), in = 1; else in = 0; end
end
