function boxes = baseline_DPM(models, test, colorset, partmasks, show)
% 

if nargin < 5
  show = 0;
end

boxes = cell(length(test),length(models));
for i = 1:length(test)
  fprintf('testing: %d/%d\n',i,length(test));
  im = imread(test(i).im);
  for m = 1:length(models)
    fprintf(' with model %d\n', m);
    box = detect_fast(im,models{m},-2); % TODO: add model threshold
    box = nms(box,0.3);
    boxes{i,m} = box(1,:);
    if show
      showboxes(im, boxes{i,m}, colorset(partmasks{m},:));
      fprintf('press enter to continue...\n');
      pause;
    end
  end
end
