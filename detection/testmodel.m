function [boxes,pscores] = testmodel(name,model,test,suffix)
% boxes = testmodel(name,model,test,suffix)
% Returns candidate bounding boxes after non-maximum suppression

globals;

% try
%   load([cachedir name '_boxes_' suffix]);
% catch
  boxes = cell(1,length(test));
  pscores = cell(1,length(test));
  for i = 1:length(test)
    fprintf([name ': testing: %d/%d\n'],i,length(test));
    im = imread(test(i).im);
    
    if nargout >= 2
        [box,pscore] = detect_fast(im,model,model.thresh);
    else
        box = detect_fast(im,model,model.thresh);
    end
    
    [boxes{i},pick] = nms(box,0.3);
    
    if nargout >= 2
        if size(pscore,1) > 1000
            [~,I] = sort(pscore(:,1),'descend');
            pscore = pscore(I(1:1000),:);
        end
        pscores{i} = pscore(pick,:);
    end
  end

%   if nargin < 4
%     suffix = [];
%   end
%   save([cachedir name '_boxes_' suffix], 'boxes','pscores','model');
% end
