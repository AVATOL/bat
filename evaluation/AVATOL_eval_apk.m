function [apk,prec,rec,dist_ca] = AVATOL_eval_apk(boxes,test,distThresh,plot_act)
%
if nargin < 3
  distThresh  = 0.1;
  plot_act = 0;
end
if nargin < 4
  plot_act = 0;
end
% -------------------
% count the total number of candidates
numca = 0;
for n = 1:length(test)
  numca = numca + size(boxes{n},1);
end

% -------------------
% generate candidate joints
ca.point = []; ca.fr = []; ca.score = [];
ca(numca) = ca;
cnt = 0;
for n = 1:length(test)
  if isempty(boxes{n})
    continue;
  end
	box = boxes{n};
  b = box(:,1:floor(size(box, 2)/4)*4);
  b = reshape(b,size(b,1),4,size(b,2)/4);
  b = permute(b,[1 3 2]);
  bx = .5*b(:,:,1) + .5*b(:,:,3);
  by = .5*b(:,:,2) + .5*b(:,:,4);
  for i = 1:size(b,1)
    cnt = cnt + 1;
    ca(cnt).point = [bx(i,:)' by(i,:)'];
    ca(cnt).fr = n;
    ca(cnt).score = box(i,end);
  end
end

% -------------------
% generate ground truth stick
for n = 1:length(test)
  gt(n).numgt = 1;
  gt(n).point = test(n).point;
  gt(n).scale = norm(gt(n).point(1,:)-gt(n).point(2,:)); % use face size as the scale
  gt(n).det = 0;
end

numpoint = size(gt(1).point,1);
for k = 1:numpoint
  ca_p = ca;
  gt_p = gt;
  for n = 1:numca
    ca_p(n).point = ca(n).point(k,:);
  end
  for n = 1:length(test)
    gt_p(n).point = gt(n).point(k,:);
  end
  [apk(k) prec{k} rec{k} dist_ca{k}] = eval_apk(ca_p,gt_p,distThresh);
end

% % average left with right and neck with top head
% apk = (apk + apk([2 1 5 6 8 10 3 4 7 9]))/2;
% % change the order to: Head & Shoulder & Elbow & Wrist & Hip & Knee & Ankle
% apk = apk([1 3 4 7 9]);

%plot_act = 1;
if plot_act == 1
    for k = 1:numpoint
        recall = rec{k};
        precision = prec{k};
        figure(k);
        cla ; hold on ;
        plot(recall,precision,'linewidth',2) ;
        %line([0 1], [1 1] * p / length(labels), 'color', 'r', 'linestyle', '--') ;
        axis square ; grid on ;
        xlim([0 1]) ; xlabel('recall') ;
        ylim([0 1]) ; ylabel('precision') ;
        auc = sum((precision(1:end-1) + precision(2:end)) .* diff(recall)) / 2 ;
        title(sprintf('Precision-recall (AP = %.2f %%)', auc * 100)) ;
        %legend('PR', 'random classifier', 'Location', 'NorthWestOutside') ;
        %clear recall precision info ;
    end
    hold off;
end

